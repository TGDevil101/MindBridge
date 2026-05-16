from __future__ import annotations

import os
from pathlib import Path
from typing import List, Dict, Any

import httpx
from dotenv import load_dotenv

from crisis import CRISIS_RESPONSE

env_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=env_path)

OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434").rstrip("/")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "mindbridge")

# Short system prompt matching the one used during QLoRA fine-tuning.
# The Modelfile also defines a default SYSTEM directive, but we pass it
# explicitly here so behaviour is deterministic regardless of model defaults.
SYSTEM_PROMPT = (
    "You are MindBridge, a warm and supportive mental health awareness chatbot "
    "for students and parents in India. You screen and refer — you never diagnose. "
    "Use deferred language ('some of what you're describing is associated with...', "
    "never 'you have X'). For moderate-to-high distress, mention iCall at 9152987821. "
    "Keep responses warm, calm, non-clinical, 3-5 sentences. Validate feelings first. "
    "For parents, frame questions about their child's behaviour, not their own."
)

_MAX_HISTORY_MESSAGES = 20


class OllamaUnavailable(RuntimeError):
    """Raised when the Ollama backend is unreachable or returns an empty result."""


def _build_messages(
    user_type: str,
    user_message: str,
    history: List[Dict[str, Any]],
) -> List[Dict[str, str]]:
    messages: List[Dict[str, str]] = [
        {"role": "system", "content": SYSTEM_PROMPT},
    ]

    recent = history[-_MAX_HISTORY_MESSAGES:] if len(history) > _MAX_HISTORY_MESSAGES else history
    for entry in recent:
        role = entry.get("role", "user")
        content = entry.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})

    if not history:
        messages.append({
            "role": "user",
            "content": f"[User type: {user_type}]\n{user_message}",
        })
    else:
        messages.append({"role": "user", "content": user_message})

    return messages


async def get_chat_response(
    user_type: str,
    user_message: str,
    implicit_distress: bool = False,
    history: List[Dict[str, Any]] | None = None,
) -> str:
    messages = _build_messages(user_type, user_message, history or [])

    payload = {
        "model": OLLAMA_MODEL,
        "messages": messages,
        "stream": False,
        "options": {
            "temperature": 0.4,
            "num_predict": 400,
        },
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            r = await client.post(f"{OLLAMA_HOST}/api/chat", json=payload)
            r.raise_for_status()
            data = r.json()
            text = (data.get("message", {}).get("content") or "").strip()
        except (httpx.HTTPError, ValueError) as exc:
            # The MindBridge model runs on a tunneled local Ollama instance.
            # When it's unreachable, surface a clear 503 instead of fabricating
            # a generic response that would mislead the user.
            raise OllamaUnavailable(
                f"Fine-tuned MindBridge model is currently unavailable "
                f"(host={OLLAMA_HOST}, model={OLLAMA_MODEL}). "
                f"Please try again in a few minutes."
            ) from exc

    if not text:
        raise OllamaUnavailable("Model returned an empty response.")

    if implicit_distress:
        return f"{CRISIS_RESPONSE}\n\n{text}"
    return text
