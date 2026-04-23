import os
import httpx
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from db import get_db
from models import Profile, CallSession
from otp import verify_token, get_user_identifier

router = APIRouter(tags=["voice"])

ELEVENLABS_API_KEY = os.getenv("ELEVENLABS_API_KEY")
ELEVENLABS_AGENT_ID = os.getenv("ELEVENLABS_AGENT_ID")


@router.post("/voice/clone")
async def clone_voice(
    audio: UploadFile = File(...),
    name: str = Form(default="My Voice"),
    user_id: str = Depends(verify_token),
    db: Session = Depends(get_db),
):
    if not ELEVENLABS_API_KEY:
        raise HTTPException(status_code=500, detail="ElevenLabs API key not configured")

    if audio.size and audio.size > 50 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 50MB)")

    phone = get_user_identifier(user_id, db)

    profile = db.query(Profile).filter(Profile.phone == phone).first()
    if not profile or not profile.is_premium:
        raise HTTPException(status_code=403, detail="Premium subscription required to clone a voice")

    audio_data = await audio.read()

    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.elevenlabs.io/v1/voices/add",
            headers={"xi-api-key": ELEVENLABS_API_KEY},
            files={"files": (audio.filename or "voice_sample.m4a", audio_data, audio.content_type or "audio/m4a")},
            data={"name": name},
            timeout=60.0,
        )
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail=f"ElevenLabs error: {response.text}")

        eleven_voice_id = response.json().get("voice_id")
        if not eleven_voice_id:
            raise HTTPException(status_code=500, detail="No voice_id returned from ElevenLabs")

    # Delete previous clone from ElevenLabs if one exists
    if profile and profile.eleven_voice_id:
        await _delete_elevenlabs_voice(profile.eleven_voice_id)

    if not profile:
        profile = Profile(phone=phone, eleven_voice_id=eleven_voice_id)
        db.add(profile)
    else:
        profile.eleven_voice_id = eleven_voice_id

    db.commit()
    return {"voice_id": eleven_voice_id, "message": "Voice cloned successfully"}


@router.get("/voice/status")
def get_voice_status(user_id: str = Depends(verify_token), db: Session = Depends(get_db)):
    phone = get_user_identifier(user_id, db)
    profile = db.query(Profile).filter(Profile.phone == phone).first()
    if profile and profile.eleven_voice_id:
        return {"has_cloned_voice": True, "voice_id": profile.eleven_voice_id}
    return {"has_cloned_voice": False, "voice_id": None}


@router.delete("/voice/clone")
async def delete_cloned_voice(user_id: str = Depends(verify_token), db: Session = Depends(get_db)):
    phone = get_user_identifier(user_id, db)
    profile = db.query(Profile).filter(Profile.phone == phone).first()

    if not profile or not profile.eleven_voice_id:
        raise HTTPException(status_code=404, detail="No cloned voice found")

    await _delete_elevenlabs_voice(profile.eleven_voice_id)
    profile.eleven_voice_id = None
    db.commit()
    return {"message": "Voice deleted successfully"}


@router.post("/elevenlabs/create-session")
async def create_elevenlabs_session(
    payload: dict,
    user_id: str = Depends(verify_token),
    db: Session = Depends(get_db),
):
    if not ELEVENLABS_API_KEY or not ELEVENLABS_AGENT_ID:
        raise HTTPException(status_code=500, detail="ElevenLabs not configured")

    from call_usage import _check_limit_by_phone
    from main import _close_open_session

    now = datetime.now(timezone.utc)
    phone = get_user_identifier(user_id, db)
    profile = db.query(Profile).filter(Profile.phone == phone).first()

    if not profile or not profile.eleven_voice_id:
        raise HTTPException(status_code=404, detail="No cloned voice found")

    _close_open_session(db, phone, now)

    limit_info = _check_limit_by_phone(db, phone)
    if not limit_info.can_call:
        raise HTTPException(
            status_code=429,
            detail=f"Daily call limit reached. You've used {limit_info.used_seconds:.1f}s of {limit_info.limit_seconds:.0f}s today."
        )

    session_row = CallSession(phone=phone, started_at=now)
    db.add(session_row)
    db.commit()

    async with httpx.AsyncClient() as client:
        response = await client.get(
            "https://api.elevenlabs.io/v1/convai/conversation/get-signed-url",
            headers={"xi-api-key": ELEVENLABS_API_KEY},
            params={"agent_id": ELEVENLABS_AGENT_ID},
            timeout=10.0,
        )
        if response.status_code != 200:
            raise HTTPException(status_code=response.status_code, detail=f"ElevenLabs error: {response.text}")
        signed_url = response.json().get("signed_url")

    todos = payload.get("todos", [])
    minutes = payload.get("minutes", 15)
    if todos:
        task_list_str = "\n".join([f"• {t.get('task', '')}" for t in todos])
    else:
        task_list_str = "NO_TASKS: The user has no pending tasks — congratulate them!"

    return {
        "websocket_url": signed_url,
        "voice_id": profile.eleven_voice_id,
        "remaining_seconds": limit_info.remaining_seconds,
        "initial_variables": {"todos": task_list_str, "minutes": str(minutes)},
    }


async def _delete_elevenlabs_voice(voice_id: str):
    if not ELEVENLABS_API_KEY:
        return
    try:
        async with httpx.AsyncClient() as client:
            await client.delete(
                f"https://api.elevenlabs.io/v1/voices/{voice_id}",
                headers={"xi-api-key": ELEVENLABS_API_KEY},
                timeout=10.0,
            )
    except Exception as e:
        print(f"⚠️ Failed to delete ElevenLabs voice {voice_id}: {e}")
