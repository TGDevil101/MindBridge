from __future__ import annotations

import os
import re
from pathlib import Path
from uuid import uuid4

import json as _json

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

# Load .env (MONGODB_URI, MODEL_PROVIDER, OLLAMA_HOST, JWT_SECRET, etc.)
load_dotenv(dotenv_path=Path(__file__).parent / ".env")

from auth import create_access_token, decode_access_token, hash_password, verify_password
from crisis import CRISIS_RESPONSE, detect_explicit_crisis, detect_implicit_distress
from database import (
    append_chat_message,
    create_user,
    delete_session,
    get_chat_history,
    get_session_history,
    get_user_by_username,
    init_db,
)
from scoring import score_assessment

# Model provider — defaults to local fine-tuned Ollama model.
# Set MODEL_PROVIDER=groq to fall back to Groq API (e.g. for comparison tests).
_PROVIDER = os.getenv("MODEL_PROVIDER", "ollama").strip().lower()
if _PROVIDER == "groq":
    from groq_client import get_chat_response
    _OllamaUnavailable: tuple = ()  # type: ignore[assignment]
    stream_chat_response = None  # streaming only available on Ollama path
else:
    from ollama_client import OllamaUnavailable as _OllamaUnavailable
    from ollama_client import get_chat_response, stream_chat_response

