import os

import pytest


@pytest.mark.pgvector
def test_pgvector_retrieval_e2e_smoke():
    """
    可选的 pgvector 端到端冒烟测试骨架。

    运行条件：
    - 设置 MUSELENS_PG_DSN 指向带 pgvector 的 Postgres
    - 已执行 lens_embeddings 同步（见 app/services/lens_embedding_sync.py）

    说明：
    - 默认在 CI/本地未配置时自动 skip。
    """
    dsn = os.getenv("MUSELENS_PG_DSN")
    if not dsn:
        pytest.skip("MUSELENS_PG_DSN not set")

    # 这里不做强断言（不同环境数据不同），仅验证客户端能连通并返回列表
    from app.services.rag_client import PgVectorLensRAGClient

    client = PgVectorLensRAGClient(dsn=dsn, table_name=os.getenv("MUSELENS_RAG_PGVECTOR_TABLE", "lens_embeddings"))
    items = client.search_lenses("抠图", k=3)
    assert isinstance(items, list)

