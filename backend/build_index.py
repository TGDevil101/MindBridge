"""Rebuild the RAG index from rag_docs/. Run any time the docs change.

Usage:
    python build_index.py
"""
from rag import build_index, retrieve

n = build_index(verbose=True)
print(f"\n=== Index built: {n} chunks ===\n")

print("=== Smoke test: a few retrieval queries ===\n")
for q in [
    "what does a GAD-7 score of 14 mean",
    "PHQ-9 question 9 about self-harm",
    "iCall helpline number",
    "what is loneliness",
    "ASRS Part A scoring",
]:
    print(f"Q: {q!r}")
    results = retrieve(q, k=2)
    for r in results:
        print(f"  [{r['score']:.2f}] {r['title']} / {r['section']}")
    print()
