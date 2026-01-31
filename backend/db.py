# db.py
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

# ==========================================
# 🚀 DEPLOYMENT SWITCH
# ==========================================
IS_LOCAL = False  # Set to False when deploying to cloud
# ==========================================

# Postgres Configuration
if IS_LOCAL:
    # Local Postgres (default connection)
    POSTGRES_USER = os.getenv("POSTGRES_USER", "postgres")
    POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "postgres")
    POSTGRES_HOST = os.getenv("POSTGRES_HOST", "localhost")
    POSTGRES_PORT = os.getenv("POSTGRES_PORT", "5432")
    POSTGRES_DB = os.getenv("POSTGRES_DB", "anti_doomscroll")
    DATABASE_URL = f"postgresql://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
    # Async URL for async operations
    DATABASE_URL_ASYNC = f"postgresql+asyncpg://{POSTGRES_USER}:{POSTGRES_PASSWORD}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}"
else:
    # Cloud Postgres (from environment variables, e.g., Render/Supabase)
    DATABASE_URL = os.getenv("DATABASE_URL")
    if not DATABASE_URL:
        raise ValueError("DATABASE_URL environment variable must be set for cloud deployment")
    # Convert postgres:// to postgresql+asyncpg:// for async
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL_ASYNC = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)
    else:
        DATABASE_URL_ASYNC = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)

# Sync engine (for SQLAlchemy ORM)
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

# Async engine (for async operations)
async_engine = create_async_engine(
    DATABASE_URL_ASYNC,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
AsyncSessionLocal = async_sessionmaker(async_engine, class_=AsyncSession, expire_on_commit=False)

def get_db():
    """Dependency for FastAPI to get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

async def get_async_db():
    """Dependency for FastAPI to get async database session."""
    async with AsyncSessionLocal() as session:
        yield session

def init_db(Base):
    """Create tables if they don't exist."""
    Base.metadata.create_all(bind=engine)
    print(f"✅ Database initialized: {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else 'local'}")