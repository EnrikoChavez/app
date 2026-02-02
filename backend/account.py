# account.py - Handles account management operations
from fastapi import APIRouter, HTTPException, Depends, Header
from sqlalchemy.orm import Session
from db import get_db
from models import Todo, Profile, CallUsage
from datetime import date

router = APIRouter(prefix="/account", tags=["account"])


# Helper: get phone number from header
def get_phone(x_phone: str = Header(...)):
    return x_phone


@router.delete("/delete")
def delete_account(
    db: Session = Depends(get_db),
    phone: str = Depends(get_phone)
):
    """
    Delete user account and all associated data.
    This includes:
    - All todos
    - Profile information
    - Call usage history
    """
    print(f"🗑️ Deleting account for phone: {phone}")
    
    # Delete all todos
    todos_deleted = db.query(Todo).filter(Todo.phone == phone).delete()
    print(f"  - Deleted {todos_deleted} todos")
    
    # Delete profile
    profile_deleted = db.query(Profile).filter(Profile.phone == phone).delete()
    print(f"  - Deleted {profile_deleted} profile(s)")
    
    # Delete call usage history
    call_usage_deleted = db.query(CallUsage).filter(CallUsage.phone == phone).delete()
    print(f"  - Deleted {call_usage_deleted} call usage records")
    
    db.commit()
    
    print(f"✅ Account deletion complete for phone: {phone}")
    
    return {
        "message": "Account deleted successfully",
        "todos_deleted": todos_deleted,
        "profile_deleted": profile_deleted,
        "call_usage_deleted": call_usage_deleted
    }
