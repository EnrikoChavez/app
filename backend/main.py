# main.py
import os
import base64
import httpx
from datetime import datetime, timezone
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, HTTPException, Depends
from otp import verify_token, get_user_identifier
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from todo import router as todo_router
from otp import router as otp_router
from profile import router as profile_router
from call_usage import router as call_usage_router
from chat import router as chat_router
from account import router as account_router
from manual_unblock import router as manual_unblock_router
from apple_auth import router as apple_auth_router
from db import init_db, get_db
from models import Base, User, Profile, CallSession, CallUsage



load_dotenv()

def migrate_existing_phone_users():
    """Create User records for phones that exist in profiles but not in users table."""
    from sqlalchemy.orm import Session
    db_gen = get_db()
    db: Session = next(db_gen)
    try:
        profiles = db.query(Profile.phone).distinct().all()
        created = 0
        for (phone,) in profiles:
            if not phone:
                continue
            existing = db.query(User).filter(User.phone == phone).first()
            if not existing:
                user = User(phone=phone)
                db.add(user)
                created += 1
        if created:
            db.commit()
            print(f"🔄 Migrated {created} existing phone users to users table")
        else:
            print("✅ No phone users to migrate")
    except Exception as e:
        print(f"⚠️ Migration error (non-fatal): {e}")
        db.rollback()
    finally:
        db.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db(Base)
    migrate_existing_phone_users()
    yield

app = FastAPI(lifespan=lifespan)
app.include_router(todo_router)
app.include_router(otp_router)
app.include_router(profile_router)
app.include_router(call_usage_router)
app.include_router(chat_router)
app.include_router(account_router)
app.include_router(manual_unblock_router)
app.include_router(apple_auth_router)

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
async def evaluate_transcript(payload: dict, user_id: str = Depends(verify_token)):
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
    if not HUME_API_KEY or not HUME_SECRET_KEY:
        raise HTTPException(
            status_code=500,
            detail="Hume API Key and Secret Key must be configured in .env (HUME_API_KEY and HUME_SECRET_KEY)"
        )
    
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
                timeout=10.0
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

def _close_open_session(db, phone: str, now: datetime) -> float:
    """
    Close any open CallSession for this phone, recording its duration into CallUsage.
    Returns the number of seconds recorded (0 if nothing was open).
    """
    from zoneinfo import ZoneInfo
    from call_usage import DAILY_LIMIT_SECONDS, EASTERN

    open_session = (
        db.query(CallSession)
        .filter(CallSession.phone == phone, CallSession.ended_at.is_(None))
        .order_by(CallSession.started_at.desc())
        .first()
    )
    if not open_session:
        return 0.0

    raw_duration = (now - open_session.started_at).total_seconds()
    duration = min(raw_duration, DAILY_LIMIT_SECONDS)

    open_session.ended_at = now
    open_session.duration_seconds = duration

    today = now.astimezone(EASTERN).date()
    usage = db.query(CallUsage).filter(
        CallUsage.phone == phone, CallUsage.usage_date == today
    ).first()
    if not usage:
        usage = CallUsage(phone=phone, usage_date=today, seconds_used=0.0)
        db.add(usage)
    usage.seconds_used += duration
    usage.updated_at = now

    db.commit()
    print(f"⚠️  Auto-closed orphan session for {phone}: recorded {duration:.1f}s")
    return duration


