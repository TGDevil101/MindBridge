from __future__ import annotations

import os
from pathlib import Path
from typing import List, Dict, Any

from dotenv import load_dotenv
from groq import AsyncGroq

from crisis import CRISIS_RESPONSE

env_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=env_path)

SYSTEM_PROMPT = """You are MindBridge, a warm and supportive mental health awareness chatbot built for students and parents in India.

Your purpose is to help people understand mental health conditions, take self-assessments, and find the right support. You are not a therapist. You are not a doctor. You screen and refer — you never diagnose.

RULES YOU MUST NEVER BREAK:
1. Never say "you have [condition]" or "you are depressed" or any direct diagnosis. Always use deferred language: "some of what you're describing is associated with..." or "your responses suggest you may be experiencing..."
2. Never diagnose. If asked directly — "do I have anxiety?" — always say only a qualified professional can determine that.
3. Keep your tone warm, calm, and non-clinical. Write like a knowledgeable, caring friend — not a medical textbook.
4. Always validate feelings before offering information. If someone shares something painful, acknowledge it first.
5. Keep responses concise — 3 to 5 sentences unless the person needs more. Do not lecture.
6. For moderate or above scores on any assessment, always recommend speaking to a professional and mention iCall (9152987821) — free, confidential, trained counsellors.
7. Never minimise what someone shares. Phrases like "everyone feels that way" or "just think positive" are harmful here.
8. You cover exactly 5 conditions: anxiety (GAD-7), depression (PHQ-9), stress (PSS-10), ADHD (ASRS v1.1), and loneliness (UCLA-3).
9. For loneliness, use warm and connection-focused language. Never catastrophise.
10. If a student asks about a parent's condition or vice versa, provide awareness information only — never assess someone who is not present.

CONTEXT:
- Students can take self-assessments and chat about their own mental health.
- Parents can ask about their child's behaviour and get awareness information. They cannot take assessments on behalf of their child.
- The app operates in India. Be aware of Indian cultural context: stigma around mental health is real, family pressure on students is common, and academic stress is a major factor.

Indian helplines you can mention:
- iCall: 9152987821 (free, confidential)
- Vandrevala Foundation: 1860-2662-345
- Emergency: 112"""

_groq_api_key = os.getenv("GROQ_API_KEY", "").strip()
_client = AsyncGroq(api_key=_groq_api_key) if _groq_api_key else None

# Cap history at last 10 exchanges (20 messages) to stay within token limits
_MAX_HISTORY_MESSAGES = 20


def _build_messages(
    user_type: str,
    user_message: str,
    history: List[Dict[str, Any]],
) -> List[Dict[str, str]]:
    """Build the full message list: system prompt + conversation history + current message."""
    messages: List[Dict[str, str]] = [
        {"role": "system", "content": SYSTEM_PROMPT},
    ]

    # Add conversation history (already stored as role/content pairs in DB)
    recent = history[-_MAX_HISTORY_MESSAGES:] if len(history) > _MAX_HISTORY_MESSAGES else history
    for entry in recent:
        role = entry.get("role", "user")
        content = entry.get("content", "")
        if role in ("user", "assistant") and content:
            messages.append({"role": role, "content": content})

    # Add current user message with user_type context on the first message only
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
    if _client is None:
        fallback = (
            "Thank you for sharing that. I'm here to listen and support you. "
            "If this is feeling hard to manage, speaking with a counsellor can help."
        )
        if implicit_distress:
            return f"{CRISIS_RESPONSE}\n\n{fallback}"
        return fallback

    messages = _build_messages(user_type, user_message, history or [])

    completion = await _client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        temperature=0.4,
        max_tokens=400,
        messages=messages,
    )
    text = (completion.choices[0].message.content or "").strip()
    if implicit_distress:
        return f"{CRISIS_RESPONSE}\n\n{text}"
    return text
