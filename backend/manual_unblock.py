# manual_unblock.py - Handles daily manual unblock limit tracking
from fastapi import APIRouter, Depends, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import and_
from db import get_db
from models import ManualUnblockUsage
from datetime import datetime, date, timezone

router = APIRouter(prefix="/manual-unblock", tags=["manual-unblock"])

# Daily limit: 10 manual unblocks
DAILY_LIMIT_COUNT = 3


# Helper: get phone number from header
def get_phone(x_phone: str = Header(...)):
    return x_phone


class ManualUnblockLimitResponse(BaseModel):
    can_unblock: bool
    remaining_count: int
    used_count: int
    limit_count: int


@router.get("/check-limit")
def check_manual_unblock_limit(
    db: Session = Depends(get_db),
    phone: str = Depends(get_phone)
):
    """
    Check if user can perform a manual unblock based on daily limit.
    Returns remaining count and whether they can unblock.
    """
    today = date.today()
    
    # Get or create today's usage record
    usage = db.query(ManualUnblockUsage).filter(
        and_(
            ManualUnblockUsage.phone == phone,
            ManualUnblockUsage.usage_date == today
        )
    ).first()
    
    if not usage:
        # No usage today, full limit available
        return ManualUnblockLimitResponse(
            can_unblock=True,
            remaining_count=DAILY_LIMIT_COUNT,
            used_count=0,
            limit_count=DAILY_LIMIT_COUNT
        )
    
    remaining = max(0, DAILY_LIMIT_COUNT - usage.unblock_count)
    can_unblock = remaining > 0
    
    return ManualUnblockLimitResponse(
        can_unblock=can_unblock,
        remaining_count=remaining,
        used_count=usage.unblock_count,
        limit_count=DAILY_LIMIT_COUNT
    )


@router.post("/record")
def record_manual_unblock(
    db: Session = Depends(get_db),
    phone: str = Depends(get_phone)
):
    """
    Record a manual unblock.
    Increments today's total usage.
    """
    print(f"🔓 Recording manual unblock for phone {phone}")
    
    today = date.today()
    
    # Get or create today's usage record
    usage = db.query(ManualUnblockUsage).filter(
        and_(
            ManualUnblockUsage.phone == phone,
            ManualUnblockUsage.usage_date == today
        )
    ).first()
    
    if not usage:
        usage = ManualUnblockUsage(
            phone=phone,
            usage_date=today,
            unblock_count=0
        )
        db.add(usage)
        print(f"📊 Created new manual unblock usage record for {phone} on {today}")
    else:
        print(f"📊 Found existing usage record: {usage.unblock_count} unblocks already used today")
    
    # Increment the unblock count
    old_count = usage.unblock_count
    usage.unblock_count += 1
    usage.updated_at = datetime.now(timezone.utc)
    
    db.commit()
    db.refresh(usage)
    
    remaining = max(0, DAILY_LIMIT_COUNT - usage.unblock_count)
    
    print(f"✅ Manual unblock recorded. Total used: {old_count} → {usage.unblock_count}. Remaining: {remaining}")
    
    return {
        "message": "Manual unblock recorded",
        "used_count": usage.unblock_count,
        "remaining_count": remaining,
        "limit_count": DAILY_LIMIT_COUNT
    }
