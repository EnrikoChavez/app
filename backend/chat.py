# chat.py - Handles Gemini text chat with conversation memory
from fastapi import APIRouter, HTTPException, Depends, Header
from pydantic import BaseModel
from typing import List, Optional
import httpx
import os
from datetime import datetime, date, timezone
from sqlalchemy.orm import Session
from sqlalchemy import and_
from db import get_db
from models import ChatUsage

router = APIRouter(prefix="/chat", tags=["chat"])

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

# Limits
MAX_MESSAGES_PER_DAY = 1000
MAX_CHARACTERS_PER_MESSAGE = 3000

# In-memory conversation storage (in production, use Redis or database)
# Format: {phone: {"history": [...], "todos": "...", "started_at": datetime}}
conversations = {}


# Helper: get phone number from header
def get_phone(x_phone: str = Header(...)):
    return x_phone


class ChatMessage(BaseModel):
    role: str  # "user" or "assistant"
    content: str


class ChatRequest(BaseModel):
    message: str
    todos: List[str]  # List of todo tasks
    is_new_conversation: bool = False  # Start new conversation


class ChatResponse(BaseModel):
    response: str
    conversation_ended: bool = False  # True if user indicated conversation is done


def build_system_prompt(todos: List[str]) -> str:
    """Build the system prompt with todos."""
    todos_list = "\n".join([f"{i+1}. {todo}" for i, todo in enumerate(todos)])
    
    return f"""You are a good friend that is lightly scolding the user for spending too much time doomscrolling or mindlessly using the internet. The user has the following tasks to do:

{todos_list}

Make sure to list quickly the things the user has to do, all of them. Enumerate them. You are skeptical if the user says they finished the tasks but are easy to convince after they provide evidence or explanation.

Keep your responses concise and friendly but firm. Remember the conversation context as it progresses."""


def detect_conversation_end(user_message: str) -> bool:
    """Detect if user wants to end the conversation."""
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
    """
    Check if user can send a message based on daily limits.
    Returns (can_send, messages_sent_today)
    """
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
    """
    Record that a message was sent (increment daily count).
    """
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
    phone: str = Depends(get_phone),
    db: Session = Depends(get_db)
):
    """
    Send a message to Gemini chat and get response.
    Maintains conversation history per user.
    Enforces daily message limit and character limit per message.
    """
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="Gemini API key not configured")
    
    # Check character limit per message
    if len(request.message) > MAX_CHARACTERS_PER_MESSAGE:
        raise HTTPException(
            status_code=400,
            detail=f"Message too long. Maximum {MAX_CHARACTERS_PER_MESSAGE} characters allowed."
        )
    
    # Check daily message limit
    can_send, messages_sent = check_chat_limits(db, phone)
    if not can_send:
        raise HTTPException(
            status_code=429,
            detail=f"Daily message limit reached. You've sent {messages_sent} messages today (limit: {MAX_MESSAGES_PER_DAY})."
        )
    
    # Start new conversation or get existing
    if request.is_new_conversation or phone not in conversations:
        conversations[phone] = {
            "history": [],
            "todos": request.todos,
            "started_at": datetime.now()
        }
        # Add system prompt as first message
        system_prompt = build_system_prompt(request.todos)
        conversations[phone]["history"].append({
            "role": "user",
            "parts": [{"text": system_prompt}]
        })
        conversations[phone]["history"].append({
            "role": "model",
            "parts": [{"text": "I see you have some tasks to complete. Let's talk about them. What have you been up to?"}]
        })
    
    conversation = conversations[phone]
    
    # Add user message to history
    conversation["history"].append({
        "role": "user",
        "parts": [{"text": request.message}]
    })
    
    # Check if user wants to end conversation
    conversation_ended = detect_conversation_end(request.message)
    
    # Prepare request to Gemini
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
            
            # Extract AI response
            if "candidates" in result and len(result["candidates"]) > 0:
                ai_response = result["candidates"][0]["content"]["parts"][0]["text"]
                
                # Add AI response to history
                conversation["history"].append({
                    "role": "model",
                    "parts": [{"text": ai_response}]
                })
                
                # Limit history to last 20 messages to avoid token limits
                if len(conversation["history"]) > 20:
                    # Keep system prompt and recent messages
                    conversation["history"] = conversation["history"][:2] + conversation["history"][-18:]
                
                # Record that a message was sent (only after successful send)
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
    phone: str = Depends(get_phone)
):
    """
    End a conversation and return the full transcript for evaluation.
    """
    print(f"📞 Received request to end conversation for phone: {phone}")
    print(f"📞 Active conversations: {list(conversations.keys())}")
    
    if phone not in conversations:
        print(f"❌ No active conversation found for phone: {phone}")
        raise HTTPException(status_code=404, detail="No active conversation found")
    
    conversation = conversations[phone]
    
    # Build transcript from history (excluding system prompt)
    transcript_parts = []
    for msg in conversation["history"][2:]:  # Skip system prompt and initial greeting
        role = "You" if msg["role"] == "user" else "AI"
        content = msg["parts"][0]["text"]
        transcript_parts.append(f"{role}: {content}")
    
    transcript = "\n".join(transcript_parts)
    print(f"✅ Built transcript with {len(transcript_parts)} messages. Transcript length: {len(transcript)}")
    
    # Clean up conversation
    del conversations[phone]
    print(f"✅ Conversation ended and cleaned up for phone: {phone}")
    
    return {
        "transcript": transcript,
        "todos": conversation["todos"]
    }


@router.delete("/cancel")
async def cancel_conversation(
    phone: str = Depends(get_phone)
):
    """Cancel an active conversation without evaluation."""
    if phone in conversations:
        del conversations[phone]
    return {"message": "Conversation cancelled"}
