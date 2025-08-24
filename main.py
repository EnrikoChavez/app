# main.py
import os
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from retell import AsyncRetell
from dotenv import load_dotenv
from todo import router as todo_router
from otp import router as otp_router
from db import init_db
from todo import Base
load_dotenv()

app = FastAPI()
app.include_router(todo_router)
app.include_router(otp_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize client (async because FastAPI works best that way)
client = AsyncRetell(api_key=os.getenv("RETELL_API_KEY"))
print(dir(client))

@app.on_event("startup")
def _startup():
    init_db(Base)   # creates tables if missing (uses SQLite file)

@app.post("/trigger-call")
async def trigger_call(payload: dict):
    """
    Trigger a Retell outbound call with context variables.
    """
    print("CALLER_NUMBER:", repr(os.getenv("CALLER_NUMBER")))
    task_list_str = "\n".join([f"• {todo['task']}" for todo in payload["todos"]])
    call = await client.call.create_phone_call(
        from_number=os.getenv("CALLER_NUMBER"),   # e.g., your Twilio/SignalWire number
        to_number=payload["phone"],
        retell_llm_dynamic_variables={
            "todos": task_list_str,
            "minutes": str(payload["minutes"]),
            "goal": "Help user pause doomscrolling and reset"
        }
    )
    return {"callId": call.call_id}


@app.post("/retell-webhook")
async def retell_webhook(request: Request):
    """
    Handle Retell webhook events (call started, ended, etc.).
    """
    event = await request.json()
    event_type = event.get("type")

    if event_type == "call_ended":
        call_id = event["data"]["call_id"]

        # Fetch call details, including utterances
        call_data = await client.call.get(call_id)
        utterances = getattr(call_data, "utterances", [])
        transcript = "\n".join(f"{u.speaker}: {u.text}" for u in utterances)

        # Store or summarize transcript for continuity
        print("Transcript:\n", transcript[:500])
        save_last_summary(event["data"]["user_id"], transcript[:200])

    return {"ok": True}


# --- Helper stubs ---
def save_last_summary(user_id: str, summary: str):
    # Replace with DB storage
    print(f"Saved summary for {user_id}: {summary[:100]}")

@app.get("/")
def homepage():
    return {"bananas": "okk"}

