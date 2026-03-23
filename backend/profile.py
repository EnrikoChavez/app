# profile.py - Handles user profiles and premium status
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.orm import Session
from db import get_db
from models import Profile
from otp import verify_token, get_user_identifier
from datetime import datetime, timezone
from apple_store import verify_app_store_jws

router = APIRouter(prefix="/profile", tags=["profile"])


class PremiumStatusResponse(BaseModel):
    phone: str
    is_premium: bool
    last_active: str


class SyncPremiumRequest(BaseModel):
    is_premium: bool
    # Required when is_premium=True: the signed JWS from StoreKit 2
    # transaction.jsonRepresentation converted to a UTF-8 string.
    transaction_jws: Optional[str] = None


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
    """
    Sync premium status.
    - Granting premium (is_premium=True): requires a valid transaction_jws from StoreKit 2.
      The JWS is cryptographically verified against Apple's certificate chain before
      updating the database. This prevents clients from falsely claiming premium status.
    - Revoking premium (is_premium=False): accepted without a JWS (no security risk).
    """
    if request.is_premium:
        if not request.transaction_jws:
            raise HTTPException(
                status_code=400,
                detail="transaction_jws is required to grant premium status"
            )
        try:
            verify_app_store_jws(request.transaction_jws)
        except ValueError as e:
            raise HTTPException(
                status_code=403,
                detail=f"Apple receipt verification failed: {e}"
            )

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
