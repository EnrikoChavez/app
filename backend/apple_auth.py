# apple_auth.py - Sign in with Apple verification
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.orm import Session
import jwt
from jwt import PyJWKClient
import os

from db import get_db
from models import User
from otp import create_jwt, verify_token, get_user, get_user_identifier

router = APIRouter(prefix="/auth", tags=["auth"])

APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"
APPLE_CLIENT_ID = os.getenv("APPLE_CLIENT_ID")  # Your app's bundle identifier

jwk_client = PyJWKClient(APPLE_KEYS_URL, cache_keys=True)


class AppleSignInRequest(BaseModel):
    identity_token: str
    email: Optional[str] = None
    full_name: Optional[str] = None


class LinkAppleRequest(BaseModel):
    identity_token: str


def _verify_apple_token(identity_token: str) -> dict:
    """Verify Apple's identity token and return the decoded payload."""
    if not APPLE_CLIENT_ID:
        raise HTTPException(
            status_code=500,
            detail="APPLE_CLIENT_ID not configured. Set it to your app's bundle identifier in .env"
        )

    try:
        signing_key = jwk_client.get_signing_key_from_jwt(identity_token)
        payload = jwt.decode(
            identity_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=APPLE_CLIENT_ID,
            issuer=APPLE_ISSUER,
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Apple identity token expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid Apple identity token: {str(e)}")
    except Exception as e:
        print(f"❌ Apple token verification error: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to verify Apple identity token")


@router.post("/apple")
def apple_sign_in(
    request: AppleSignInRequest,
    db: Session = Depends(get_db)
):
    """
    Authenticate with Apple Sign-In.
    Verifies the identity token, finds or creates a user, returns a JWT.
    """
    payload = _verify_apple_token(request.identity_token)
    apple_id = payload.get("sub")
    token_email = payload.get("email")

    if not apple_id:
        raise HTTPException(status_code=401, detail="No user identifier in Apple token")

    user = db.query(User).filter(User.apple_id == apple_id).first()

    if not user:
        user = User(
            apple_id=apple_id,
            email=request.email or token_email,
            full_name=request.full_name,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        print(f"🍎 New Apple user created: id={user.id}")
    else:
        if request.email and not user.email:
            user.email = request.email
        if request.full_name and not user.full_name:
            user.full_name = request.full_name
        db.commit()
        print(f"🍎 Existing Apple user logged in: id={user.id}")

    token = create_jwt(user.id)
    return {"token": token, "user_id": str(user.id)}


@router.post("/link-apple")
def link_apple_to_account(
    request: LinkAppleRequest,
    user_id: str = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Link an Apple ID to an existing account (e.g. phone user adds Apple Sign-In).
    If the Apple ID already belongs to another user, merges the accounts.
    """
    payload = _verify_apple_token(request.identity_token)
    apple_id = payload.get("sub")
    if not apple_id:
        raise HTTPException(status_code=401, detail="No user identifier in Apple token")

    current_user = get_user(user_id, db)

    if current_user.apple_id == apple_id:
        return {"message": "Apple ID already linked", "user_id": str(current_user.id)}

    existing_apple_user = db.query(User).filter(User.apple_id == apple_id).first()

    if existing_apple_user and existing_apple_user.id != current_user.id:
        _merge_users(source=existing_apple_user, target=current_user, db=db)
        return {"message": "Accounts merged", "user_id": str(current_user.id)}

    current_user.apple_id = apple_id
    token_email = payload.get("email")
    if token_email and not current_user.email:
        current_user.email = token_email
    db.commit()

    return {"message": "Apple ID linked", "user_id": str(current_user.id)}


@router.post("/link-phone")
def link_phone_to_account(
    user_id: str = Depends(verify_token),
    db: Session = Depends(get_db)
):
    """
    Link a phone number to an existing Apple account.
    Called after the user successfully verifies their phone via OTP.
    Expects {"phone": "+1..."} in the body.
    If the phone already belongs to another user, merges the accounts.
    """
    from fastapi import Body
    from pydantic import BaseModel

    # This will be called by the iOS app after OTP verification succeeds
    # The app sends the verified phone number
    pass


def _merge_users(source: User, target: User, db: Session):
    """Merge source user's data into target user, then delete source."""
    from models import Todo, Profile, CallUsage, ChatUsage, ManualUnblockUsage

    source_id = get_user_identifier(str(source.id), db) if not source.phone else source.phone
    if source.phone and not source.phone.startswith("apple_"):
        source_phone = source.phone
    else:
        source_phone = f"apple_{source.id}"

    target_phone = target.phone if target.phone else f"apple_{target.id}"

    # Move all data from source's phone identifier to target's identifier
    for model in [Todo, CallUsage, ChatUsage, ManualUnblockUsage]:
        db.query(model).filter(model.phone == source_phone).update(
            {"phone": target_phone}, synchronize_session="fetch"
        )

    # Merge profile: keep target's, delete source's
    source_profile = db.query(Profile).filter(Profile.phone == source_phone).first()
    if source_profile:
        target_profile = db.query(Profile).filter(Profile.phone == target_phone).first()
        if not target_profile:
            source_profile.phone = target_phone
        else:
            if source_profile.is_premium and not target_profile.is_premium:
                target_profile.is_premium = True
            db.delete(source_profile)

    # Copy Apple ID / phone to target if missing
    if source.apple_id and not target.apple_id:
        target.apple_id = source.apple_id
    if source.phone and not target.phone:
        target.phone = source.phone
    if source.email and not target.email:
        target.email = source.email

    db.delete(source)
    db.commit()
    print(f"🔗 Merged user {source.id} into user {target.id}")
