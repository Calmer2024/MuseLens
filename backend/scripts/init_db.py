#!/usr/bin/env python3
"""Initialize the backend database."""

from __future__ import annotations

import sys
from pathlib import Path

from sqlalchemy import create_engine, text


BACKEND_DIR = Path(__file__).resolve().parents[1]
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.core.database import DATABASE_URL, normalize_database_url  # noqa: E402
from app.core.db_base import Base  # noqa: E402


def init_database() -> None:
    url = normalize_database_url(DATABASE_URL)
    print(f"[init_db] database url: {url}")

    from app.models import asset_tree_models  # noqa: F401
    from app.models import community_models  # noqa: F401
    from app.models import lens_example_model  # noqa: F401
    from app.models import lens_model  # noqa: F401
    from app.models import market_models  # noqa: F401
    from app.models import router_session_model  # noqa: F401
    from app.models import user_models  # noqa: F401

    engine = create_engine(
        url,
        connect_args={"check_same_thread": False} if url.startswith("sqlite") else {},
        echo=True,
    )

    Base.metadata.create_all(bind=engine)

    if not url.startswith("sqlite"):
        with engine.begin() as conn:
            try:
                conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector;"))
                print("[init_db] pgvector extension checked.")
            except Exception as exc:
                print(f"[init_db] skip pgvector extension: {exc}")

    print("[init_db] database initialization complete.")


if __name__ == "__main__":
    init_database()
