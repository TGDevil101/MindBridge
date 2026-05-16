"""
RAG (Retrieval-Augmented Generation) layer for MindBridge.

Architecture (per the PDF spec):
  Layer 1: System prompt (tone enforcement) -- stays short, in ollama_client
  Layer 2: RAG (factual accuracy at runtime) -- THIS MODULE
  Layer 3: Fine-tuned Llama 3.1 8B (behaviour) -- the QLoRA model

What this gives us:
  - GAD-7 / PHQ-9 / PSS-10 / ASRS / UCLA-3 scoring bands retrieved at runtime
    instead of relying on the model's parametric memory (which hallucinates).
  - Helpline numbers always current (single source of truth in helplines.md).
  - Indian-context clinical content from authored docs rather than the
    model's training mix.

Storage: persistent ChromaDB at backend/rag_index/. Embedding model
defaults to ChromaDB's built-in 'all-MiniLM-L6-v2' (sentence-transformers,
~80MB, runs on CPU, no GPU contention with Ollama).

Build once via `python build_index.py`. Then `import rag; rag.retrieve(query, k=3)`.
"""
from __future__ import annotations

import os
import re
from pathlib import Path
from typing import List, Dict, Optional

# Disable telemetry BEFORE importing chromadb (otherwise it tries to phone home).
os.environ.setdefault("ANONYMIZED_TELEMETRY", "False")
os.environ.setdefault("CHROMA_TELEMETRY", "False")

import chromadb
from chromadb.config import Settings

BACKEND_DIR = Path(__file__).parent
DOCS_DIR = BACKEND_DIR / "rag_docs"
INDEX_DIR = BACKEND_DIR / "rag_index"
COLLECTION_NAME = "mindbridge_v1"


# ---------------------------------------------------------------------------
# Chunking
# ---------------------------------------------------------------------------
# Strategy: split each markdown file on top-level (`# `) and second-level
# (`## `) headers. Each chunk gets the doc title + section header(s) as
# metadata so retrieval results are self-identifying.

def _split_markdown(text: str) -> List[Dict[str, str]]:
    """Return list of {title, section, content} dicts."""
    lines = text.splitlines()
    title = ""
    current_section = ""
    buffer: list[str] = []
    chunks: list[dict] = []

    def flush():
        body = "\n".join(buffer).strip()
        if body:
            chunks.append({"title": title, "section": current_section, "content": body})
        buffer.clear()

    for line in lines:
        if line.startswith("# "):
            flush()
            title = line.lstrip("# ").strip()
            current_section = ""
        elif line.startswith("## "):
            flush()
            current_section = line.lstrip("# ").strip()
        else:
            buffer.append(line)

    flush()
    return chunks


def load_chunks_from_docs(docs_dir: Path = DOCS_DIR) -> List[Dict[str, str]]:
    chunks: list[dict] = []
    for md_path in sorted(docs_dir.rglob("*.md")):
        rel = md_path.relative_to(docs_dir).as_posix()
        text = md_path.read_text(encoding="utf-8")
        for chunk in _split_markdown(text):
            chunk["source"] = rel
            chunks.append(chunk)
    return chunks


# ---------------------------------------------------------------------------
# Client + collection helpers
# ---------------------------------------------------------------------------

_client: Optional[chromadb.PersistentClient] = None
_collection = None


def _get_client() -> chromadb.PersistentClient:
    global _client
    if _client is None:
        INDEX_DIR.mkdir(parents=True, exist_ok=True)
        _client = chromadb.PersistentClient(
            path=str(INDEX_DIR),
            settings=Settings(anonymized_telemetry=False),
        )
    return _client


def get_collection():
    global _collection
    if _collection is None:
        client = _get_client()
        _collection = client.get_or_create_collection(
            name=COLLECTION_NAME,
            metadata={"hnsw:space": "cosine"},
        )
    return _collection


# ---------------------------------------------------------------------------
# Index build
# ---------------------------------------------------------------------------

def build_index(verbose: bool = True) -> int:
    """Rebuild the index from scratch from rag_docs/. Returns # chunks indexed."""
    client = _get_client()
    # Wipe + recreate to ensure a clean build
    try:
        client.delete_collection(COLLECTION_NAME)
    except Exception:
        pass

    collection = client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={"hnsw:space": "cosine"},
    )

    chunks = load_chunks_from_docs()
    if verbose:
        print(f"Indexing {len(chunks)} chunks from {DOCS_DIR}")

    ids = []
    documents = []
    metadatas = []
    for i, ch in enumerate(chunks):
        # ID encodes source + section so duplicates can be deduped easily
        slug = re.sub(r"[^a-z0-9]+", "_", (ch["source"] + "::" + ch["section"]).lower()).strip("_")
        ids.append(f"{i:03d}__{slug}"[:128])
        # Prepend the title + section to the embedded content so semantic
        # search picks up the topic even when the body is generic.
        text = f"{ch['title']} — {ch['section']}\n\n{ch['content']}" if ch["section"] else f"{ch['title']}\n\n{ch['content']}"
        documents.append(text)
        metadatas.append({
            "source": ch["source"],
            "title": ch["title"],
            "section": ch["section"],
        })

    collection.add(ids=ids, documents=documents, metadatas=metadatas)
    # Refresh module-level reference so subsequent retrieve() sees new collection
    global _collection
    _collection = collection
    if verbose:
        print(f"Indexed {len(chunks)} chunks. Stored at {INDEX_DIR}")
    return len(chunks)


# ---------------------------------------------------------------------------
# Retrieval
# ---------------------------------------------------------------------------

def retrieve(query: str, k: int = 3) -> List[Dict[str, str]]:
    """Return top-k chunks. Each entry: {source, title, section, content, score}."""
    if not query or not query.strip():
        return []

    collection = get_collection()
    if collection.count() == 0:
        return []

    n_results = min(k, collection.count())
    res = collection.query(query_texts=[query], n_results=n_results)

    out: list[dict] = []
    docs = res.get("documents", [[]])[0]
    metas = res.get("metadatas", [[]])[0]
    dists = res.get("distances", [[]])[0]
    for doc, meta, dist in zip(docs, metas, dists):
        # cosine distance -> similarity (1 - distance)
        score = float(1.0 - dist) if dist is not None else 0.0
        out.append({
            "source": meta.get("source", ""),
            "title": meta.get("title", ""),
            "section": meta.get("section", ""),
            "content": doc,
            "score": round(score, 3),
        })
    return out


def format_for_prompt(chunks: List[Dict[str, str]], max_chars: int = 2400) -> str:
    """Render retrieved chunks as a compact context block for the system prompt."""
    if not chunks:
        return ""
    parts = ["[Retrieved clinical reference — quote exactly when relevant, do NOT invent details]"]
    total = len(parts[0])
    for ch in chunks:
        block = f"\n--- {ch['title']} / {ch['section']} ---\n{ch['content']}\n"
        if total + len(block) > max_chars:
            break
        parts.append(block)
        total += len(block)
    return "".join(parts)
