# MindBridge — System Architecture

## Three-layer safety + grounding architecture

The MindBridge backend implements the three-layer architecture mandated by the project spec. Each layer has a single responsibility and the layers are independent — a failure or weakness in one layer is partially compensated by the others.

```
┌──────────────────────────────────────────────────────────────────┐
│  USER MESSAGE arrives at POST /chat (or /chat/stream)            │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  AUTH (Test1)                                                    │
│  JWT validation -> reject if no token (401)                      │
│  MongoDB session retrieval                                       │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
┌══════════════════════════════════════════════════════════════════┐
║  LAYER 0 — HARDCODED CRISIS DETECTOR  (backend/crisis.py)        ║
║                                                                  ║
║   72 regex patterns (47 explicit Tier-1, 25 implicit Tier-2)     ║
║   + 12 exclusion patterns for research/past-resolved framings    ║
║                                                                  ║
║   Tier 1 (EXPLICIT): unambiguous crisis -> BYPASS the model.     ║
║       Return hardcoded CRISIS_RESPONSE + helplines (iCall +112). ║
║   Tier 2 (IMPLICIT): concerning -> prepend helpline to model     ║
║       response.                                                  ║
║                                                                  ║
║   Validated: 99.1% recall on 197-prompt adversarial set,         ║
║              1.2% FP rate.                                       ║
║   This layer is the most important code in the project.          ║
║   If Tier-1 matches: no model call. Instant response (0 ms LLM). ║
╚════════════════════════╤═════════════════════════════════════════╝
                         │ (no Tier-1 match)
                         ▼
┌══════════════════════════════════════════════════════════════════┐
║  LAYER 1 — SYSTEM PROMPT (tone)                                  ║
║                                                                  ║
║   Short prompt (~85 words) defining MindBridge identity, rules,  ║
║   and deferred language. Kept short by design — fine-tune        ║
║   carries the heavy behavioural work.                            ║
╚════════════════════════╤═════════════════════════════════════════╝
                         │
                         ▼
┌══════════════════════════════════════════════════════════════════┐
║  LAYER 2 — RAG (factual grounding)  (backend/rag.py)             ║
║                                                                  ║
║   ChromaDB persistent index, ~41 chunks across 8 source docs:    ║
║     • assessments/{gad7, phq9, pss10, asrs, ucla3}.md            ║
║       exact scoring bands, Q9 crisis rule, reverse-scored items  ║
║     • conditions.md  - WHO/NIMH/NIMHANS-grounded descriptions    ║
║     • helplines.md   - iCall, Vandrevala, 112 with hours/scope   ║
║                                                                  ║
║   Embedding model: ChromaDB built-in all-MiniLM-L6-v2 (CPU).     ║
║   Per user message: retrieve top-k=3 chunks, inject into system  ║
║   prompt as authoritative context.                               ║
║                                                                  ║
║   Result: zero hallucination on scoring bands or helpline #s.    ║
╚════════════════════════╤═════════════════════════════════════════╝
                         │
                         ▼
┌══════════════════════════════════════════════════════════════════┐
║  LAYER 3 — FINE-TUNED LLAMA 3.1 8B (behaviour)                   ║
║                                                                  ║
║   Base model: meta-llama/Llama-3.1-8B-Instruct                   ║
║   Training:   QLoRA via Unsloth on RTX A4000 (16 GB VRAM)        ║
║   Dataset:    711 single-turn + 200 synthetic multi-turn pairs   ║
║   Loss:       train 0.55  /  eval 0.696                          ║
║                                                                  ║
║   Serves via local Ollama (port 11434) — streams tokens          ║
║   back to caller as NDJSON.                                      ║
╚════════════════════════╤═════════════════════════════════════════╝
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────┐
│  Persistence: append both user message and model reply to        │
│  MongoDB session.                                                │
│                                                                  │
│  Return: streamed JSON-lines (NDJSON) over Cloudflare tunnel     │
│          {event: start | delta | end, content: "...", ...}       │
└──────────────────────────────────────────────────────────────────┘
```

## Deployment topology

```
┌─────────────────────┐    HTTPS    ┌─────────────────────┐
│  Friend's browser   │ ──────────▶ │  Firebase Hosting    │
│  (anywhere)         │             │  Flutter web build  │
└─────────────────────┘             └──────────┬──────────┘
                                               │ fetch /chat/stream
                                               ▼
                                    ┌─────────────────────┐
                                    │  Cloudflare Tunnel   │
                                    │  trycloudflare.com   │
                                    └──────────┬──────────┘
                                               │ (encrypted)
                                               ▼
                                    ┌─────────────────────┐    Atlas   ┌──────────────┐
                                    │  Your PC: FastAPI    │ ─────────▶ │ MongoDB Atlas │
                                    │  port 8000          │            │ (auth + chat) │
                                    │                     │            └──────────────┘
                                    │  ┌──────────────┐   │
                                    │  │  Ollama       │   │
                                    │  │  port 11434   │   │
                                    │  │  mindbridge-v3│   │
                                    │  └──────────────┘   │
                                    │                     │
                                    │  ┌──────────────┐   │
                                    │  │  ChromaDB     │   │
                                    │  │  local index  │   │
                                    │  └──────────────┘   │
                                    └─────────────────────┘
```

## Key design choices

### Why layered safety instead of trusting the model
A fine-tuned language model is non-deterministic. A regex matcher is. For mental health crisis detection, **deterministic safety wins over probabilistic correctness**. The crisis detector runs BEFORE the model and can BYPASS it entirely. Even if the model has a bad day, the hardcoded response goes out for explicit crisis triggers.

### Why RAG instead of fine-tuning more
Fine-tuning the model on more clinical content would have to be redone every time the helpline number changes or guidelines update. RAG keeps the factual content in markdown files we can edit instantly — no retraining needed for the system to learn that iCall hours changed.

### Why QLoRA + Unsloth instead of full fine-tune
Full fine-tuning Llama 3.1 8B requires ~128 GB VRAM. We have 16 GB. QLoRA quantises the base model to 4-bit (~5 GB on disk) and trains only small adapter weights (~167 MB). Unsloth's kernels reduce QLoRA's VRAM footprint a further 2-3× so training fits with headroom on an RTX A4000.

### Why stream tokens instead of waiting
A 4-second wait for a 100-word response feels broken. Streaming the response token-by-token (NDJSON over HTTP) shows partial output starting ~1 second after the user hits send, matching the UX expectations set by ChatGPT.
