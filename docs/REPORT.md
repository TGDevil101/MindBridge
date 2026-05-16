# MindBridge — Final Project Report

> An AI-powered mental health awareness chatbot for Indian students and parents, built as an 8-week proof-of-concept by a 3-person team.

**Team**: Angad (coder), Siddhi (dataset), Shambhavi (research/QA)
**Hardware**: NVIDIA RTX A4000 (16 GB VRAM) on a single local PC
**Cost**: ₹0 — everything runs locally except MongoDB Atlas free tier

## Live demo

- **App**: https://mindbridge-101-2c6e2.web.app
- **Backend**: FastAPI on Cloudflare tunnel → local PC with Ollama serving `mindbridge-v3`
- **Database**: MongoDB Atlas (auth + chat history)

## What was built

### The 3-layer safety + grounding architecture

```
USER MESSAGE
    │
    ▼
[LAYER 0]  72-pattern crisis detector  ───► (Tier-1 match)  ───► hardcoded helpline (BYPASS LLM)
    │ (no Tier-1 match)
    ▼
[LAYER 1]  Short tone-defining system prompt
    │
    ▼
[LAYER 2]  RAG retrieval from 41 indexed clinical chunks (ChromaDB)
    │
    ▼
[LAYER 3]  Fine-tuned Llama 3.1 8B (mindbridge-v3, QLoRA, 41M trained params)
    │
    ▼
Streamed token response back to the Flutter UI
```

See [ARCHITECTURE.md](./ARCHITECTURE.md) for the detailed diagram and [MODEL_CARD.md](./MODEL_CARD.md) for full model details.

## Evaluation summary — the numbers

### 1. Training convergence (v3, 911 examples, 2 epochs)

| Epoch | Train loss | Eval loss |
|---|---|---|
| 0.18 | 1.41 | 0.97 |
| 0.53 | 0.78 | 0.75 |
| 0.88 | 0.75 | 0.71 |
| 1.93 | 0.54 | **0.70** |

Train-eval gap of 0.14 indicates mild but acceptable overfitting; the validation loss flattens by epoch 1.5, justifying our 2-epoch choice empirically.

### 2. Single-turn test set (n=96, held out from training and validation)

| Metric | base Llama 3.1 8B | mindbridge-v3 (ours) |
|---|---|---|
| Diagnosis violation rate | 0.0% | 1.0%\* |
| **Helpline mention rate** | **6.2%** | **47.9%** |
| Toxic positivity rate | 0.0% | 0.0% |
| Avg response length | 71 words | 115 words |
| Helpline mention — parent queries | 4.3% | **69.6%** (16× lift) |
| Helpline mention — assessment queries | 13.6% | **68.2%** (5× lift) |
| Helpline mention — referral queries | 33.3% | **100%** |

\*Both flagged violations are heuristic false positives (the model says "you are anxious" to acknowledge user-stated feelings, not to diagnose). Manual review: 0 actual violations.

### 3. Adversarial red-team (n=197 prompts, 17 categories)

| Iteration | Crisis recall | Misses | FP rate |
|---|---|---|---|
| Initial 14-keyword detector | 58.9% | 46 | 1.2% |
| Expanded to 72 regex patterns (after unit-test gap analysis) | 95.5% | 5 | 1.2% |
| **Final (after red-team-informed patterns added)** | **99.1%** | **1** | **1.2%** |

The single remaining miss is `i wnt 2 die` — text-speak, a fundamental regex limit. Resolution requires either leetspeak normalisation or an ML-based classifier (future work).

By category at v3:
- Direct ideation, methods, goodbye signals, self-harm, slang, indirect language, implicit distress, parent-reported child crisis, referral, refusal: **100% recall**
- Disguised/fictional framing ("asking for a friend", role-play, novel framing): **88% recall**
- Edge cases (text-speak): 83% recall

### 4. Multi-turn behavioural improvement (qualitative)

A 3-conversation vibe check showed v3 — trained with 200 synthetic multi-turn examples — visibly:
- Asks more open-ended follow-up questions
- Maintains warmth across 3-4 turns
- Produces more conversational (~6% shorter) responses

The tradeoff: -7pp single-turn helpline mention rate vs v2 (mitigated by the hardcoded Layer-0 crisis detector that runs *before* the model on all messages).

## The 10 originally-scoped improvements: what we did

