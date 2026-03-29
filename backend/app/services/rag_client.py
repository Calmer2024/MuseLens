"""
RAG 客户端抽象与默认实现。

本模块为 Router 提供基于 Lens 协议的语义检索接口：

- `BaseLensRAGClient`：定义统一的 `search_lenses` 能力；
- `InMemoryLensRAGClient`：基于当前 `LENS_REGISTRY` 的简易向量/相似度模拟实现，
  无需数据库，适合作为默认实现与测试用例依赖；
- `PgVectorLensRAGClient`：预留的 PostgreSQL + pgvector 实现骨架，依赖外部
  数据库与 embedding 服务，但不会在模块导入阶段强制引入第三方驱动。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, List, Protocol

from app.lenses.registry import LENS_REGISTRY
from app.schemas.lens import LensTemplate


# 默认的文本嵌入维度（用于 pgvector）
EMBEDDING_DIM: int = 256


def default_encode_text_to_vector(text: str, dim: int = EMBEDDING_DIM) -> List[float]:
    """
    一个无需依赖外部服务的简易文本 embedding 实现。

    思路：
    - 先用非常粗糙的分词（与 InMemoryLensRAGClient 的 _tokenize 保持一致风格）；
    - 将每个 token 的 hash 投影到固定维度的桶上，做计数累加；
    - 最后做一次 L2 归一化，得到长度为 dim 的向量。

    这不是“高质量语义向量”，但在 pgvector 上已经是一个
    真实可运行、可扩展的向量检索通路，方便后续无缝替换为
    真正的 embedding 服务。
    """
    if not text:
        return [0.0] * dim

    # 复用与 InMemoryLensRAGClient 相似的切分规则
    for ch in [",", "，", "。", ".", "！", "?", "？", "、", ";", "；", "：", ":"]:
        text = text.replace(ch, " ")
    tokens = [t.strip().lower() for t in text.split() if t.strip()]

    vec = [0.0] * dim
    for tok in tokens:
        h = hash(tok)
        idx = h % dim
        vec[idx] += 1.0

    # L2 归一化，避免长度随 token 数暴涨
    norm_sq = sum(v * v for v in vec)
    if norm_sq <= 0:
        return vec
    norm = norm_sq**0.5
    return [v / norm for v in vec]


@dataclass
class LensCandidate:
    """
    RAG 召回结果中的单个候选透镜。
    """

    lens_id: str
    score: float
    template: LensTemplate


class BaseLensRAGClient(Protocol):
    """
    Lens 语义检索客户端抽象。

    RouterService 只依赖这个接口，便于后续替换为真正的
    PostgreSQL + pgvector / 远程服务等实现。
    """

    def search_lenses(self, query_text: str, k: int = 5) -> List[LensCandidate]:
        """
        根据自然语言查询返回 Top-K 透镜候选。
        """
        ...


class InMemoryLensRAGClient:
    """
    基于内存 LENS_REGISTRY 的简易 RAG 实现。

    - 使用非常粗糙的关键词/词袋相似度作为分数；
    - 不依赖任何数据库或外部服务；
    - 作为 Router 的默认依赖与单元测试的基础实现。
    """

    def __init__(self, registry: Dict[str, LensTemplate] | None = None) -> None:
        self._registry: Dict[str, LensTemplate] = registry or LENS_REGISTRY

    def search_lenses(self, query_text: str, k: int = 5) -> List[LensCandidate]:
        tokens = self._tokenize(query_text)

        scored: List[LensCandidate] = []
        for lens_id, tmpl in self._registry.items():
            score = self._score_template(tokens, tmpl)
            scored.append(LensCandidate(lens_id=lens_id, score=score, template=tmpl))

        scored.sort(key=lambda c: c.score, reverse=True)
        return scored[: max(k, 0)]

    @staticmethod
    def _tokenize(text: str) -> List[str]:
        """
        极简中文/英文分词：按空白和常见标点切分。
        """
        if not text:
            return []
        for ch in [",", "，", "。", ".", "！", "?", "？", "、", ";", "；", "：", ":"]:
            text = text.replace(ch, " ")
        return [t.strip().lower() for t in text.split() if t.strip()]

    @staticmethod
    def _score_template(tokens: Iterable[str], tmpl: LensTemplate) -> float:
        """
        一个非常粗略的词袋重叠打分函数：

        - 将 query tokens 与 lens 的 description / layer / params 名称拼在一起；
        - 统计交集大小作为分数。
        """
        if not tokens:
            return 0.0

        haystack_parts: List[str] = [
            tmpl.description or "",
            tmpl.lens_id,
            tmpl.layer.value,
        ]
        for p in tmpl.params:
            haystack_parts.append(p.name)
            haystack_parts.append(p.description or "")

        haystack = " ".join(haystack_parts).lower()
        score = 0.0
        for t in tokens:
            if not t:
                continue
            if t in haystack:
                score += 1.0
        return score


class PgVectorLensRAGClient:
    """
    PostgreSQL + pgvector 的 Lens RAG 实现骨架。

    注意：
    - 为避免在未安装驱动/未配置数据库时阻塞整个后端启动，
      本类不会在模块导入阶段引入 psycopg/asyncpg，而是在
      `search_lenses` 内部按需导入。
    - 当前实现假设存在一张 `lens_embeddings` 表，包含：
      - lens_id (text, primary key 或 unique)
      - embedding (vector) — pgvector 类型
      - 其它可选元信息列
    - 向量编码函数 `encode_text_to_vector` 目前允许调用方传入，
      默认会抛出异常，提示需要接入真正的 embedding 服务。
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
            raise RuntimeError(
                "PgVectorLensRAGClient 需要提供 encode_text_to_vector 实现，"
                "以便将自然语言查询转换为向量。"
            )
        raw_vec = self._encode_text_to_vector(query_text)
        query_vec = self._to_vector_literal(raw_vec)

        # 延迟导入 psycopg，避免在未安装依赖时阻塞整个模块导入。
        try:
            import psycopg  # type: ignore
        except ImportError as exc:  # pragma: no cover - 仅在缺依赖时触发
            raise RuntimeError(
                "PgVectorLensRAGClient 需要 psycopg 支持，请在后端环境中安装。"
            ) from exc

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
                    cur.execute(
                        sql,  # type: ignore[arg-type]
                        {"query_vec": query_vec, "limit": k or self._top_k},
                    )
                    rows = cur.fetchall()
        except Exception as exc:
            # 端到端冒烟测试/开发环境中，pgvector 扩展可能未启用或表不存在。
            # 这种情况下返回空列表比直接抛异常更稳健。
            print(f"[PgVectorLensRAGClient] 警告：pgvector 检索失败，返回空列表：{exc}")
            return []

        for lens_id, score in rows:
            tmpl = LENS_REGISTRY.get(lens_id)
            if not tmpl:
                # 即使数据库中存在该 lens 的 embedding，如果本地 Registry
                # 不包含相应模板，则暂时跳过，避免运行期错误。
                continue
            results.append(
                LensCandidate(lens_id=str(lens_id), score=float(score), template=tmpl)
            )

        return results

    @staticmethod
    def _to_vector_literal(vec: Iterable[float]) -> str:
        """
        将 Python 序列转换为 pgvector 文本字面量形式：
        [0.1,0.2,0.3]
        """
        return "[" + ",".join(str(float(v)) for v in vec) + "]"

