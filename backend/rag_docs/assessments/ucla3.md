# UCLA-3 — UCLA Three-Item Loneliness Scale

## What it is
The UCLA Three-Item Loneliness Scale (Hughes, Waite, Hawkley, & Cacioppo, 2004) is a short-form derivative of the longer 20-item UCLA Loneliness Scale (Russell, 1996). It measures three core dimensions of subjective loneliness and is the most widely used brief loneliness instrument in research.

## What it measures
Over the past two weeks (or "in general"), how often do you...

1. Feel that you lack companionship?
2. Feel left out?
3. Feel isolated from others?

Each item is rated on a 3-point scale:
- 1 = Hardly ever
- 2 = Some of the time
- 3 = Often

## Scoring bands
Total score is 3–9. The bands typically used:

- **3–4 Low loneliness.** Either not feeling lonely or only fleetingly.
- **5–6 Moderate loneliness.** Meaningful but manageable feelings of disconnection.
- **7–9 High loneliness.** Persistent and significant loneliness; warrants attention.

A cutoff of **≥6** is often used in research as the threshold for "feels lonely."

## Note on scale range confusion
The longer 20-item UCLA Loneliness Scale (Russell, 1996) has a range of 20–80. The brief UCLA-3 (Hughes et al., 2004) has a range of 3–9. These are different instruments. MindBridge uses the 3-item version because:
- It is appropriate for repeated brief screening in a chatbot context
- The longer scale is impractical for a 7-question per-screen UX
- The 3-item version has demonstrated good convergent validity with the longer scale (r ≈ 0.82)

## CRITICAL framing rules — tone for loneliness
Loneliness is a feeling state, not a clinical disorder. Treat it with warmth and normalisation, NOT pathology language. The PDF spec is explicit: "Loneliness results must be warm and connection-focused, never catastrophising."

**Required tone**:
- Normalise: "Loneliness is something almost everyone experiences at some point — especially during transitions like moving to a new city or starting college."
- Avoid clinical labelling: never say "you have loneliness disorder" — there is no such thing.
- Connection-focused suggestions: small concrete actions ("one short conversation a day", "join one activity that has regulars", "reach out to one specific person you trust").
- For high scores (≥7), still recommend professional support but frame it as "talking through what's making connection feel hard right now" rather than "treatment."

## Why UCLA-3 was chosen over OCI-R for the 5th MindBridge condition
The original MindBridge spec considered OCD (OCI-R) as the 5th condition. It was replaced with loneliness (UCLA-3) for three reasons:
1. **False-positive risk**: OCI-R has a high false-positive rate in non-clinical populations because normal intrusive thoughts overlap with OCD symptoms.
2. **Harm asymmetry**: A false-positive OCD screen is significantly more harmful than a false-positive loneliness screen (OCD diagnosis is more stigmatising and pathologising).
3. **Population relevance**: UCLA-3 is validated in Indian student populations and post-COVID loneliness rates in this group are well-documented.

## Indian context
- Post-COVID loneliness in Indian university students rose significantly (multiple studies 2021-2024).
- Hostel and migrant student populations report particularly high loneliness during first-year transitions.
- Cultural note: in collectivist family contexts, students often feel that admitting loneliness is shameful ("you have family, how can you be lonely"). Validation that loneliness can co-exist with having family is important.
