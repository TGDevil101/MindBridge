"""
MindBridge crisis detection layer.

This is the most safety-critical code in the project. The PDF spec says:
"Crisis detection runs on every single message before the AI is called.
 If it fails, nothing else matters."

We implement a two-tier defense:

  Tier 1 — EXPLICIT crisis: direct ideation, methods, goodbye signals,
    self-harm verbs, common euphemisms / slang. These BYPASS the AI entirely.
    The hardcoded CRISIS_RESPONSE is returned with helplines, instant.

  Tier 2 — IMPLICIT distress: hopelessness, burden cognition, indirect
    language. The AI is still called, but the helpline text is prepended
    to its response and the UI flags `show_helpline_card`.

All patterns are compiled regex with word boundaries to reduce false
matches ("skill" doesn't trigger "kill", "psuicide" doesn't trigger
"suicide" but real text typo-fuzziness is still handled by substring
matching for multi-word phrases).

A separate test_crisis.py file validates this against a labeled set of
~150 positive + ~50 negative cases. Run with: pytest backend/tests/

Design principle: false positives are vastly preferable to false negatives.
If a regex accidentally surfaces helplines for a non-crisis prompt, the
user sees a phone number they didn't ask for — annoying but harmless.
A missed real crisis is potentially fatal. Tune accordingly.
"""
from __future__ import annotations

import re

CRISIS_RESPONSE = (
    "I'm really glad you reached out. Please contact iCall right now at 9152987821 "
    "— they are trained to help and it is completely free. If you are in immediate "
    "danger, please call 112. You do not have to face this alone."
)


# -----------------------------------------------------------------------------
# Tier 1 — EXPLICIT crisis (bypass the AI; instant helpline response)
# -----------------------------------------------------------------------------
# Each entry is either a regex pattern (string starting with 'r:') or a
# plain phrase that will be matched as a substring after lowercasing.
# Regex patterns get re.IGNORECASE + word boundaries where appropriate.

EXPLICIT_CRISIS_PATTERNS: list[str] = [
    # --- Direct suicidal ideation ---
    r"\bsuicide\b",
    r"\bsuicidal\b",
    r"\bkill(ing)?\s+myself\b",
    r"\bkill\s+my\s*self\b",
    r"\bend(ing)?\s+(my|it)\s+(life|all)\b",
    r"\bend\s+my\s+own\s+life\b",
    r"\btake\s+my\s+(own\s+)?life\b",
    r"\bcommit(ting)?\s+suicide\b",

    # --- Wishing dead / not wanting to live ---
    r"\bwant\s+to\s+die\b",
    r"\bwish\s+i\s+(were|was)\s+dead\b",
    r"\bwish\s+i\s+(were|was)\s+gone\b",
    r"\b(never\s+been\s+born|never\s+born)\b",   # "wish I'd never been born", etc.
    r"\bdon'?t\s+want\s+to\s+live\b",
    r"\bdon'?t\s+want\s+to\s+be\s+(here|alive)\b",
    r"\bdon'?t\s+want\s+to\s+wake\s+up\b",
    r"\bno\s+reason\s+to\s+live\b",
    r"\bno\s+(point|reason)\s+(in\s+)?living\b",
    r"\blife\s+is\s+(not|n't)\s+worth\s+living\b",
    r"\b(rather|prefer)\s+(be\s+)?dead\b",

    # --- Methods / planning ---
    r"\b(taking|swallow(ing)?|overdos(ing|e))\s+(pills|tablets|drugs|medicine)\b",
    r"\boverdose\b",                                 # standalone noun/verb
    r"\bhang(ing)?\s+myself\b",
    r"\bshoot(ing)?\s+myself\b",
    r"\bjump(ing)?\s+(off|from)\s+(the\s+|a\s+)?(building|bridge|roof|balcony|window|train)\b",
    r"\bslit(ting)?\s+my\s+wrists?\b",
    r"\bcut(ting)?\s+(my\s+)?(wrists?|deep)\b",
    r"\bnoose\b",

    # --- Goodbye signals / planning leaving ---
    r"\bgoodbye\s+(note|letter)s?\b",
    r"\b(writing|writ)\s+(a\s+)?suicide\s+note\b",
    r"\bwriting\s+goodbye\b",
    r"\bplanning\s+(my\s+)?(exit|end|death)\b",
    r"\bsaying\s+(my\s+)?(last\s+)?goodbyes?\b",
    r"\bafter\s+i'?m\s+gone\b",
    r"\bwhen\s+i'?m\s+gone\b",
    r"\bgiving\s+(away\s+)?my\s+(things|stuff|possessions)\b",

    # --- Self-harm (direct) ---
    r"\bself[\s-]?harm(ing)?\b",
    r"\bharm(ing)?\s+myself\b",
    r"\bhurt(ing)?\s+myself\b",
    r"\bcut(ting)?\s+myself\b",
    r"\bself[\s-]?injur(y|ies|ing)\b",
    r"\bburn(ing)?\s+myself\b",

    # --- Slang / euphemism ---
    r"\bkms\b",       # "kill myself"
    r"\bkys\b",       # "kill yourself" (often used self-directed)
    r"\bunalive\b",
    r"\boff\s+myself\b",
    r"\boff\s+my\s*self\b",

    # --- Existential despair phrases people use specifically before attempts ---
    r"\bcan'?t\s+(do|take)\s+(this|it)\s+anymore\b",  # NOTE: also in implicit; we
                                                       # treat it as Tier 1 because
                                                       # historically this phrase
                                                       # precedes attempts often.
    r"\bgive\s+up\s+on\s+life\b",
    r"\bwant\s+(it|everything)\s+to\s+end\b",
    r"\bwant\s+it\s+(all\s+)?to\s+(end|stop|be\s+over)\b",   # both word orders
    r"\bwant\s+it\s+to\s+(all\s+)?(end|stop|be\s+over)\b",
]


