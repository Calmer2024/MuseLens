from __future__ import annotations

from typing import Dict, List, Optional

from sqlalchemy.orm import Session

from app.models.lens_example_model import LensExampleRecord
from app.models.lens_model import LensRecord
from app.schemas.retrieval import LensAssetSchema, LensExample, LensKnowledge, LensParamSchema
from app.services.rag_client import BaseLensRAGClient
from app.services.lens_docs_service import load_lens_doc


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
        examples_by_id: Dict[str, List[LensExample]] = {}
        for row in ex_rows:
            examples_by_id.setdefault(row.lens_id, []).append(
                LensExample(nl_desc=row.nl_desc or "", params_example=row.params_example or {})
            )

        # 4) 组装输出（保持候选排序）
        result: List[LensKnowledge] = []
        for lens_id in lens_ids:
            lk = self._lens_knowledge_from_record(
                lens_id=lens_id,
                score=score_by_id.get(lens_id, 0.0),
                rec=record_by_id.get(lens_id),
                examples_by_id=examples_by_id,
            )
            if lk:
                result.append(lk)

        return result

    def retrieve_by_lens_ids(
        self,
        db: Session,
        lens_ids: List[str],
        *,
        score_by_id: Optional[Dict[str, float]] = None,
        enabled_only: bool = False,
    ) -> List[LensKnowledge]:
        """
        按 lens_id 精确拉取 Catalog + docs overlay + examples（不经过向量召回）。
        用于 Planner 首轮后按缺失信息 enrich candidates。
        """
        if not lens_ids:
            return []

        uniq: List[str] = []
        seen = set()
        for lid in lens_ids:
            if lid and lid not in seen:
                seen.add(lid)
                uniq.append(lid)

        scores = score_by_id or {}
        records: List[LensRecord] = (
            db.query(LensRecord).filter(LensRecord.lens_id.in_(uniq)).all()
        )
        record_by_id = {r.lens_id: r for r in records}

        ex_rows: List[LensExampleRecord] = (
            db.query(LensExampleRecord).filter(LensExampleRecord.lens_id.in_(uniq)).all()
        )
        examples_by_id: Dict[str, List[LensExample]] = {}
        for row in ex_rows:
            examples_by_id.setdefault(row.lens_id, []).append(
                LensExample(nl_desc=row.nl_desc or "", params_example=row.params_example or {})
            )

        result: List[LensKnowledge] = []
        for lens_id in uniq:
            lk = self._lens_knowledge_from_record(
                lens_id=lens_id,
                score=float(scores.get(lens_id, 0.0)),
                rec=record_by_id.get(lens_id),
                examples_by_id=examples_by_id,
            )
            if lk:
                result.append(lk)

        return result

    def _lens_knowledge_from_record(
        self,
        *,
        lens_id: str,
        score: float,
        rec: Optional[LensRecord],
        examples_by_id: Dict[str, List[LensExample]],
    ) -> Optional[LensKnowledge]:
        if not rec:
            return None

        doc = None
        try:
            doc = load_lens_doc(lens_id)
        except Exception:
            doc = None

        raw_params = rec.params or []
        raw_inputs = rec.inputs or []
        raw_outputs = rec.outputs or []

        params: List[LensParamSchema] = []
        for p in raw_params:
            name = str(p.get("name", ""))
            params.append(
                LensParamSchema(
                    name=name,
                    type=str(p.get("type", "")),
                    description=str(p.get("description", "")),
                    required=bool(p.get("required", False)),
                    default=p.get("default", None),
                )
            )

        inputs: List[LensAssetSchema] = []
        for item in raw_inputs:
            inputs.append(
                LensAssetSchema(
                    name=str(item.get("name", "")),
                    type=str(item.get("type", "")),
                    description=str(item.get("description", "")),
                )
            )

        outputs: List[LensAssetSchema] = []
        for item in raw_outputs:
            outputs.append(
                LensAssetSchema(
                    name=str(item.get("name", "")),
                    type=str(item.get("type", "")),
                    description=str(item.get("description", "")),
                )
            )

        if doc:
            if doc.description:
                rec_description = str(doc.description)
            else:
                rec_description = rec.description or ""

            doc_params = doc.params or {}
            if doc_params:
                merged_params: List[LensParamSchema] = []
                for ps in params:
                    dp = doc_params.get(ps.name)
                    if dp:
                        merged_params.append(
                            LensParamSchema(
                                name=ps.name,
                                type=ps.type,
                                description=dp.merged_description(
                                    base_description=ps.description or ""
                                ),
                                required=bool(dp.required)
                                if dp.required is not None
                                else ps.required,
                                default=dp.default
                                if dp.default is not None
                                else ps.default,
                            )
                        )
                    else:
                        merged_params.append(ps)
                params = merged_params
            description = rec_description
        else:
            description = rec.description or ""

        return LensKnowledge(
            lens_id=lens_id,
            score=score,
            layer=doc.layer if doc and doc.layer else (rec.layer or ""),
            description=description,
            inputs=inputs,
            outputs=outputs,
            params=params,
            examples=(
                (doc.examples if doc and doc.examples else [])
                + examples_by_id.get(lens_id, [])
            ),
        )


def build_task_desc(*, user_message: str, history_summary: str = "") -> str:
    """
    最小 task_desc 组装器：后续可扩展为更智能的摘要拼接策略。
    """
    if history_summary:
        return f"历史摘要：{history_summary}\n用户本轮：{user_message}"
    return user_message
