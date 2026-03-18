from __future__ import annotations

import json
from typing import List

from sqlalchemy.orm import Session

from app.models.lens_example_model import LensExampleRecord
from app.models.lens_model import LensRecord
from app.schemas.retrieval import LensExample, LensKnowledge, LensParamSchema
from app.services.rag_client import BaseLensRAGClient


class RetrievalService:
    """
    Retrieval 层：只负责“找知识”。

    输入自然语言查询（可包含历史摘要）：
    - 先用 RAG 客户端召回候选 lens_id（pgvector 或 in-memory）
    - 再到 Catalog DB 补全结构化信息（description/params/examples）
    - 输出给 Planner 使用的 LensKnowledge 列表
    """

    def __init__(self, rag_client: BaseLensRAGClient) -> None:
        self._rag_client = rag_client

    def retrieve(
        self,
        db: Session,
        *,
        task_desc: str,
        top_k: int = 5,
        enabled_only: bool = False,
    ) -> List[LensKnowledge]:
        if not task_desc:
            return []

        # 1) 向量召回：只得到 lens_id + score
        candidates = self._rag_client.search_lenses(task_desc, k=top_k)
        if not candidates:
            return []

        lens_ids = [c.lens_id for c in candidates]
        score_by_id = {c.lens_id: float(c.score) for c in candidates}

        # 2) Catalog 补全：从 lenses 表读取 description/layer/params
        records: List[LensRecord] = (
            db.query(LensRecord).filter(LensRecord.lens_id.in_(lens_ids)).all()
        )
        record_by_id = {r.lens_id: r for r in records}

        # 3) Examples：从 lens_examples 表读取 few-shot 语料
        ex_rows: List[LensExampleRecord] = (
            db.query(LensExampleRecord).filter(LensExampleRecord.lens_id.in_(lens_ids)).all()
        )
        examples_by_id = {}
        for row in ex_rows:
            examples_by_id.setdefault(row.lens_id, []).append(
                LensExample(nl_desc=row.nl_desc or "", params_example=row.params_example or {})
            )

        # 4) 组装输出（保持候选排序）
        result: List[LensKnowledge] = []
        for lens_id in lens_ids:
            rec = record_by_id.get(lens_id)
            if not rec:
                # 向量库里可能存在，但 Catalog 里缺失；跳过避免 Planner 误用
                continue

            raw_params = []
            try:
                raw_params = json.loads(rec.params_json or "[]")
            except Exception:
                raw_params = []

            params: List[LensParamSchema] = []
            for p in raw_params:
                # 兼容当前 register 接口写入的结构：{name,type,description,mapping:{...}}
                params.append(
                    LensParamSchema(
                        name=str(p.get("name", "")),
                        type=str(p.get("type", "")),
                        description=str(p.get("description", "")),
                        required=bool(p.get("required", False)),
                        default=p.get("default", None),
                    )
                )

            result.append(
                LensKnowledge(
                    lens_id=lens_id,
                    score=score_by_id.get(lens_id, 0.0),
                    layer=rec.layer or "",
                    description=rec.description or "",
                    params=params,
                    examples=examples_by_id.get(lens_id, []),
                )
            )

        return result


def build_task_desc(*, user_message: str, history_summary: str = "") -> str:
    """
    最小 task_desc 组装器：后续可扩展为更智能的摘要拼接策略。
    """
    if history_summary:
        return f"历史摘要：{history_summary}\n用户本轮：{user_message}"
    return user_message