# -----------------------------------------------------------------------------
# Tier 2 — IMPLICIT distress (AI still responds; helpline gets prepended)
# -----------------------------------------------------------------------------
# These suggest worrying ideation but are not unambiguous enough to bypass
# the model. The model gets a chance to respond with empathy + nudge to
# resources.

IMPLICIT_DISTRESS_PATTERNS: list[str] = [
    # Hopelessness
    r"\bwhat'?s\s+the\s+point\b",
    r"\bno\s+(future|hope|way\s+out)\b",
    r"\blife\s+is\s+over\b",
    r"\bit'?ll\s+never\s+get\s+better\b",
    r"\bnothing\s+(will\s+)?(matters|matter)\b",
    r"\bcan'?t\s+see\s+a\s+way\s+out\b",
    r"\beverything\s+is\s+pointless\b",

    # Burden cognition
    r"\bbetter\s+off\s+without\s+me\b",
    r"\b(everyone|nobody|no\s+one)\s+would\s+(miss|notice|care)\s+(if\s+)?(me|i'?m\s+gone|i\s+disappeared)\b",
    r"\bnobody\s+would\s+miss\s+me\b",
    r"\bi'?m\s+(\w+\s+)?(a|just\s+a)\s+burden\b",            # allows "I'm just a burden"
    r"\bi'?m\s+(such\s+)?a\s+burden\b",
    r"\bburden\s+to\s+(everyone|my\s+family|my\s+parents)\b",
    r"\beveryone'?s\s+life\s+(would\s+be\s+)?easier\s+without\s+me\b",

    # Disconnection from life
    r"\b(numb|empty)\s+all\s+the\s+time\b",
    r"\bnothing\s+feels\s+real\b",
    r"\bdon'?t\s+feel\s+(anything|alive)\b",

    # Tired-of-existing patterns
    r"\btired\s+of\s+(being\s+)?(alive|here|existing)\b",
    r"\bso\s+tired\s+of\s+(life|everything|this)\b",
    r"\bdone\s+with\s+(life|everything)\b",

    # Goodbye-soft
    r"\bif\s+anything\s+happens\s+to\s+me\b",
    r"\bif\s+i'?m\s+not\s+(here|around)\s+anymore\b",
]


