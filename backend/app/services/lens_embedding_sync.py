from __future__ import annotations

"""
基于 PostgreSQL + pgvector 的 Lens 向量表同步工具。

目标：
- 从当前 LENS_REGISTRY 中抽取每个透镜的文本描述；
- 使用与 PgVectorLensRAGClient 一致的 encode_text_to_vector 生成向量；
- 将结果写入 / 更新到 PostgreSQL 中的 lens_embeddings 表；
- 确保在透镜数量增多时，只需“新增透镜配置 + 重新跑一次同步”即可扩展。
"""

from typing import Callable, Dict, Iterable, List

from app.lenses.registry import LENS_REGISTRY
from app.schemas.lens import LensTemplate
from app.services.rag_client import EMBEDDING_DIM, default_encode_text_to_vector


def _build_lens_corpus(tmpl: LensTemplate) -> str:
    """
    为单个 Lens 构造用于编码的文本语料。
    默认包含：
    - lens_id
    - layer
    - description
    - 所有参数名称与描述
    """
    parts: List[str] = [
        tmpl.lens_id,
        tmpl.layer.value,
        tmpl.description or "",
    ]
    for p in tmpl.params:
        parts.append(p.name)
        if p.description:
            parts.append(p.description)
    return " ".join(parts)


def _to_vector_literal(vec: Iterable[float]) -> str:
    """
    将 Python 序列转换为 pgvector 文本字面量形式：
    [0.1,0.2,0.3]
    """
    return "[" + ",".join(str(float(v)) for v in vec) + "]"


def ensure_lens_embeddings_schema(dsn: str, table_name: str = "lens_embeddings") -> None:
    """
    确保 pgvector 扩展和 lens_embeddings 表存在。

    注意：
    - 默认使用 EMBEDDING_DIM 作为向量维度；
    - 使用 ivfflat 索引，lists 参数可根据数据量调整。
    """
    try:
        import psycopg  # type: ignore
    except ImportError as exc:  # pragma: no cover - 仅在缺依赖时触发
        raise RuntimeError(
            "ensure_lens_embeddings_schema 需要 psycopg 支持，请在后端环境中安装。"
        ) from exc

    create_sql = f"""
    CREATE EXTENSION IF NOT EXISTS vector;

    CREATE TABLE IF NOT EXISTS {table_name} (
        lens_id    TEXT PRIMARY KEY,
        embedding  VECTOR({EMBEDDING_DIM}) NOT NULL,
        description TEXT,
        layer       TEXT
    );

    CREATE INDEX IF NOT EXISTS idx_{table_name}_embedding
    ON {table_name}
    USING ivfflat (embedding vector_l2_ops)
    WITH (lists = 100);
    """

    with psycopg.connect(dsn) as conn:  # type: ignore[attr-defined]
        with conn.cursor() as cur:
            cur.execute(create_sql)
        conn.commit()


def sync_lens_embeddings(
    dsn: str,
    table_name: str = "lens_embeddings",
    encode_text_to_vector: Callable[[str], Iterable[float]] = default_encode_text_to_vector,
    registry: Dict[str, LensTemplate] | None = None,
) -> int:
    """
    将给定 registry（默认使用全局 LENS_REGISTRY）中的所有透镜
    同步到 PostgreSQL + pgvector 表中。

    返回成功 upsert 的条目数量。
    """
    try:
        import psycopg  # type: ignore
    except ImportError as exc:  # pragma: no cover - 仅在缺依赖时触发
        raise RuntimeError(
            "sync_lens_embeddings 需要 psycopg 支持，请在后端环境中安装。"
        ) from exc

    reg = LENS_REGISTRY if registry is None else registry
    if not reg:
        return 0

    ensure_lens_embeddings_schema(dsn, table_name=table_name)

    upsert_sql = f"""
    INSERT INTO {table_name} (lens_id, embedding, description, layer)
    VALUES (%(lens_id)s, %(embedding)s, %(description)s, %(layer)s)
    ON CONFLICT (lens_id) DO UPDATE SET
        embedding  = EXCLUDED.embedding,
        description = EXCLUDED.description,
        layer       = EXCLUDED.layer;
    """

    count = 0
    with psycopg.connect(dsn) as conn:  # type: ignore[attr-defined]
        with conn.cursor() as cur:
            for lens_id, tmpl in reg.items():
                corpus = _build_lens_corpus(tmpl)
                vec = encode_text_to_vector(corpus)
                vec_literal = _to_vector_literal(vec)
                params = {
                    "lens_id": lens_id,
                    "embedding": vec_literal,
                    "description": tmpl.description,
                    "layer": tmpl.layer.value,
                }
                cur.execute(upsert_sql, params)
                count += 1
        conn.commit()

    return count

