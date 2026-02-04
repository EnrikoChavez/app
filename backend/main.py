# main.py
import os
import base64
import httpx
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from todo import router as todo_router
from otp import router as otp_router
from profile import router as profile_router
from call_usage import router as call_usage_router
from chat import router as chat_router
from account import router as account_router
from manual_unblock import router as manual_unblock_router
from db import init_db
from models import Base



load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_db(Base)   # creates tables if missing (uses SQLite file)
    yield
    # Shutdown (if needed)

app = FastAPI(lifespan=lifespan)
app.include_router(todo_router)
app.include_router(otp_router)
app.include_router(profile_router)
app.include_router(call_usage_router)
app.include_router(chat_router)
app.include_router(account_router)
app.include_router(manual_unblock_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Hume AI Configuration
HUME_API_KEY = os.getenv("HUME_API_KEY")
HUME_SECRET_KEY = os.getenv("HUME_SECRET_KEY")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
HUME_BASE_URL = "https://api.hume.ai"

async def analyze_transcript_with_gemini(transcript: str) -> bool:
    """
    Asks Gemini if the user convinced the AI to unblock their apps.
    Returns True if convinced, False otherwise.
    """
    if not GEMINI_API_KEY:
        print("⚠️ GEMINI_API_KEY not set, defaulting to False")
        return False

    prompt = f"""
    You are an evaluator for an 'Anti-Doomscroll' app. 
    A user just had a conversation with an AI scolder/coach to try and unblock their distracted apps.
    Based on the following transcript, did the AI agent (scolder) explicitly or implicitly agree that the user has completed their tasks and deserves to have their apps unblocked?
    
    Transcript:
    {transcript}
    
    Respond with ONLY 'YES' if they should be unblocked, or 'NO' if they should not be unblocked.
    """

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={GEMINI_API_KEY}"
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                url,
                json={
                    "contents": [{
                        "parts": [{"text": prompt}]
                    }]
                },
                timeout=30.0
            )
            
            if response.status_code == 200:
                result = response.json()
                text = result['candidates'][0]['content']['parts'][0]['text'].strip().upper()
                print(f"🤖 Gemini Evaluation: {text}")
                return "YES" in text
            else:
                print(f"❌ Gemini Error: {response.text}")
                return False
    except Exception as e:
        print(f"❌ Gemini Exception: {str(e)}")
        return False

@app.post("/hume/evaluate-transcript")
async def evaluate_transcript(payload: dict):
    """
    Endpoint for iOS app to send transcript for evaluation.
    """
    transcript = payload.get("transcript", "")
    if not transcript:
        return {"unblock": False, "message": "No transcript provided"}

    should_unblock = await analyze_transcript_with_gemini(transcript)
    print(f"🎯 Transcript Evaluation: should_unblock={should_unblock}")
    
    if should_unblock:
        return {
            "unblock": True,
            "message": "Great job! You convinced the AI. Apps are now unblocked."
        }
    else:
        return {
            "unblock": False,
            "message": "You were not able to convince the AI! Finish your tasks!"
        }


async def get_hume_access_token():
    """
    Exchange API Key + Secret Key for a temporary access token.
    Uses Basic Auth: base64(API_KEY:SECRET_KEY)
    """
    if not HUME_API_KEY or not HUME_SECRET_KEY:
        raise HTTPException(
            status_code=500,
            detail="Hume API Key and Secret Key must be configured in .env (HUME_API_KEY and HUME_SECRET_KEY)"
        )
    
    # Hume uses Basic Auth (API_KEY:SECRET_KEY) to get a token
    credentials = f"{HUME_API_KEY}:{HUME_SECRET_KEY}"
    encoded_credentials = base64.b64encode(credentials.encode()).decode()
    
    try:
        async with httpx.AsyncClient() as client:
            print(f"🔗 Sending request to Hume OAuth... (using API Key: {HUME_API_KEY[:5]}***)")
            response = await client.post(
                "https://api.hume.ai/oauth2-cc/token",
                headers={
                    "Authorization": f"Basic {encoded_credentials}",
                    "Content-Type": "application/x-www-form-urlencoded"
                },
                data={"grant_type": "client_credentials"},
                timeout=10.0 # Shorter timeout to fail fast
            )
            
            print(f"📡 Hume OAuth Response Status: {response.status_code}")
            if response.status_code != 200:
                print(f"❌ Hume OAuth Error Body: {response.text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Hume token exchange failed: {response.text}"
                )
            
            token_data = response.json()
            access_token = token_data.get("access_token")
            
            if not access_token:
                raise HTTPException(
                    status_code=500,
                    detail="No access_token in Hume response"
                )
            
            return access_token
            
    except httpx.HTTPError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Hume token exchange HTTP error: {str(e)}"
        )

# Phone call endpoint removed - will be replaced with WebRTC web call endpoint in Phase 3
# @app.post("/trigger-call") - DEPRECATED

@app.post("/hume/create-session")
async def create_hume_session(payload: dict, request: Request):
    """
    Generate WebSocket connection details for Hume AI EVI.
    Checks daily call limit before creating session.
    """
    print("📥 Received request for /hume/create-session")
    
    # Check call limit before proceeding
    phone = request.headers.get("x-phone")
    if phone:
        from call_usage import check_call_limit
        from db import get_db
        
        # Get database session
        db = next(get_db())
        try:
            limit_info = check_call_limit(db=db, phone=phone)
            if not limit_info.can_call:
                raise HTTPException(
                    status_code=429,
                    detail=f"Daily call limit reached. You've used {limit_info.used_seconds:.1f}s of {limit_info.limit_seconds:.0f}s today."
                )
            print(f"✅ Call limit check passed: {limit_info.remaining_seconds:.1f}s remaining")
        finally:
            db.close()
    
    try:
        # 1. Get a secure temporary access token
        print("🔑 Fetching Hume access token...")
        access_token = await get_hume_access_token()
        print("✅ Access token received")
    
        # 2. Prepare variables for session_settings message
        todos = payload.get("todos", [])
        task_list_str = "\n".join([f"• {t.get('task', '')}" for t in todos])
        minutes = payload.get("minutes", 15)
        
        # 3. Get EVI config ID from environment (optional)
        evi_config_id = os.getenv("HUME_EVI_CONFIG_ID")
        
        # 4. Build WebSocket URL using access_token (not API key)
        from urllib.parse import urlencode
        params = {"access_token": access_token}
        if evi_config_id:
            params["config_id"] = evi_config_id
        
        # The correct path is /v0/evi/chat (EVI 3 standard)
        ws_url = f"wss://api.hume.ai/v0/evi/chat?{urlencode(params)}"
        
        # 5. Return WebSocket URL and variables for iOS to send in session_settings
        return {
            "websocket_url": ws_url,
            "initial_variables": {
                "todos": task_list_str,
                "minutes": str(minutes)
            }
        }
    except Exception as e:
        print(f"❌ Error creating Hume session: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))



@app.post("/hume-webhook")
async def hume_webhook(request: Request):
    """
    Handle Hume AI webhook events (session ended, transcript available, etc.).
    """
    event = await request.json()
    event_type = event.get("type")

    if event_type == "session_ended":
        transcript = event.get("transcript", "")
        
        # Store or summarize transcript for continuity
        print("Hume Transcript:\n", transcript[:])

    return {"ok": True}


@app.get("/")
def homepage():
    return {"bananas": "okk"}

