from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv
from groq import AsyncGroq

from crisis import CRISIS_RESPONSE

env_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=env_path)

SYSTEM_PROMPT = """You are MindBridge, a mental health awareness chatbot for students and parents in India.

Rules you must never break:
1. Never say "you have [condition]". Always use deferred language: "some of your responses are associated with..."
2. Never diagnose anyone.
3. Always recommend speaking to a professional for moderate or above scores.
4. Keep your tone warm, simple, and non-clinical.
5. If someone expresses distress, validate first before offering information.
6. You cover 5 conditions: anxiety, depression, stress, ADHD, and loneliness.
7. Always end referral conversations by mentioning iCall (9152987821)."""

_groq_api_key = os.getenv("GROQ_API_KEY", "").strip()
print(f"DEBUG: GROQ_API_KEY loaded = {bool(_groq_api_key)}, length = {len(_groq_api_key)}")
_client = AsyncGroq(api_key=_groq_api_key) if _groq_api_key else None


async def get_chat_response(user_type: str, user_message: str, implicit_distress: bool = False) -> str:
    if _client is None:
        fallback = (
            "Thank you for sharing that. I'm here to listen and support you. "
            "If this is feeling hard to manage, speaking with a counsellor can help."
        )
        if implicit_distress:
            return f"{CRISIS_RESPONSE}\n\n{fallback}"
        return fallback

    completion = await _client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        temperature=0.4,
        max_tokens=400,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"User type: {user_type}\nMessage: {user_message}",
            },
        ],
    )
    text = (completion.choices[0].message.content or "").strip()
    if implicit_distress:
        return f"{CRISIS_RESPONSE}\n\n{text}"
    return text
