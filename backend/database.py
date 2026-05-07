from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo import ASCENDING

_client: AsyncIOMotorClient | None = None
_db: AsyncIOMotorDatabase | None = None


async def init_db(mongodb_uri: str) -> None:
    global _client, _db
    _client = AsyncIOMotorClient(mongodb_uri)
    _db = _client.mindbridge
    
    users_collection = _db.users
    await users_collection.create_index("username", unique=True)
    
    sessions_collection = _db.chat_sessions
    await sessions_collection.create_index([("session_id", ASCENDING), ("user_id", ASCENDING)])
    await sessions_collection.create_index("user_id")


async def create_user(username: str, password_hash: str) -> Dict[str, Any]:
    if _db is None:
        raise RuntimeError("Database not initialized")
    
    users_collection = _db.users
    username_lower = username.lower()
    
    existing = await users_collection.find_one({"username": username_lower})
    if existing:
        raise ValueError(f"Username '{username}' is already taken")
    
    doc = {
        "username": username_lower,
        "password_hash": password_hash,
        "created_at": datetime.utcnow(),
    }
    result = await users_collection.insert_one(doc)
    doc["_id"] = result.inserted_id
    return doc


async def get_user_by_username(username: str) -> Dict[str, Any] | None:
    if _db is None:
        raise RuntimeError("Database not initialized")
    
    users_collection = _db.users
    username_lower = username.lower()
    return await users_collection.find_one({"username": username_lower})


async def append_chat_message(
    session_id: str, user_id: str, username: str, user_message: str, bot_message: str
) -> None:
    if _db is None:
        raise RuntimeError("Database not initialized")
    
    sessions_collection = _db.chat_sessions
    now = datetime.utcnow().isoformat()
    
    message_user = {"role": "user", "content": user_message, "timestamp": now}
    message_bot = {"role": "assistant", "content": bot_message, "timestamp": now}
    
    await sessions_collection.update_one(
        {"session_id": session_id, "user_id": user_id},
        {
            "$push": {"messages": {"$each": [message_user, message_bot]}},
            "$set": {
                "session_id": session_id,
                "user_id": user_id,
                "username": username,
                "updated_at": datetime.utcnow(),
            },
            "$setOnInsert": {
                "created_at": datetime.utcnow(),
            },
        },
        upsert=True,
    )


async def get_session_history(session_id: str, user_id: str) -> List[Dict[str, Any]]:
    if _db is None:
        raise RuntimeError("Database not initialized")
    
    sessions_collection = _db.chat_sessions
    session = await sessions_collection.find_one({"session_id": session_id, "user_id": user_id})
    
    if session is None:
        return []
    
    return session.get("messages", [])


async def get_chat_history(user_id: str) -> List[Dict[str, Any]]:
    if _db is None:
        raise RuntimeError("Database not initialized")
    
    sessions_collection = _db.chat_sessions
    cursor = sessions_collection.find({"user_id": user_id}).sort("updated_at", -1)
    sessions = await cursor.to_list(length=None)
    
    return [
        {
            "session_id": session.get("session_id"),
            "user_id": session.get("user_id"),
            "username": session.get("username"),
            "messages": session.get("messages", []),
            "created_at": session.get("created_at").isoformat() if session.get("created_at") else None,
            "updated_at": session.get("updated_at").isoformat() if session.get("updated_at") else None,
        }
        for session in sessions
    ]


async def delete_session(session_id: str, user_id: str) -> bool:
    if _db is None:
        raise RuntimeError("Database not initialized")
    
    sessions_collection = _db.chat_sessions
    result = await sessions_collection.delete_one({"session_id": session_id, "user_id": user_id})
    
    return result.deleted_count > 0
