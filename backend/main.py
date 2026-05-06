from __future__ import annotations

from uuid import uuid4

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from crisis import CRISIS_RESPONSE, detect_explicit_crisis, detect_implicit_distress
from database import append_chat_message, get_chat_history, init_db
from groq_client import get_chat_response
from scoring import score_assessment

app = FastAPI(title="MindBridge Backend")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    message: str = Field(min_length=1)
    user_type: str = Field(default="student")
    session_id: str | None = None


class AssessRequest(BaseModel):
    assessment_type: str
    answers: list[int]


@app.on_event("startup")
def startup_event() -> None:
    init_db()


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "service": "mindbridge-backend"}


@app.post("/chat")
async def chat(payload: ChatRequest) -> dict:
    session_id = payload.session_id or str(uuid4())
    text = payload.message.strip()

    if detect_explicit_crisis(text):
        append_chat_message(session_id, payload.user_type, text, CRISIS_RESPONSE)
        return {
            "session_id": session_id,
            "response": CRISIS_RESPONSE,
            "crisis": True,
            "show_helpline_card": True,
        }

    implicit_distress = detect_implicit_distress(text)
    response = await get_chat_response(payload.user_type, text, implicit_distress=implicit_distress)
    append_chat_message(session_id, payload.user_type, text, response)

    return {
        "session_id": session_id,
        "response": response,
        "crisis": implicit_distress,
        "show_helpline_card": implicit_distress,
    }


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
async def history() -> dict:
    return {"sessions": get_chat_history()}
