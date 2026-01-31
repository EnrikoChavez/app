from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session
from fastapi import Header
from db import get_db
from models import Todo, Profile

# -----------------------------------
# FastAPI router
# -----------------------------------
router = APIRouter(prefix="/todos", tags=["todos"])


class TodoItem(BaseModel):
    task: str
    apple_id: str | None = None


class TodoResponse(BaseModel):
    id: int
    task: str
    phone: str


# Helper: get phone number from header (simple auth mechanism)
def get_phone(x_phone: str = Header(...)):
    return x_phone


@router.get("")
def get_todos(db: Session = Depends(get_db), phone: str = Depends(get_phone)):
    """Get all todos for a user. Syncs from Postgres."""
    todos = db.query(Todo).filter(Todo.phone == phone).order_by(Todo.created_at.desc()).all()
    return {
        "todos": [
            {
                "id": t.id,
                "task": t.task,
                "phone": t.phone,
                "appleId": t.apple_id,
                "syncedAt": t.synced_at.isoformat() if t.synced_at else None
            }
            for t in todos
        ]
    }


@router.post("")
def add_todo(item: TodoItem, db: Session = Depends(get_db), phone: str = Depends(get_phone)):
    """Add a todo. Saves to Postgres immediately."""
    todo = Todo(task=item.task, phone=phone, apple_id=item.apple_id)
    db.add(todo)
    db.commit()
    db.refresh(todo)
    
    # Update user's last_active timestamp
    profile = db.query(Profile).filter(Profile.phone == phone).first()
    if profile:
        from datetime import datetime
        profile.last_active = datetime.utcnow()
        db.commit()
    else:
        # Create profile if it doesn't exist
        profile = Profile(phone=phone, is_premium=False)
        db.add(profile)
        db.commit()
    
    return {
        "message": "Todo added",
        "todo": {
            "id": todo.id,
            "task": todo.task,
            "phone": todo.phone,
            "appleId": todo.apple_id,
            "syncedAt": todo.synced_at.isoformat() if todo.synced_at else None
        },
    }


@router.put("/{todo_id}")
def update_todo(todo_id: int, item: TodoItem, db: Session = Depends(get_db), phone: str = Depends(get_phone)):
    """Update a todo. Syncs to Postgres."""
    todo = db.query(Todo).filter(Todo.id == todo_id, Todo.phone == phone).first()
    if not todo:
        raise HTTPException(status_code=404, detail="Invalid id")

    todo.task = item.task
    if item.apple_id is not None:
        todo.apple_id = item.apple_id
    db.commit()
    db.refresh(todo)
    return {
        "message": f"Updated todo {todo_id}",
        "todo": {
            "id": todo.id,
            "task": todo.task,
            "phone": todo.phone,
            "appleId": todo.apple_id,
            "syncedAt": todo.synced_at.isoformat() if todo.synced_at else None
        }
    }


@router.delete("/{todo_id}")
def delete_todo(todo_id: int, db: Session = Depends(get_db), phone: str = Depends(get_phone)):
    """Delete a todo. Syncs to Postgres."""
    todo = db.query(Todo).filter(Todo.id == todo_id, Todo.phone == phone).first()
    if not todo:
        raise HTTPException(status_code=404, detail="Invalid id")

    task_text = todo.task
    db.delete(todo)
    db.commit()
    
    return {
        "message": f"Removed '{task_text}'",
        "todos": [{"id": t.id, "task": t.task, "phone": t.phone} for t in db.query(Todo).filter(Todo.phone == phone).all()],
    }
