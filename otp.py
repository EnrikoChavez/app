from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
import redis
import os
import jwt
import time
from twilio.rest import Client
from dotenv import load_dotenv
load_dotenv(override=True)

REDIS_HOST = os.getenv("REDIS_HOST", "localhost")

router = APIRouter(prefix="/otp", tags=["otp"])

# Connect to Redis using the dynamic host
r = redis.from_url(
    REDIS_HOST,
    db=0,
    decode_responses=True
)

RATE_LIMIT = 3          # per hour per phone
SECRET_KEY = os.getenv("SECRET_KEY", "supersecret")
t_client = Client(os.getenv("TWILIO_ACCOUNT_SID"), os.getenv("TWILIO_AUTH_TOKEN"))
VERIFY_SID = os.getenv("TWILIO_VERIFY_SID")

class PhoneRequest(BaseModel):
    phone: str

class VerifyRequest(BaseModel):
    phone: str
    otp: str

def create_jwt(phone: str):
    payload = {
        "phone": phone,
        "exp": time.time() + 3600
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

@router.post("/send")
def send_otp(data: PhoneRequest):
    phone = data.phone

    # --- Rate limit ---
    attempts_key = f"attempts:{phone}"
    attempts = r.get(attempts_key)
    if attempts and int(attempts) >= RATE_LIMIT:
        raise HTTPException(status_code=429, detail="Too many OTP requests, try later")
    else:
        r.incr(attempts_key, 1)
        r.expire(attempts_key, 3600)  # reset after 1 hr

    v = t_client.verify.v2.services(VERIFY_SID).verifications.create(to=phone, channel="sms")  # or "call"
    return {"status": v.status}  # "pending" typically

@router.post("/verify")
def verify_otp(data: VerifyRequest):
    check = t_client.verify.v2.services(VERIFY_SID).verification_checks.create(to=data.phone, code=data.otp)
    if check.status == "approved":
        token = create_jwt(data.phone)
        return {"token": token}
    raise HTTPException(status_code=401, detail="Invalid or expired code")