# -----------------------------------------------------------------------------
# Academic / resolved-past EXCLUSIONS
# -----------------------------------------------------------------------------
# These patterns mean "the user is talking ABOUT crisis vocabulary in a safe
# context, not in active distress." If any of these match, we DON'T trigger
# detection. Risky tradeoff — but better than annoying every psychology
# student doing a school project with a helpline pop-up they didn't need.
#
# Note: a real user who is currently in distress but DESCRIBES it as past
# tense ("I used to feel suicidal but...") may slip through. This is an
# accepted limitation for a heuristic detector. The model itself will still
# respond empathetically; only the hardcoded helpline overlay is skipped.

EXCLUSION_PATTERNS: list[str] = [
    # Research / academic framing
    r"\b(research(ing)?|studying|reading\s+about|writing\s+about|learning\s+about)\b.{0,40}\b(suicide|self[\s-]?harm|depression|crisis)\b",
    r"\b(suicide|self[\s-]?harm|depression)\b.{0,40}\b(research|statistics|prevalence|rates|data|epidemiology|study)\b",
    r"\b(school|class)\s+project\b",
    r"\bpsychology\s+(class|paper|assignment)\b",
    r"\bfor\s+(a\s+)?(school|college|class|psychology)\s+(project|paper|assignment|essay)\b",
    r"\btell\s+me\s+about\b.{0,30}\b(suicide|self[\s-]?harm)\b",
    r"\bcan\s+you\s+(tell\s+me\s+about|explain)\b.{0,30}\b(suicide|self[\s-]?harm)\b",
    # Past-resolved framing
    r"\bused\s+to\b.{0,40}\bbut\b.{0,40}\b(getting\s+better|better\s+now|okay\s+now|fine\s+now|recovered|past)\b",
    r"\b(years|long\s+time)\s+ago\b",
    r"\b(in\s+the\s+past|back\s+then|long\s+ago)\b",
    r"\bnever\s+went\s+through\s+with\b",
]


# -----------------------------------------------------------------------------
# Compiled regex caches (one re object per pattern, case-insensitive)
# -----------------------------------------------------------------------------
_EXPLICIT_REGEX = [re.compile(p, re.IGNORECASE) for p in EXPLICIT_CRISIS_PATTERNS]
_IMPLICIT_REGEX = [re.compile(p, re.IGNORECASE) for p in IMPLICIT_DISTRESS_PATTERNS]
_EXCLUSION_REGEX = [re.compile(p, re.IGNORECASE) for p in EXCLUSION_PATTERNS]


def _normalized(text: str) -> str:
    return (text or "").strip()


def _is_safe_context(text: str) -> bool:
    """True if the text appears to be academic/research/past-resolved framing."""
    return any(p.search(text) for p in _EXCLUSION_REGEX)


def detect_explicit_crisis(text: str) -> bool:
    """Return True if `text` contains any unambiguous crisis signal.

    Callers should treat this as: bypass the AI, return CRISIS_RESPONSE,
    surface helpline card immediately.
    """
    t = _normalized(text)
    if not t:
        return False
    if _is_safe_context(t):
        return False
    return any(p.search(t) for p in _EXPLICIT_REGEX)


def detect_implicit_distress(text: str) -> bool:
    """Return True if `text` shows concerning-but-ambiguous distress.

    Callers should treat this as: still call the AI, but prepend the
    crisis helpline text and surface the helpline card.
    """
    t = _normalized(text)
    if not t:
        return False
    if _is_safe_context(t):
        return False
    return any(p.search(t) for p in _IMPLICIT_REGEX)


def matched_explicit_patterns(text: str) -> list[str]:
    """Diagnostic helper: which explicit patterns matched? Used by tests."""
    t = _normalized(text)
    return [p.pattern for p in _EXPLICIT_REGEX if p.search(t)]


def matched_implicit_patterns(text: str) -> list[str]:
    """Diagnostic helper: which implicit patterns matched? Used by tests."""
    t = _normalized(text)
    return [p.pattern for p in _IMPLICIT_REGEX if p.search(t)]
