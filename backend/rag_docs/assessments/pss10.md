# PSS-10 — Perceived Stress Scale 10-item

## What it is
The PSS-10 is a 10-question scale developed by Cohen et al. (1983) measuring the degree to which a person perceives their life as unpredictable, uncontrollable, and overloaded over the past month. It is the most widely used psychological stress instrument worldwide.

## What it measures
Over the past month, how often have you...

1. Been upset because of something that happened unexpectedly?
2. Felt that you were unable to control the important things in your life?
3. Felt nervous and "stressed"?
4. **(reverse-scored)** Felt confident about your ability to handle your personal problems?
5. **(reverse-scored)** Felt that things were going your way?
6. Found that you could not cope with all the things you had to do?
7. **(reverse-scored)** Been able to control irritations in your life?
8. **(reverse-scored)** Felt that you were on top of things?
9. Been angered because of things that were outside of your control?
10. Felt difficulties were piling up so high that you could not overcome them?

Each item is rated 0–4:
- 0 = Never
- 1 = Almost never
- 2 = Sometimes
- 3 = Fairly often
- 4 = Very often

## CRITICAL: Reverse-scored items
Items 4, 5, 7, and 8 are **reverse-scored**. The scoring transformation is:
- Original response 0 → scored as 4
- Original response 1 → scored as 3
- Original response 2 → scored as 2
- Original response 3 → scored as 1
- Original response 4 → scored as 0

This is because these items are positively worded ("felt confident", "things going your way") and a high frequency of positive coping is consistent with LOW perceived stress.

**Implementation note**: In `backend/scoring.py`, the indices of reverse-scored items in a 0-indexed array are `{3, 4, 6, 7}`. A silent scoring error here would invalidate every PSS-10 result in the system.

## Scoring bands
Total score is 0–40. The bands are:

- **0–13 Low perceived stress.** Within typical range for adults.
- **14–26 Moderate perceived stress.** Common during high-pressure periods (exam season, life transitions). Self-care strategies indicated.
- **27–40 High perceived stress.** Significant stress load with likely physical and cognitive impact. Professional support recommended.

## Important framing rules
- PSS-10 measures *perceived* stress — how stressful life feels — not necessarily an objective measure of stressors.
- Use deferred language: "your responses are associated with a [moderate/high] level of perceived stress."
- Do not call a high score a disorder. Stress is a state, not a diagnosis.

## Indian context
- PSS-10 has been validated in Indian student populations across multiple studies (Lee, 2012 review; multiple Indian adaptations).
- Indian respondents often score high during academic pressure peaks (e.g. board exam season, entrance test cycles).
