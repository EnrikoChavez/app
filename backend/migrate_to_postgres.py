#!/usr/bin/env python3
"""
Migration script to move from SQLite to Postgres.
Run this once to migrate existing data.
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Load old SQLite
SQLITE_PATH = "./todos.db"
sqlite_engine = create_engine(f"sqlite:///{SQLITE_PATH}")

# Load new Postgres
load_dotenv()
IS_LOCAL = os.getenv("IS_LOCAL", "True").lower() == "true"

if IS_LOCAL:
    POSTGRES_USER = os.getenv("POSTGRES_USER", "postgres")
    POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")
    POSTGRES_HOST = os.getenv("POSTGRES_HOST", "localhost")
    POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5432")
    POSTGRES_DB = os.getenv("POSTGRES_DB", "anti_doomscroll")
    DATABASE_URL = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
else:
    DATABASE_URL = os.getenv("DATABASE_URL")

postgres_engine = create_engine(DATABASE_URL)

# Import models
from models import Base, Todo
from todo import Todo as OldTodo  # SQLite model

# Create Postgres tables
Base.metadata.create_all(bind=postgres_engine)

# Create sessions
SQLiteSession = sessionmaker(bind=sqlite_engine)
PostgresSession = sessionmaker(bind=postgres_engine)

sqlite_session = SQLiteSession()
postgres_session = PostgresSession()

try:
    # Migrate todos
    old_todos = sqlite_session.query(OldTodo).all()
    print(f"📦 Found {len(old_todos)} todos to migrate...")
    
    for old_todo in old_todos:
        new_todo = Todo(
            id=old_todo.id,
            task=old_todo.task,
            phone=old_todo.phone
        )
        postgres_session.merge(new_todo)  # Use merge to handle duplicates
    
    postgres_session.commit()
    print(f"✅ Migrated {len(old_todos)} todos to Postgres!")
    
except Exception as e:
    postgres_session.rollback()
    print(f"❌ Migration failed: {e}")
finally:
    sqlite_session.close()
    postgres_session.close()
