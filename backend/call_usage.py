# call_usage.py - Handles daily call limit tracking
from fastapi import APIRouter, Depends, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import and_
from db import get_db
from models import CallUsage
from datetime import datetime, date, timezone

router = APIRouter(prefix="/call-usage", tags=["call-usage"])

# Daily limit: 60 seconds (1 minute)
DAILY_LIMIT_SECONDS = 600.0


# Helper: get phone number from header
def get_phone(x_phone: str = Header(...)):
    return x_phone


class CallLimitResponse(BaseModel):
    can_call: bool
    remaining_seconds: float
    used_seconds: float
    limit_seconds: float


class RecordCallDurationRequest(BaseModel):
    duration_seconds: float


@router.get("/check-limit")
def check_call_limit(
    db: Session = Depends(get_db),
    phone: str = Depends(get_phone)
):
    """
    Check if user can make a call based on daily limit.
    Returns remaining time and whether they can call.
    """
    today = date.today()
    
    # Get or create today's usage record
    usage = db.query(CallUsage).filter(
        and_(
            CallUsage.phone == phone,
            CallUsage.usage_date == today
        )
    ).first()
    
    if not usage:
        # No usage today, full limit available
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


@router.post("/record-duration")
def record_call_duration(
    request: RecordCallDurationRequest,
    db: Session = Depends(get_db),
    phone: str = Depends(get_phone)
):
    """
    Record call duration after a call ends.
    Adds to today's total usage.
    """
    duration_seconds = request.duration_seconds
    print(f"📞 Recording call duration: {duration_seconds:.2f} seconds for phone {phone}")
    
    today = date.today()
    
    # Get or create today's usage record
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
    
    # Add the call duration to today's total
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
