from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List

from sqlalchemy import JSON, Column, DateTime, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = "sqlite:///./mindbridge.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class ChatSession(Base):
    __tablename__ = "chat_sessions"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String, nullable=False, index=True)
    user_type = Column(String, nullable=False)
    messages = Column(JSON, nullable=False, default=list)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)


def init_db() -> None:
    Base.metadata.create_all(bind=engine)


def append_chat_message(session_id: str, user_type: str, user_message: str, bot_message: str) -> None:
    db = SessionLocal()
    try:
        record = (
            db.query(ChatSession)
            .filter(ChatSession.session_id == session_id)
            .order_by(ChatSession.id.desc())
            .first()
        )

        if record is None:
            record = ChatSession(
                session_id=session_id,
                user_type=user_type,
                messages=[],
            )
            db.add(record)
            db.flush()

        messages: List[Dict[str, Any]] = list(record.messages or [])
        now = datetime.utcnow().isoformat()
        messages.append({"role": "user", "content": user_message, "timestamp": now})
        messages.append({"role": "assistant", "content": bot_message, "timestamp": now})
        record.messages = messages
        db.commit()
    finally:
        db.close()


def get_session_history(session_id: str) -> List[Dict[str, Any]]:
    """Return the message list for a specific session, for passing to the LLM as context."""
    db = SessionLocal()
    try:
        record = (
            db.query(ChatSession)
            .filter(ChatSession.session_id == session_id)
            .order_by(ChatSession.id.desc())
            .first()
        )
        if record is None:
            return []
        return list(record.messages or [])
    finally:
        db.close()


def get_chat_history() -> List[Dict[str, Any]]:
    db = SessionLocal()
    try:
        records = db.query(ChatSession).order_by(ChatSession.updated_at.desc()).all()
        return [
            {
                "session_id": record.session_id,
                "user_type": record.user_type,
                "messages": record.messages or [],
                "created_at": record.created_at.isoformat() if record.created_at else None,
                "updated_at": record.updated_at.isoformat() if record.updated_at else None,
            }
            for record in records
        ]
    finally:
        db.close()
