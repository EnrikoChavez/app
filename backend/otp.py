from fastapi import APIRouter, HTTPException, Header, Depends
from pydantic import BaseModel
from typing import Optional
import redis
import os
import jwt
import time
from twilio.rest import Client
from dotenv import load_dotenv
from sqlalchemy.orm import Session
from db import get_db
from models import User

load_dotenv(override=True)

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")

router = APIRouter(prefix="/otp", tags=["otp"])

try:
    r = redis.from_url(
        REDIS_HOST,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_keepalive=True,
        retry_on_timeout=True
    )
    r.ping()
    print(f"✅ Connected to Redis/Valkey at {REDIS_HOST}")
except Exception as e:
    print(f"⚠️ Redis connection failed: {str(e)}")
    r = None

RATE_LIMIT = 3          # per hour per phone
_secret = os.getenv("SECRET_KEY")
if not _secret:
    raise RuntimeError("SECRET_KEY environment variable must be set")
SECRET_KEY: str = _secret
t_client = Client(os.getenv("TWILIO_ACCOUNT_SID"), os.getenv("TWILIO_AUTH_TOKEN"))
VERIFY_SID = os.getenv("TWILIO_VERIFY_SID")

TEST_PHONE = os.getenv("TEST_PHONE", "+10000000002")
TEST_OTP = os.getenv("TEST_OTP", "123456")

class PhoneRequest(BaseModel):
    phone: str

class VerifyRequest(BaseModel):
    phone: str
    otp: str


def create_jwt(user_id: int) -> str:
    payload = {
        "user_id": user_id,
        "exp": time.time() + 30 * 24 * 3600  # 30 days
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


def verify_token(authorization: Optional[str] = Header(default=None)) -> str:
    """Extract user identifier from JWT. Returns user_id as string.
    Supports legacy tokens that contain 'phone' (returns 'phone:<number>').
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization header missing or invalid")
    token = authorization[len("Bearer "):]
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        if "user_id" in payload:
            return str(payload["user_id"])
        if "phone" in payload:
            return f"phone:{payload['phone']}"
        raise HTTPException(status_code=401, detail="Invalid token format")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Session expired, please log in again")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")


def get_user_identifier(user_id: str, db: Session) -> str:
    """Resolve user_id (from verify_token) to the string identifier used in legacy tables.
    For phone users returns their phone number; for Apple-only users returns 'apple_<id>'.
    Also handles legacy tokens that contain 'phone:<number>' by auto-creating a User row.
    """
    if user_id.startswith("phone:"):
        phone = user_id[6:]
        user = db.query(User).filter(User.phone == phone).first()
        if not user:
            user = User(phone=phone)
            db.add(user)
            db.commit()
            db.refresh(user)
        return phone

    uid = int(user_id)
    user = db.query(User).filter(User.id == uid).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user.phone if user.phone else f"apple_{user.id}"


def get_user(user_id: str, db: Session) -> User:
    """Resolve user_id to User ORM object."""
    if user_id.startswith("phone:"):
        phone = user_id[6:]
        user = db.query(User).filter(User.phone == phone).first()
        if not user:
            user = User(phone=phone)
            db.add(user)
            db.commit()
            db.refresh(user)
        return user

    uid = int(user_id)
    user = db.query(User).filter(User.id == uid).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


def _find_or_create_user_by_phone(phone: str, db: Session) -> User:
    """Find existing user by phone or create a new one."""
    user = db.query(User).filter(User.phone == phone).first()
    if not user:
        user = User(phone=phone)
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


@router.post("/send")
def send_otp(data: PhoneRequest):
    phone = data.phone

    if TEST_PHONE and phone == TEST_PHONE:
        return {"status": "pending"}

    if r:
        try:
            attempts_key = f"attempts:{phone}"
            attempts = r.get(attempts_key)
            if attempts and int(attempts) >= RATE_LIMIT:
                raise HTTPException(status_code=429, detail="Too many OTP requests, try later")
            else:
                r.incr(attempts_key, 1)
                r.expire(attempts_key, 3600)
        except Exception as e:
            print(f"⚠️ Redis error during rate limit check: {str(e)}")

    v = t_client.verify.v2.services(VERIFY_SID).verifications.create(to=phone, channel="sms")
    return {"status": v.status}


@router.post("/verify")
def verify_otp(data: VerifyRequest, db: Session = Depends(get_db)):
    if TEST_PHONE and data.phone == TEST_PHONE:
        if TEST_OTP and data.otp == TEST_OTP:
            user = _find_or_create_user_by_phone(data.phone, db)
            token = create_jwt(user.id)
            return {"token": token, "user_id": str(user.id)}
        raise HTTPException(status_code=401, detail="Invalid or expired code")

    check = t_client.verify.v2.services(VERIFY_SID).verification_checks.create(to=data.phone, code=data.otp)
    if check.status == "approved":
        user = _find_or_create_user_by_phone(data.phone, db)
        token = create_jwt(user.id)
        return {"token": token, "user_id": str(user.id)}
    raise HTTPException(status_code=401, detail="Invalid or expired code")
