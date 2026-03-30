"""
Database configuration for the backend.

PostgreSQL is the primary target database. SQLite remains available as a
lightweight fallback for unit tests and local smoke checks.
"""

from __future__ import annotations

import os
from pathlib import Path

from sqlalchemy import create_engine, pool
from sqlalchemy.engine import Engine
from sqlalchemy.orm import sessionmaker

from app.core.db_base import Base


def _default_sqlite_url() -> str:
    backend_dir = Path(__file__).resolve().parents[2]
    return f"sqlite:///{backend_dir / 'muselens.db'}"


def normalize_database_url(url: str | None) -> str:
    raw = (url or "").strip()
    if not raw or raw.lower() == "sqlite":
        return _default_sqlite_url()
    if raw.startswith("postgres://"):
        raw = raw.replace("postgres://", "postgresql+psycopg://", 1)
    elif raw.startswith("postgresql://"):
        raw = raw.replace("postgresql://", "postgresql+psycopg://", 1)
    return raw


def get_database_url() -> str:
    return normalize_database_url(
        os.getenv("MUSELENS_DB_URL")
        or os.getenv("DATABASE_URL")
    )


def create_db_engine(database_url: str | None = None) -> Engine:
    url = normalize_database_url(database_url or get_database_url())
    if url.startswith("sqlite"):
        return create_engine(
            url,
            connect_args={"check_same_thread": False},
        )

    return create_engine(
        url,
        poolclass=pool.QueuePool,
        pool_size=10,
        max_overflow=20,
        pool_pre_ping=True,
    )


DATABASE_URL = get_database_url()
engine = create_db_engine(DATABASE_URL)
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,
    bind=engine,
)


def get_db():
    """FastAPI dependency for a database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Create all ORM tables if they do not already exist."""
    from app.models import asset_tree_models  # noqa: F401
    from app.models import chat_models  # noqa: F401
    from app.models import community_models  # noqa: F401
    from app.models import lens_example_model  # noqa: F401
    from app.models import lens_model  # noqa: F401
    from app.models import market_models  # noqa: F401
    from app.models import router_session_model  # noqa: F401
    from app.models import user_models  # noqa: F401

    Base.metadata.create_all(bind=engine)
