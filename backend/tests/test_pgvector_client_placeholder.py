import pytest

from app.services.rag_client import PgVectorLensRAGClient


def test_pgvector_client_requires_encoder_when_overridden():
    """
    仅做占位测试：验证当显式传入 encode_text_to_vector=None 时会抛出清晰错误，
    避免误用。
    """
    client = PgVectorLensRAGClient(dsn="postgresql://user:pass@localhost/db", encode_text_to_vector=None)  # type: ignore[arg-type]

    with pytest.raises(RuntimeError):
        client.search_lenses("test", k=1)

