# call_usage.py - Handles daily call limit tracking
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import and_
from db import get_db
from models import CallUsage
from otp import verify_token, get_user_identifier
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

EASTERN = ZoneInfo("America/New_York")

router = APIRouter(prefix="/call-usage", tags=["call-usage"])

DAILY_LIMIT_SECONDS = 600.0


class CallLimitResponse(BaseModel):
    can_call: bool
    remaining_seconds: float
    used_seconds: float
    limit_seconds: float


class RecordCallDurationRequest(BaseModel):
    duration_seconds: float


def _check_limit_by_phone(db: Session, phone: str) -> CallLimitResponse:
    """Business logic for checking call limits by phone identifier."""
    today = datetime.now(EASTERN).date()
    
    usage = db.query(CallUsage).filter(
        and_(
            CallUsage.phone == phone,
            CallUsage.usage_date == today
        )
    ).first()
    
    if not usage:
        return CallLimitResponse(
            can_call=True,
            remaining_seconds=DAILY_LIMIT_SECONDS,
            used_seconds=0.0,
            limit_seconds=DAILY_LIMIT_SECONDS
        )
    
    remaining = max(0.0, DAILY_LIMIT_SECONDS - usage.seconds_used)
    can_call = remaining > 0
    
    return CallLimitResponse(
        can_call=can_call,
        remaining_seconds=remaining,
        used_seconds=usage.seconds_used,
        limit_seconds=DAILY_LIMIT_SECONDS
    )


@router.get("/check-limit")
def check_call_limit(
    db: Session = Depends(get_db),
    user_id: str = Depends(verify_token)
):
    phone = get_user_identifier(user_id, db)
    return _check_limit_by_phone(db, phone)


@router.post("/record-duration")
def record_call_duration(
    request: RecordCallDurationRequest,
    db: Session = Depends(get_db),
    user_id: str = Depends(verify_token)
):
    phone = get_user_identifier(user_id, db)
    duration_seconds = request.duration_seconds
    print(f"📞 Recording call duration: {duration_seconds:.2f} seconds for user {user_id} (phone={phone})")
    
    today = datetime.now(EASTERN).date()
    
    usage = db.query(CallUsage).filter(
        and_(
            CallUsage.phone == phone,
            CallUsage.usage_date == today
        )
    ).first()
    
    if not usage:
        usage = CallUsage(
            phone=phone,
            usage_date=today,
            seconds_used=0.0
        )
        db.add(usage)
        print(f"📊 Created new usage record for {phone} on {today}")
    else:
        print(f"📊 Found existing usage record: {usage.seconds_used:.2f}s already used today")
    
    old_used = usage.seconds_used
    usage.seconds_used += duration_seconds
    usage.updated_at = datetime.now(timezone.utc)
    
    db.commit()
    db.refresh(usage)
    
    remaining = max(0.0, DAILY_LIMIT_SECONDS - usage.seconds_used)
    
    print(f"✅ Call duration recorded: {duration_seconds:.2f}s added. Total used: {old_used:.2f}s → {usage.seconds_used:.2f}s. Remaining: {remaining:.2f}s")
    
    return {
        "message": "Call duration recorded",
        "used_seconds": usage.seconds_used,
        "remaining_seconds": remaining,
        "limit_seconds": DAILY_LIMIT_SECONDS
    }
