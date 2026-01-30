# db.py
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Use /data on Render (mounted persistent disk). Fallback to local file when not set.
SQLITE_PATH = os.getenv("SQLITE_PATH", "./todos.db")
DATABASE_URL = f"sqlite:///{SQLITE_PATH}"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},  # required for SQLite + threads
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db(Base):
    """Create tables if they don't exist."""
    # Ensure folder exists if using a path like /data/todos.db
    os.makedirs(os.path.dirname(os.path.abspath(SQLITE_PATH)), exist_ok=True)
    Base.metadata.create_all(bind=engine)
