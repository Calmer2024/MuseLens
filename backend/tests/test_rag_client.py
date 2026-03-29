import pytest

from app.lenses.registry import LENS_REGISTRY
from app.services.rag_client import (
    EMBEDDING_DIM,
    InMemoryLensRAGClient,
    LensCandidate,
    PgVectorLensRAGClient,
    default_encode_text_to_vector,
)


def test_default_encode_text_to_vector_empty_string():
    """空字符串应返回全零向量，长度为 EMBEDDING_DIM。"""
    vec = default_encode_text_to_vector("")
    assert len(vec) == EMBEDDING_DIM
    assert all(v == 0.0 for v in vec)


def test_default_encode_text_to_vector_non_empty_normalized():
    """非空文本应返回 L2 归一化后的向量，长度为 EMBEDDING_DIM。"""
    vec = default_encode_text_to_vector("抠图 多肉 背景")
    assert len(vec) == EMBEDDING_DIM
    norm_sq = sum(v * v for v in vec)
    assert abs(norm_sq - 1.0) < 1e-5 or norm_sq == 0  # 允许全零（极端分词结果）


def test_default_encode_text_to_vector_custom_dim():
    """可指定维度 dim。"""
    vec = default_encode_text_to_vector("hello", dim=128)
    assert len(vec) == 128


def test_inmemory_rag_client_returns_known_lenses():
    client = InMemoryLensRAGClient()

    # 使用包含“抠图”“多肉”等关键词的查询，期望能够召回注册表中的透镜
    query = "请用抠图和多肉相关的能力编辑图片"
    results = client.search_lenses(query, k=5)

    assert results  # 至少返回一个候选
    returned_ids = {c.lens_id for c in results}

    # 所有返回的 lens_id 都应该来自当前注册表
    assert returned_ids.issubset(set(LENS_REGISTRY.keys()))


def test_inmemory_rag_client_respects_k():
    """应最多返回 k 个候选。"""
    client = InMemoryLensRAGClient()
    results = client.search_lenses("抠图", k=2)
    assert len(results) <= 2
    for c in results:
        assert isinstance(c, LensCandidate)
        assert c.lens_id in LENS_REGISTRY
        assert 0 <= c.score


def test_inmemory_rag_client_k_zero_returns_empty():
    """k=0 时应返回空列表。"""
    client = InMemoryLensRAGClient()
    results = client.search_lenses("任意查询", k=0)
    assert results == []


def test_inmemory_rag_client_empty_query_returns_sorted_candidates():
    """空查询时仍返回按分数排序的候选（可能全 0 分）。"""
    client = InMemoryLensRAGClient()
    results = client.search_lenses("", k=5)
    assert len(results) <= 5
    if len(results) >= 2:
        assert results[0].score >= results[-1].score


def test_pgvector_client_requires_encoder_when_overridden():
    """
    仅做占位测试：验证当显式传入 encode_text_to_vector=None 时会抛出清晰错误，
    避免误用。
    """
    client = PgVectorLensRAGClient(
        dsn="postgresql://user:pass@localhost/db",
        encode_text_to_vector=None,  # type: ignore[arg-type]
    )
    with pytest.raises(RuntimeError):
        client.search_lenses("test", k=1)