@app.post("/hume/create-session")
async def create_hume_session(payload: dict, user_id: str = Depends(verify_token)):
    print("📥 Received request for /hume/create-session")

    from sqlalchemy.orm import Session as SA_Session
    from call_usage import _check_limit_by_phone
    from models import Profile

    now = datetime.now(timezone.utc)
    db = next(get_db())
    try:
        phone = get_user_identifier(user_id, db)

        # Require premium subscription to access Hume AI calls
        profile = db.query(Profile).filter(Profile.phone == phone).first()
        if not profile or not profile.is_premium:
            raise HTTPException(
                status_code=403,
                detail="Premium subscription required to use AI calls."
            )

        # Auto-close any orphaned session from a crash / missed end-session call
        _close_open_session(db, phone, now)

        limit_info = _check_limit_by_phone(db, phone)
        if not limit_info.can_call:
            raise HTTPException(
                status_code=429,
                detail=f"Daily call limit reached. You've used {limit_info.used_seconds:.1f}s of {limit_info.limit_seconds:.0f}s today."
            )
        print(f"✅ Call limit check passed: {limit_info.remaining_seconds:.1f}s remaining")

        # Record session start server-side so duration is measured here, not by the client
        session_row = CallSession(phone=phone, started_at=now)
        db.add(session_row)
        db.commit()
        print(f"🕐 Call session started for {phone} at {now.isoformat()}")
    finally:
        db.close()
    
    try:
        print("🔑 Fetching Hume access token...")
        access_token = await get_hume_access_token()
        print("✅ Access token received")
    
        todos = payload.get("todos", [])
        minutes = payload.get("minutes", 15)
        if todos:
            task_list_str = "\n".join([f"• {t.get('task', '')}" for t in todos])
        else:
            task_list_str = "NO_TASKS: The user has no pending tasks — they have everything done! Congratulate them warmly and tell them they deserve a guilt-free break."
        
        evi_config_id = os.getenv("HUME_EVI_CONFIG_ID")
        
        from urllib.parse import urlencode
        params = {"access_token": access_token}
        if evi_config_id:
            params["config_id"] = evi_config_id
        
        ws_url = f"wss://api.hume.ai/v0/evi/chat?{urlencode(params)}"
        
        return {
            "websocket_url": ws_url,
            "initial_variables": {
                "todos": task_list_str,
                "minutes": str(minutes)
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"❌ Error creating Hume session: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/hume/end-session")
async def end_hume_session(user_id: str = Depends(verify_token)):
    """
    Called by the iOS app when a Hume call ends.
    Duration is computed server-side (now - started_at), so the client cannot
    report a fake duration to inflate or reduce their usage counter.
    """
    from call_usage import DAILY_LIMIT_SECONDS, EASTERN

    now = datetime.now(timezone.utc)
    db = next(get_db())
    try:
        phone = get_user_identifier(user_id, db)

        open_session = (
            db.query(CallSession)
            .filter(CallSession.phone == phone, CallSession.ended_at.is_(None))
            .order_by(CallSession.started_at.desc())
            .first()
        )
        if not open_session:
            raise HTTPException(status_code=404, detail="No active call session found")

        raw_duration = (now - open_session.started_at).total_seconds()
        duration = min(raw_duration, DAILY_LIMIT_SECONDS)

        open_session.ended_at = now
        open_session.duration_seconds = duration

        today = now.astimezone(EASTERN).date()
        usage = db.query(CallUsage).filter(
            CallUsage.phone == phone, CallUsage.usage_date == today
        ).first()
        if not usage:
            usage = CallUsage(phone=phone, usage_date=today, seconds_used=0.0)
            db.add(usage)
        old_used = usage.seconds_used
        usage.seconds_used += duration
        usage.updated_at = now

        db.commit()
        db.refresh(usage)

        remaining = max(0.0, DAILY_LIMIT_SECONDS - usage.seconds_used)
        print(
            f"✅ Call ended for {phone}: {duration:.1f}s recorded. "
            f"Total today: {old_used:.1f}s → {usage.seconds_used:.1f}s. Remaining: {remaining:.1f}s"
        )

        return {
            "message": "Call duration recorded",
            "duration_seconds": duration,
            "used_seconds": usage.seconds_used,
            "remaining_seconds": remaining,
            "limit_seconds": DAILY_LIMIT_SECONDS,
        }
    finally:
        db.close()



@app.post("/hume-webhook")
async def hume_webhook(request: Request):
    event = await request.json()
    event_type = event.get("type")

    if event_type == "session_ended":
        transcript = event.get("transcript", "")
        print("Hume Transcript:\n", transcript[:])

    return {"ok": True}


@app.get("/")
def homepage():
    return {"bananas": "okk"}
