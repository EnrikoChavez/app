from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from fastapi import Header
from db import get_db

# -----------------------------------
# Database setup
# -----------------------------------
DATABASE_URL = "sqlite:///./todos.db"

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


# -----------------------------------
# SQLAlchemy model
# -----------------------------------
class Todo(Base):
    __tablename__ = "todos"

    id = Column(Integer, primary_key=True, index=True)
    task = Column(String, index=True)
    phone = Column(String, index=True)  # 🔑 link each todo to a phone


# Create the table if not exists
Base.metadata.create_all(bind=engine)


# -----------------------------------
# FastAPI router
# -----------------------------------
router = APIRouter(prefix="/todos", tags=["todos"])


class TodoItem(BaseModel):
    task: str



# Helper: get phone number from header (simple auth mechanism)
def get_phone(x_phone: str = Header(...)):
    return x_phone


@router.get("")
def get_todos(db: Session = Depends(get_db), phone: str = Depends(get_phone)):
    todos = db.query(Todo).filter(Todo.phone == phone).all()
    return {"todos": [{"id": t.id, "task": t.task, "phone": t.phone} for t in todos]}


@router.post("")
def add_todo(item: TodoItem, db: Session = Depends(get_db), phone: str = Depends(get_phone)):
    todo = Todo(task=item.task, phone=phone)
    db.add(todo)
    db.commit()
    db.refresh(todo)
    return {
        "message": "Todo added",
        "todos": [{"id": t.id, "task": t.task, "phone": t.phone} for t in db.query(Todo).filter(Todo.phone == phone)],
    }


@router.put("/{todo_id}")
def update_todo(todo_id: int, item: TodoItem, db: Session = Depends(get_db), phone: str = Depends(get_phone)):
    todo = db.query(Todo).filter(Todo.id == todo_id, Todo.phone == phone).first()
    if not todo:
        raise HTTPException(status_code=404, detail="Invalid id")

    todo.task = item.task
    db.commit()
    db.refresh(todo)
    return {"message": f"Updated todo {todo_id}", "todo": {"id": todo.id, "task": todo.task, "phone": todo.phone}}


@router.delete("/{todo_id}")
def delete_todo(todo_id: int, db: Session = Depends(get_db), phone: str = Depends(get_phone)):
    todo = db.query(Todo).filter(Todo.id == todo_id, Todo.phone == phone).first()
    if not todo:
        raise HTTPException(status_code=404, detail="Invalid id")

    db.delete(todo)
    db.commit()
    
    return {
        "message": f"Removed '{todo.task}'",
        "todos": [{"id": t.id, "task": t.task, "phone": t.phone} for t in db.query(Todo).filter(Todo.phone == phone)],
    }
