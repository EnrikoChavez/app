# models.py
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, String, Boolean, DateTime, func, Date, Float

Base = declarative_base()

# Keep existing todos schema as requested, with apple_id added
class Todo(Base):
    __tablename__ = "todos"

    id = Column(Integer, primary_key=True, index=True)
    task = Column(String, index=True)
    phone = Column(String, index=True)  # 🔑 link each todo to a phone
    apple_id = Column(String, index=True, nullable=True)  # Apple ID for user identification
    # Sync fields
    synced_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())


# New profiles table for premium status
class Profile(Base):
    __tablename__ = "profiles"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, unique=True, index=True, nullable=False)
    is_premium = Column(Boolean, default=False, nullable=False)
    last_active = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


# Call usage tracking for daily limits
class CallUsage(Base):
    __tablename__ = "call_usage"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, index=True, nullable=False)
    usage_date = Column(Date, nullable=False, index=True)  # Date only (no time)
    seconds_used = Column(Float, default=0.0, nullable=False)  # Total seconds used today
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Unique constraint: one record per phone per day
    __table_args__ = (
        {'sqlite_autoincrement': True},
    )


# Chat usage tracking for daily limits
class ChatUsage(Base):
    __tablename__ = "chat_usage"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, index=True, nullable=False)
    usage_date = Column(Date, nullable=False, index=True)  # Date only (no time)
    message_count = Column(Integer, default=0, nullable=False)  # Total messages sent today
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Unique constraint: one record per phone per day
    __table_args__ = (
        {'sqlite_autoincrement': True},
    )


# Manual unblock usage tracking for daily limits
class ManualUnblockUsage(Base):
    __tablename__ = "manual_unblock_usage"

    id = Column(Integer, primary_key=True, index=True)
    phone = Column(String, index=True, nullable=False)
    usage_date = Column(Date, nullable=False, index=True)  # Date only (no time)
    unblock_count = Column(Integer, default=0, nullable=False)  # Total manual unblocks today
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Unique constraint: one record per phone per day
    __table_args__ = (
        {'sqlite_autoincrement': True},
    )
