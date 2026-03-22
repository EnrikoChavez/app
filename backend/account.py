# account.py - Handles account management operations
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from db import get_db
from models import Todo, Profile, CallUsage, User
from otp import verify_token, get_user_identifier, get_user

router = APIRouter(prefix="/account", tags=["account"])


@router.delete("/delete")
def delete_account(
    db: Session = Depends(get_db),
    user_id: str = Depends(verify_token)
):
    """
    Delete user account and all associated data.
    """
    phone = get_user_identifier(user_id, db)
    user = get_user(user_id, db)
    print(f"🗑️ Deleting account for user {user.id} (phone={phone})")
    
    todos_deleted = db.query(Todo).filter(Todo.phone == phone).delete()
    print(f"  - Deleted {todos_deleted} todos")
    
    profile_deleted = db.query(Profile).filter(Profile.phone == phone).delete()
    print(f"  - Deleted {profile_deleted} profile(s)")
    
    call_usage_deleted = db.query(CallUsage).filter(CallUsage.phone == phone).delete()
    print(f"  - Deleted {call_usage_deleted} call usage records")

    db.delete(user)
    
    db.commit()
    
    print(f"✅ Account deletion complete for user {user.id}")
    
    return {
        "message": "Account deleted successfully",
        "todos_deleted": todos_deleted,
        "profile_deleted": profile_deleted,
        "call_usage_deleted": call_usage_deleted
    }
