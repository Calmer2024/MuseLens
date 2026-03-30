"""
RAG client abstractions and default implementations for lens retrieval.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Dict, Iterable, List, Protocol

from app.lenses.registry import LENS_REGISTRY
from app.schemas.lens import LensTemplate


EMBEDDING_DIM: int = 256

_LATIN_TOKEN_RE = re.compile(r"[a-zA-Z0-9_]+")
_CJK_RE = re.compile(r"[\u4e00-\u9fff]+")


def tokenize_text(text: str) -> List[str]:
    """
    Lightweight mixed Chinese/English tokenization.

    - Keep latin words/numbers as lowercase tokens
    - Extract contiguous CJK spans
    - For CJK spans, emit the whole span and overlapping 2/3-grams
    """
    if not text:
        return []

    normalized = text.lower()
    tokens: List[str] = []
    tokens.extend(_LATIN_TOKEN_RE.findall(normalized))

    for match in _CJK_RE.finditer(normalized):
        span = match.group(0).strip()
        if not span:
            continue
        tokens.append(span)
        if len(span) >= 2:
            for n in (2, 3):
                if len(span) < n:
                    continue
                for i in range(len(span) - n + 1):
                    tokens.append(span[i : i + n])

    deduped: List[str] = []
    seen = set()
    for tok in tokens:
        if tok and tok not in seen:
            seen.add(tok)
            deduped.append(tok)
    return deduped


def default_encode_text_to_vector(text: str, dim: int = EMBEDDING_DIM) -> List[float]:
    """
    Small local embedding implementation used for pgvector bootstrap/search.
    """
    if not text:
        return [0.0] * dim

    tokens = tokenize_text(text)

    vec = [0.0] * dim
    for tok in tokens:
        idx = hash(tok) % dim
        vec[idx] += 1.0

    norm_sq = sum(v * v for v in vec)
    if norm_sq <= 0:
        return vec
    norm = norm_sq**0.5
    return [v / norm for v in vec]


@dataclass
class LensCandidate:
    lens_id: str
    score: float
    template: LensTemplate


class BaseLensRAGClient(Protocol):
    def search_lenses(self, query_text: str, k: int = 5) -> List[LensCandidate]:
        ...


class InMemoryLensRAGClient:
    """
    Simple lexical retrieval over the in-memory registry.
    """

    def __init__(self, registry: Dict[str, LensTemplate] | None = None) -> None:
        self._registry: Dict[str, LensTemplate] = registry or LENS_REGISTRY

    def search_lenses(self, query_text: str, k: int = 5) -> List[LensCandidate]:
        tokens = tokenize_text(query_text)

        scored: List[LensCandidate] = []
        for lens_id, tmpl in self._registry.items():
            score = self._score_template(tokens, tmpl)
            scored.append(LensCandidate(lens_id=lens_id, score=score, template=tmpl))

        scored.sort(key=lambda c: c.score, reverse=True)
        return scored[: max(k, 0)]

    @staticmethod
    def _score_template(tokens: Iterable[str], tmpl: LensTemplate) -> float:
        if not tokens:
            return 0.0

        haystack_parts: List[str] = [tmpl.description or "", tmpl.lens_id, tmpl.layer.value]
        for p in tmpl.params:
            haystack_parts.append(p.name)
            haystack_parts.append(p.description or "")

        haystack_tokens = set(tokenize_text(" ".join(haystack_parts)))

        score = 0.0
        for tok in tokens:
            if tok in haystack_tokens:
                score += 1.0
        return score


class PgVectorLensRAGClient:
    """
    PostgreSQL + pgvector based retrieval.
    """

    def __init__(
        self,
        dsn: str,
        table_name: str = "lens_embeddings",
        top_k: int = 5,
        encode_text_to_vector=default_encode_text_to_vector,
    ) -> None:
        self._dsn = dsn
        self._table_name = table_name
        self._top_k = top_k
        self._encode_text_to_vector = encode_text_to_vector

    def search_lenses(self, query_text: str, k: int = 5) -> List[LensCandidate]:
        if not self._encode_text_to_vector:
            raise RuntimeError("PgVectorLensRAGClient requires encode_text_to_vector.")

        query_vec = self._to_vector_literal(self._encode_text_to_vector(query_text))

        try:
            import psycopg  # type: ignore
        except ImportError as exc:
            raise RuntimeError("PgVectorLensRAGClient requires psycopg.") from exc

        sql = f"""
        SELECT lens_id, 1 - (embedding <=> %(query_vec)s) AS score
        FROM {self._table_name}
        ORDER BY embedding <-> %(query_vec)s
        LIMIT %(limit)s
        """

        results: List[LensCandidate] = []
        try:
            with psycopg.connect(self._dsn) as conn:  # type: ignore[attr-defined]
                with conn.cursor() as cur:
                    cur.execute(sql, {"query_vec": query_vec, "limit": k or self._top_k})
                    rows = cur.fetchall()
        except Exception as exc:
            print(f"[PgVectorLensRAGClient] 警告：pgvector 检索失败，返回空列表：{exc}")
            return []

        for lens_id, score in rows:
            tmpl = LENS_REGISTRY.get(lens_id)
            if not tmpl:
                continue
            results.append(
                LensCandidate(lens_id=str(lens_id), score=float(score), template=tmpl)
            )

        return results

    @staticmethod
    def _to_vector_literal(vec: Iterable[float]) -> str:
        return "[" + ",".join(str(float(v)) for v in vec) + "]"
