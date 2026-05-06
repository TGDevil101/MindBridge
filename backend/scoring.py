from __future__ import annotations

from typing import Dict, List

from crisis import CRISIS_RESPONSE


def _validate_answers(answers: List[int], expected_len: int, min_v: int, max_v: int) -> None:
    if len(answers) != expected_len:
        raise ValueError(f"Expected {expected_len} answers, got {len(answers)}")
    for value in answers:
        if not isinstance(value, int) or value < min_v or value > max_v:
            raise ValueError(f"All answers must be integers between {min_v} and {max_v}")


def _gad7(answers: List[int]) -> Dict:
    _validate_answers(answers, 7, 0, 3)
    score = sum(answers)
    if score <= 4:
        band = "Minimal"
    elif score <= 9:
        band = "Mild"
    elif score <= 14:
        band = "Moderate"
    else:
        band = "Severe"
    return {
        "assessment_type": "anxiety",
        "score": score,
        "band": band,
        "summary": (
            f"Your anxiety screening score is {score} ({band}). "
            "This is not a diagnosis."
        ),
        "show_icall": score >= 10,
        "recommend_professional": score >= 10,
    }


def _phq9(answers: List[int]) -> Dict:
    _validate_answers(answers, 9, 0, 3)
    score = sum(answers)
    q9 = answers[8]
    crisis_trigger = q9 > 0
    if score <= 4:
        band = "Minimal"
    elif score <= 9:
        band = "Mild"
    elif score <= 14:
        band = "Moderate"
    elif score <= 19:
        band = "Moderately Severe"
    else:
        band = "Severe"
    result = {
        "assessment_type": "depression",
        "score": score,
        "band": band,
        "summary": (
            f"Your depression screening score is {score} ({band}). "
            "This is not a diagnosis."
        ),
        "show_icall": score >= 10 or crisis_trigger,
        "recommend_professional": score >= 10 or crisis_trigger,
        "crisis_trigger": crisis_trigger,
    }
    if crisis_trigger:
        result["crisis_response"] = CRISIS_RESPONSE
    return result


def _pss10(answers: List[int]) -> Dict:
    _validate_answers(answers, 10, 0, 4)
    reverse_scored_indices = {3, 4, 6, 7}
    scored_answers = []
    for idx, value in enumerate(answers):
        if idx in reverse_scored_indices:
            scored_answers.append(4 - value)
        else:
            scored_answers.append(value)
    score = sum(scored_answers)
    if score <= 13:
        band = "Low"
    elif score <= 26:
        band = "Moderate"
    else:
        band = "High"
    return {
        "assessment_type": "stress",
        "score": score,
        "band": band,
        "summary": (
            f"Your stress screening score is {score} ({band}). "
            "This is not a diagnosis."
        ),
        "show_icall": score >= 14,
        "recommend_professional": score >= 14,
    }


def _asrs_part_a(answers: List[int]) -> Dict:
    _validate_answers(answers, 6, 0, 1)
    symptom_count = sum(answers)
    screen_positive = symptom_count >= 4
    return {
        "assessment_type": "adhd",
        "score": symptom_count,
        "band": "Screen Positive" if screen_positive else "Screen Negative",
        "summary": (
            f"You endorsed {symptom_count} out of 6 Part A items. "
            "This is a screening result, not a diagnosis."
        ),
        "screen_positive": screen_positive,
        "show_icall": screen_positive,
        "recommend_professional": screen_positive,
    }


def _ucla3(answers: List[int]) -> Dict:
    _validate_answers(answers, 3, 1, 3)
    score = sum(answers)
    if score <= 4:
        band = "Low"
    elif score <= 6:
        band = "Moderate"
    else:
        band = "High"
    return {
        "assessment_type": "loneliness",
        "score": score,
        "band": band,
        "summary": (
            f"Your loneliness screening score is {score} ({band}). "
            "Feeling disconnected can happen to anyone, and support is available. "
            "This is not a diagnosis."
        ),
        "show_icall": score >= 7,
        "recommend_professional": score >= 7,
    }


def score_assessment(assessment_type: str, answers: List[int]) -> Dict:
    normalized = (assessment_type or "").strip().lower()
    if normalized == "anxiety":
        return _gad7(answers)
    if normalized == "depression":
        return _phq9(answers)
    if normalized == "stress":
        return _pss10(answers)
    if normalized == "adhd":
        return _asrs_part_a(answers)
    if normalized == "loneliness":
        return _ucla3(answers)
    raise ValueError(f"Unsupported assessment type: {assessment_type}")
