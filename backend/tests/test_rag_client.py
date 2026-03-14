from app.lenses.registry import LENS_REGISTRY
from app.services.rag_client import InMemoryLensRAGClient


def test_inmemory_rag_client_returns_known_lenses():
    client = InMemoryLensRAGClient()

    # 使用包含“抠图”“多肉”等关键词的查询，期望能够召回注册表中的透镜
    query = "请用抠图和多肉相关的能力编辑图片"
    results = client.search_lenses(query, k=5)

    assert results  # 至少返回一个候选
    returned_ids = {c.lens_id for c in results}

    # 所有返回的 lens_id 都应该来自当前注册表
    assert returned_ids.issubset(set(LENS_REGISTRY.keys()))

