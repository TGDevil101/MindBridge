from scoring import score_assessment


def test_pss10_reverse_scoring_items_4_5_7_8():
    # Items 4, 5, 7, 8 are reverse-scored in PSS-10 (1-based indexing).
    # Input all zeros => reverse items become 4 each; expected total = 16.
    answers = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    result = score_assessment("stress", answers)
    assert result["score"] == 16
    assert result["band"] == "Moderate"


def test_phq9_q9_non_zero_triggers_crisis():
    answers = [0, 0, 0, 0, 0, 0, 0, 0, 1]
    result = score_assessment("depression", answers)
    assert result["crisis_trigger"] is True