app = FastAPI(title="MindBridge Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

JWT_SECRET = os.getenv("JWT_SECRET", "your-secret-key-change-in-prod")
JWT_ALGORITHM = "HS256"
MONGODB_URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")


class RegisterRequest(BaseModel):
    username: str
    password: str


class LoginRequest(BaseModel):
    username: str
    password: str


class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    user_type: str = Field(default="student")
    session_id: str | None = None


class AssessRequest(BaseModel):
    assessment_type: str
    answers: list[int]


async def get_current_user(authorization: str = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid token")

    token = authorization.replace("Bearer ", "", 1)
    payload = decode_access_token(token, JWT_SECRET, JWT_ALGORITHM)

    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    username = payload.get("sub")
    if username is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = await get_user_by_username(username)
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")

    return user


@app.on_event("startup")
async def startup_event() -> None:
    await init_db(MONGODB_URI)


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": "mindbridge-backend", "provider": _PROVIDER}


@app.post("/auth/register")
async def register(payload: RegisterRequest) -> dict:
    username = payload.username.strip().lower()
    password = payload.password.strip()

    if not re.match(r"^[a-z0-9_]{3,20}$", username):
        raise HTTPException(status_code=400, detail="Username must be 3-20 alphanumeric + underscores, lowercase")

    if len(password) < 8:
        raise HTTPException(status_code=400, detail="Password must be at least 8 characters")

    if len(password) > 72:
        raise HTTPException(status_code=400, detail="Password must be 72 characters or less")

    try:
        password_hash = hash_password(password)
        await create_user(username, password_hash)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e

    return {"message": "User registered successfully"}


@app.post("/auth/login")
async def login(payload: LoginRequest) -> dict:
    username = payload.username.strip().lower()
    password = payload.password.strip()

    user = await get_user_by_username(username)
    if user is None or not verify_password(password, user.get("password_hash", "")):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    access_token = create_access_token({"sub": username}, JWT_SECRET, JWT_ALGORITHM)
    return {"access_token": access_token, "token_type": "bearer", "username": username}


@app.get("/auth/me")
async def me(authorization: str = Header(None)) -> dict:
    user = await get_current_user(authorization)
    return {"username": user.get("username"), "user_id": str(user.get("_id"))}


@app.post("/chat")
async def chat(payload: ChatRequest, authorization: str = Header(None)) -> dict:
    user = await get_current_user(authorization)
    user_id = str(user.get("_id"))
    username = user.get("username")

    session_id = payload.session_id or str(uuid4())
    text = payload.message.strip()

    if detect_explicit_crisis(text):
        await append_chat_message(session_id, user_id, username, text, CRISIS_RESPONSE)
        return {
            "session_id": session_id,
            "response": CRISIS_RESPONSE,
            "crisis": True,
            "show_helpline_card": True,
        }

    implicit_distress = detect_implicit_distress(text)
    history = await get_session_history(session_id, user_id)
    try:
        response = await get_chat_response(
            payload.user_type, text, implicit_distress=implicit_distress, history=history
        )
    except _OllamaUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    await append_chat_message(session_id, user_id, username, text, response)

    return {
        "session_id": session_id,
        "response": response,
        "crisis": implicit_distress,
        "show_helpline_card": implicit_distress,
    }


@app.post("/chat/stream")
async def chat_stream(payload: ChatRequest, authorization: str = Header(None)):
    """Stream model tokens as NDJSON.

    Wire protocol — each line is a JSON object:
      {"event":"start","session_id":"..."}
      {"event":"crisis","content":"...","show_helpline_card":true}   (only if hardcoded crisis)
      {"event":"delta","content":"some"}                              (model tokens)
      {"event":"delta","content":" tokens"}
      ...
      {"event":"end","session_id":"...","crisis":bool,"show_helpline_card":bool}

    The client reads line by line and appends `event=delta` content to the
    growing assistant message.
    """
    if stream_chat_response is None:
        raise HTTPException(status_code=501, detail="Streaming not supported with current MODEL_PROVIDER")

    user = await get_current_user(authorization)
    user_id = str(user.get("_id"))
    username = user.get("username")
    session_id = payload.session_id or str(uuid4())
    text = payload.message.strip()

    explicit_crisis = detect_explicit_crisis(text)
    implicit_distress = detect_implicit_distress(text)

    async def event_stream():
        # Always emit start so client knows session_id
        yield _json.dumps({"event": "start", "session_id": session_id}) + "\n"

        # Explicit crisis bypasses the model entirely — instant hardcoded response.
        if explicit_crisis:
            yield _json.dumps({
                "event": "crisis",
                "content": CRISIS_RESPONSE,
                "show_helpline_card": True,
            }) + "\n"
            await append_chat_message(session_id, user_id, username, text, CRISIS_RESPONSE)
            yield _json.dumps({
                "event": "end",
                "session_id": session_id,
                "crisis": True,
                "show_helpline_card": True,
            }) + "\n"
            return

        # Implicit distress: prepend hardcoded crisis text before streaming model output
        if implicit_distress:
            yield _json.dumps({"event": "delta", "content": CRISIS_RESPONSE + "\n\n"}) + "\n"
            full_response_parts: list[str] = [CRISIS_RESPONSE + "\n\n"]
        else:
            full_response_parts = []

        history = await get_session_history(session_id, user_id)
        try:
            async for delta in stream_chat_response(payload.user_type, text, history=history):
                full_response_parts.append(delta)
                yield _json.dumps({"event": "delta", "content": delta}) + "\n"
        except _OllamaUnavailable as exc:
            yield _json.dumps({"event": "error", "detail": str(exc)}) + "\n"
            return

        full_response = "".join(full_response_parts).strip()
        if full_response:
            await append_chat_message(session_id, user_id, username, text, full_response)

        yield _json.dumps({
            "event": "end",
            "session_id": session_id,
            "crisis": implicit_distress,
            "show_helpline_card": implicit_distress,
        }) + "\n"

    return StreamingResponse(
        event_stream(),
        media_type="application/x-ndjson",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable nginx/proxy buffering
        },
    )


@app.post("/assess")
async def assess(payload: AssessRequest) -> dict:
    try:
        result = score_assessment(payload.assessment_type, payload.answers)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    if result.get("crisis_trigger"):
        result["show_helpline_card"] = True
        result["crisis_response"] = CRISIS_RESPONSE
    else:
        result["show_helpline_card"] = bool(result.get("show_icall"))

    return result


@app.get("/history")
async def history(authorization: str = Header(None)) -> dict:
    user = await get_current_user(authorization)
    user_id = str(user.get("_id"))
    sessions = await get_chat_history(user_id)
    return {"sessions": sessions}


@app.delete("/history/{session_id}")
async def delete_chat_session(session_id: str, authorization: str = Header(None)) -> dict:
    user = await get_current_user(authorization)
    user_id = str(user.get("_id"))

    deleted = await delete_session(session_id, user_id)

    if not deleted:
        raise HTTPException(status_code=404, detail="Session not found")

    return {"status": "deleted", "session_id": session_id}
