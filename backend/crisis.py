from __future__ import annotations

CRISIS_RESPONSE = (
    "I'm really glad you reached out. Please contact iCall right now at 9152987821 "
    "— they are trained to help and it is completely free. If you are in immediate "
    "danger, please call 112. You do not have to face this alone."
)

EXPLICIT_CRISIS_KEYWORDS = [
    "hurt myself",
    "want to die",
    "kill myself",
    "end my life",
    "suicide",
    "suicidal",
    "want to end it",
    "don't want to live",
    "no reason to live",
    "can't go on",
]

IMPLICIT_DISTRESS_TRIGGERS = [
    "everyone would be better off without me",
    "can't do this anymore",
    "what's the point",
    "nobody would miss me",
]


def _normalized(text: str) -> str:
    return (text or "").strip().lower()


def detect_explicit_crisis(text: str) -> bool:
    normalized = _normalized(text)
    return any(keyword in normalized for keyword in EXPLICIT_CRISIS_KEYWORDS)


def detect_implicit_distress(text: str) -> bool:
    normalized = _normalized(text)
    return any(trigger in normalized for trigger in IMPLICIT_DISTRESS_TRIGGERS)