| # | Item | Status | Headline |
|---|---|---|---|
| 1 | Held-out test set + eval framework + train/eval loss curves | ✅ Done | 0.14 train-eval gap @ 2 epochs |
| 2 | Streaming responses (NDJSON) over HTTP | ✅ Done | First token at ~1 sec; full streaming through Cloudflare tunnel verified |
| 3 | Groq 70B baseline | ⏭️ Skipped | Deprioritised — base 8B comparison sufficient |
| 4 | Stronger regex-based crisis layer + 90-case unit test suite | ✅ Done | 100% unit test recall, 0% FP |
| 5 | Adversarial red-team eval (197 prompts × 17 categories) | ✅ Done | Iterated 58.9% → 99.1% recall |
| 6 | Ablation studies (epochs, rank, target modules) | ⏭️ Skipped | Loss curve already supports 2-epoch choice |
| 7 | RAG with ChromaDB (41 chunks across 8 source docs) | ✅ Done | Model now quotes exact scoring bands + helplines verbatim |
| 8 | Multi-turn training data (200 synthetic + 711 single) → v3 | ✅ Done | Visibly more conversational; -7pp helpline mention tradeoff |
| 9 | DPO (preference-optimisation refinement after SFT) | ⏭️ Skipped (future work) | Requires team labelling effort |
| 10 | Architecture diagram + model card + this report | ✅ Done | You're reading it |

**7 / 10 implemented, 3 explicitly skipped with justification.**

## Engineering artefacts

| | |
|---|---|
| Backend | FastAPI + Pydantic + JWT auth + Motor (async Mongo) + httpx + ChromaDB |
| Frontend | Flutter web (Material 3), deployed to Firebase Hosting |
| Tunnel | Cloudflare Tunnel (free tier) — `*.trycloudflare.com` |
| Model serving | Ollama (local), GGUF format converted via llama.cpp |
| Embeddings | ChromaDB built-in all-MiniLM-L6-v2 (CPU) |
| Training | Unsloth + TRL SFTTrainer + bitsandbytes 4-bit QLoRA |
| Test suites | pytest (crisis detector: 90 cases), heuristic eval pipeline (96 test prompts), red-team (197 adversarial prompts) |

## What we'd do with more time

1. **ML-based crisis classifier** (DistilBERT) layered on top of the regex detector — would catch text-speak and novel euphemisms the regex misses.
2. **DPO refinement** on a 200-pair team-labelled preference set, particularly targeting the single-turn helpline-mention regression in v3 and the residual heuristic violations.
3. **Multi-turn evaluation set** — 50 hand-crafted multi-turn conversations with rubric-based scoring, to validate v3 quantitatively rather than just via vibe check.
4. **Hinglish / Indian-language support** — current model is English-only.
5. **Move backend deployment off the operator's PC** (Cloud GPU like Vast.ai or Runpod) — currently the system requires the team's PC to be online.
6. **Formal clinician review** of the full 894-pair training dataset (only crisis pairs got line-by-line review).
7. **DPDP Act 2023 compliance audit** before any non-academic deployment — consent flow, data residency, right to deletion.

## Honest limitations

This is a student POC, not a clinical tool. Specifically:
- The fine-tune is on synthetic + curated student-team-written data, not on professional therapy transcripts.
- The crisis detector achieves 99.1% recall on a 197-prompt adversarial set we wrote ourselves — a real production deployment would need a much larger, professionally-labelled adversarial set.
- The model serves through the team's home internet via a free Cloudflare tunnel — uptime is "when the PC is on" rather than 24/7.
- Privacy: MongoDB Atlas stores usernames and chat history. We do not collect PII at intake (only user type and age range per DPDP Act 2023 considerations), but a real deployment needs a full privacy policy and right-to-deletion implementation.

## Reproducibility

All code, training scripts, dataset (without PII), source documents, and eval results are at:

> **https://github.com/TGDevil101/MindBridge**

To reproduce the model from scratch on a 16 GB GPU:

```bash
# 1. Install training environment
cd backend && python -m venv .venv && .venv/bin/pip install -r requirements.txt

# 2. Split dataset and train
python split_dataset.py
python train_mindbridge_v3.py   # ~44 min on RTX A4000

# 3. Convert to GGUF and import to Ollama
python ~/llama.cpp/convert_lora_to_gguf.py \
       --outfile mindbridge-lora-v3.gguf --outtype f16 \
       --base-model-id unsloth/Meta-Llama-3.1-8B-Instruct \
       mindbridge-lora-v3
ollama create mindbridge-v3 -f Modelfile.v3

# 4. Build RAG index
python build_index.py

# 5. Run backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000

# 6. Run eval suite
python evaluate.py --model mindbridge-v3 --label v3
python run_redteam.py --base-url http://localhost:8000 ...
pytest backend/tests/test_crisis.py
```

---

## Acknowledgements

- **Meta AI** — Llama 3.1 8B base model
- **Unsloth team** — QLoRA-on-consumer-GPU implementation
- **TISS Mumbai (iCall)** + **Vandrevala Foundation** — helpline information used in our RAG corpus
- **WHO mhGAP**, **NIMH**, **NIMHANS** — clinical content sources
- Original instrument authors: Spitzer et al. (GAD-7), Kroenke et al. (PHQ-9), Cohen et al. (PSS-10), Kessler et al. (ASRS), Hughes et al. (UCLA-3)
