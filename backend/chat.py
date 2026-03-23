# chat.py - Handles Gemini text chat with conversation memory
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
import httpx
import os
from datetime import datetime, date, timezone
from sqlalchemy.orm import Session
from sqlalchemy import and_
from db import get_db
from models import ChatUsage, Profile
from otp import verify_token, get_user_identifier

router = APIRouter(prefix="/chat", tags=["chat"])

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

MAX_MESSAGES_PER_DAY = 1000
MAX_CHARACTERS_PER_MESSAGE = 3000

# In-memory conversation storage keyed by user_id
conversations = {}


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    todos: List[str]
    is_new_conversation: bool = False


class ChatResponse(BaseModel):
    response: str
    conversation_ended: bool = False


def build_system_prompt(todos: List[str]) -> str:
    if not todos:
        return """You are a good friend who is genuinely thrilled to see the user has no pending tasks. Congratulate them warmly and enthusiastically — they have everything done! Tell them they've earned a real break and should enjoy their free time guilt-free. Be upbeat, celebratory, and encouraging. If the conversation ends, evaluate it as a success and allow unblocking."""

    todos_list = "\n".join([f"{i+1}. {todo}" for i, todo in enumerate(todos)])

    return f"""You are a good friend that is lightly scolding the user for spending too much time doomscrolling or mindlessly using the internet. The user has the following tasks to do:

{todos_list}

Make sure to list quickly the things the user has to do, all of them. Enumerate them. You are skeptical if the user says they finished the tasks but are easy to convince after they provide evidence or explanation.

Keep your responses concise and friendly but firm. Remember the conversation context as it progresses."""


def detect_conversation_end(user_message: str) -> bool:
    end_phrases = [
        "i'm done",
        "i'm finished",
        "conversation is over",
        "we're done",
        "that's it",
        "end conversation",
        "ready to evaluate",
        "done talking",
        "finished talking"
    ]
    message_lower = user_message.lower().strip()
    return any(phrase in message_lower for phrase in end_phrases)


def check_chat_limits(db: Session, phone: str):
    today = date.today()
    
    usage = db.query(ChatUsage).filter(
        and_(
            ChatUsage.phone == phone,
            ChatUsage.usage_date == today
        )
    ).first()
    
    if not usage:
        return (True, 0)
    
    can_send = usage.message_count < MAX_MESSAGES_PER_DAY
    return (can_send, usage.message_count)


def record_chat_message(db: Session, phone: str):
    today = date.today()
    
    usage = db.query(ChatUsage).filter(
        and_(
            ChatUsage.phone == phone,
            ChatUsage.usage_date == today
        )
    ).first()
    
    if not usage:
        usage = ChatUsage(
            phone=phone,
            usage_date=today,
            message_count=0
        )
        db.add(usage)
    
    usage.message_count += 1
    usage.updated_at = datetime.now(timezone.utc)
    
    db.commit()
    db.refresh(usage)


@router.post("/message")
async def send_chat_message(
    request: ChatRequest,
    user_id: str = Depends(verify_token),
    db: Session = Depends(get_db)
):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Gemini API key not configured")
    
    phone = get_user_identifier(user_id, db)

    # Require premium subscription to access AI chat
    profile = db.query(Profile).filter(Profile.phone == phone).first()
    if not profile or not profile.is_premium:
        raise HTTPException(
            status_code=403,
            detail="Premium subscription required to use AI chat."
        )

    if len(request.message) > MAX_CHARACTERS_PER_MESSAGE:
        raise HTTPException(
            status_code=400,
            detail=f"Message too long. Maximum {MAX_CHARACTERS_PER_MESSAGE} characters allowed."
        )
    
    can_send, messages_sent = check_chat_limits(db, phone)
    if not can_send:
        raise HTTPException(
            status_code=429,
            detail=f"Daily message limit reached. You've sent {messages_sent} messages today (limit: {MAX_MESSAGES_PER_DAY})."
        )
    
    if request.is_new_conversation or user_id not in conversations:
        conversations[user_id] = {
            "history": [],
            "todos": request.todos,
            "started_at": datetime.now()
        }
        system_prompt = build_system_prompt(request.todos)
        conversations[user_id]["history"].append({
            "role": "user",
            "parts": [{"text": system_prompt}]
        })
        conversations[user_id]["history"].append({
            "role": "model",
            "parts": [{"text": "I see you have some tasks to complete. Let's talk about them. What have you been up to?"}]
        })
    
    conversation = conversations[user_id]
    
    conversation["history"].append({
        "role": "user",
        "parts": [{"text": request.message}]
    })
    
    conversation_ended = detect_conversation_end(request.message)
    
    url = f"{GEMINI_API_URL}?key={GEMINI_API_KEY}"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                url,
                json={
                    "contents": conversation["history"]
                },
                timeout=30.0
            )
            
            if response.status_code != 200:
                error_text = response.text
                print(f"❌ Gemini Chat Error: {error_text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Gemini API error: {error_text}"
                )
            
            result = response.json()
            
            if "candidates" in result and len(result["candidates"]) > 0:
                ai_response = result["candidates"][0]["content"]["parts"][0]["text"]
                
                conversation["history"].append({
                    "role": "model",
                    "parts": [{"text": ai_response}]
                })
                
                if len(conversation["history"]) > 20:
                    conversation["history"] = conversation["history"][:2] + conversation["history"][-18:]
                
                record_chat_message(db, phone)
                
                return {
                    "response": ai_response,
                    "conversation_ended": conversation_ended
                }
            else:
                raise HTTPException(status_code=500, detail="No response from Gemini")
                
    except httpx.HTTPError as e:
        print(f"❌ Gemini Chat HTTP Error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to connect to Gemini: {str(e)}")
    except Exception as e:
        print(f"❌ Gemini Chat Exception: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")


@router.post("/end")
async def end_conversation(
    user_id: str = Depends(verify_token)
):
    print(f"📞 Received request to end conversation for user: {user_id}")
    print(f"📞 Active conversations: {list(conversations.keys())}")
    
    if user_id not in conversations:
        print(f"❌ No active conversation found for user: {user_id}")
        raise HTTPException(status_code=404, detail="No active conversation found")
    
    conversation = conversations[user_id]
    
    transcript_parts = []
    for msg in conversation["history"][2:]:
        role = "You" if msg["role"] == "user" else "AI"
        content = msg["parts"][0]["text"]
        transcript_parts.append(f"{role}: {content}")
    
    transcript = "\n".join(transcript_parts)
    print(f"✅ Built transcript with {len(transcript_parts)} messages. Transcript length: {len(transcript)}")
    
    del conversations[user_id]
    print(f"✅ Conversation ended and cleaned up for user: {user_id}")
    
    return {
        "transcript": transcript,
        "todos": conversation["todos"]
    }


@router.delete("/cancel")
async def cancel_conversation(
    user_id: str = Depends(verify_token)
):
    if user_id in conversations:
        del conversations[user_id]
    return {"message": "Conversation cancelled"}
