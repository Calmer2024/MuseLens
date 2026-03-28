"""
Cross-database SQLAlchemy column types.

The backend is PostgreSQL-first, but we keep SQLite-compatible fallbacks for
unit tests and lightweight local checks. These helpers let the ORM expose
PostgreSQL-native capabilities in production while remaining creatable on
SQLite during tests.
"""

from sqlalchemy import BigInteger, Integer, JSON, String, Text
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID


UUID_STR = String(36).with_variant(UUID(as_uuid=False), "postgresql")
JSON_DOC = JSON().with_variant(JSONB(astext_type=Text()), "postgresql")
UUID_ARRAY = JSON().with_variant(ARRAY(UUID(as_uuid=False)), "postgresql")
BIGINT_ID = Integer().with_variant(BigInteger(), "postgresql")
