from __future__ import annotations

"""
Sync lens embeddings into PostgreSQL + pgvector.
"""

import json
from typing import Any, Callable, Dict, Iterable, List

from app.lenses.registry import LENS_REGISTRY
from app.schemas.lens import LensTemplate
from app.services.lens_docs_service import load_lens_doc
from app.services.rag_client import EMBEDDING_DIM, default_encode_text_to_vector


def _load_lens_examples_from_db(lens_ids: Iterable[str]) -> Dict[str, List[Dict[str, Any]]]:
    try:
        from app.core.database import SessionLocal
        from app.models.lens_example_model import LensExampleRecord
    except Exception:
        return {}

    lens_id_list = list(lens_ids)
    if not lens_id_list:
        return {}

    try:
        db = SessionLocal()
        try:
            rows = (
                db.query(LensExampleRecord)
                .filter(LensExampleRecord.lens_id.in_(lens_id_list))
                .all()
            )
        finally:
            db.close()
    except Exception:
        return {}

    examples_by_id: Dict[str, List[Dict[str, Any]]] = {}
    for r in rows:
        examples_by_id.setdefault(str(r.lens_id), []).append(
            {"nl_desc": r.nl_desc or "", "params_example": r.params_example or {}}
        )
    return examples_by_id


def _build_lens_corpus(
    tmpl: LensTemplate,
    *,
    examples: List[Dict[str, Any]] | None = None,
) -> str:
    parts: List[str] = [tmpl.lens_id, tmpl.layer.value, tmpl.description or ""]

    for asset in tmpl.inputs:
        parts.append(asset.name)
        parts.append(asset.type.value)
    for asset in tmpl.outputs:
        parts.append(asset.name)
        parts.append(asset.type.value)

    for p in tmpl.params:
        parts.append(p.name)
        if p.description:
            parts.append(p.description)

    doc = load_lens_doc(tmpl.lens_id)
    if doc:
        if doc.description:
            parts.append(doc.description)
        if doc.body:
            parts.append(doc.body)
        for pdoc in (doc.params or {}).values():
            parts.append(pdoc.name)
            if pdoc.description:
                parts.append(pdoc.description)
            if pdoc.decision_rules:
                parts.append(pdoc.decision_rules)
            if pdoc.format_rules:
                parts.append(pdoc.format_rules)
        for ex in doc.examples or []:
            nl_desc = str(ex.get("nl_desc") or "")
            if nl_desc:
                parts.append(nl_desc)
            params_example = ex.get("params_example") or {}
            if params_example:
                parts.append(json.dumps(params_example, ensure_ascii=False))

    for ex in examples or []:
        nl_desc = str(ex.get("nl_desc") or "")
        if nl_desc:
            parts.append(nl_desc)
        params_example = ex.get("params_example") or {}
        if params_example:
            parts.append(json.dumps(params_example, ensure_ascii=False))

    return " ".join(parts)


def _to_vector_literal(vec: Iterable[float]) -> str:
    return "[" + ",".join(str(float(v)) for v in vec) + "]"


def ensure_lens_embeddings_schema(dsn: str, table_name: str = "lens_embeddings") -> None:
    try:
        import psycopg  # type: ignore
    except ImportError as exc:
        raise RuntimeError("ensure_lens_embeddings_schema 需要 psycopg 支持。") from exc

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
    include_examples: bool = True,
) -> int:
    try:
        import psycopg  # type: ignore
    except ImportError as exc:
        raise RuntimeError("sync_lens_embeddings 需要 psycopg 支持。") from exc

    reg = LENS_REGISTRY if registry is None else registry
    if not reg:
        return 0

    examples_by_id: Dict[str, List[Dict[str, Any]]] = {}
    if include_examples:
        examples_by_id = _load_lens_examples_from_db(reg.keys())

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
                corpus = _build_lens_corpus(tmpl, examples=examples_by_id.get(lens_id, []))
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
