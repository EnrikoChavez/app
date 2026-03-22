# profile.py - Handles user profiles and premium status
from fastapi import APIRouter, HTTPException, Depends, Body
from pydantic import BaseModel
from sqlalchemy.orm import Session
from db import get_db
from models import Profile
from otp import verify_token, get_user_identifier
from datetime import datetime, timezone

router = APIRouter(prefix="/profile", tags=["profile"])


class PremiumStatusResponse(BaseModel):
    phone: str
    is_premium: bool
    last_active: str


class SyncPremiumRequest(BaseModel):
    is_premium: bool


@router.get("/premium-status")
def get_premium_status(db: Session = Depends(get_db), user_id: str = Depends(verify_token)):
    phone = get_user_identifier(user_id, db)
    profile = db.query(Profile).filter(Profile.phone == phone).first()
    
    if not profile:
        profile = Profile(phone=phone, is_premium=False)
        db.add(profile)
        db.commit()
        db.refresh(profile)
    
    return {
        "phone": profile.phone,
        "is_premium": profile.is_premium,
        "last_active": profile.last_active.isoformat() if profile.last_active else None,
    }


@router.post("/sync-premium")
def sync_premium_status(
    request: SyncPremiumRequest,
    db: Session = Depends(get_db),
    user_id: str = Depends(verify_token)
):
    phone = get_user_identifier(user_id, db)
    profile = db.query(Profile).filter(Profile.phone == phone).first()
    
    if not profile:
        profile = Profile(phone=phone, is_premium=request.is_premium)
        db.add(profile)
    else:
        profile.is_premium = request.is_premium
        profile.last_active = datetime.now(timezone.utc)
    
    db.commit()
    db.refresh(profile)
    
    return {
        "message": "Premium status synced",
        "phone": profile.phone,
        "is_premium": profile.is_premium,
    }
