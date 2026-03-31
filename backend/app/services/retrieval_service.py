from __future__ import annotations

from typing import Dict, List, Optional, Set, Tuple

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
        available_user_assets: Optional[Dict[str, str]] = None,
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

        result = self._expand_dependency_candidates(
            db,
            seeds=result,
            examples_by_id=examples_by_id,
            enabled_only=enabled_only,
            available_user_assets=available_user_assets,
        )
        result = self._inject_semantic_chain_candidates(
            db,
            items=result,
            task_desc=task_desc,
            examples_by_id=examples_by_id,
        )
        return self._rerank_by_available_user_assets(
            result,
            available_user_assets=available_user_assets,
        )

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
            notes = str(doc.body or "")
        else:
            description = rec.description or ""
            notes = ""

        return LensKnowledge(
            lens_id=lens_id,
            score=score,
            layer=doc.layer if doc and doc.layer else (rec.layer or ""),
            description=description,
            notes=notes,
            inputs=inputs,
            outputs=outputs,
            params=params,
            examples=(
                (doc.examples if doc and doc.examples else [])
                + examples_by_id.get(lens_id, [])
            ),
        )

    def _expand_dependency_candidates(
        self,
        db: Session,
        *,
        seeds: List[LensKnowledge],
        examples_by_id: Dict[str, List[LensExample]],
        enabled_only: bool = False,
        available_user_assets: Optional[Dict[str, str]] = None,
        max_depth: int = 2,
        max_matches_per_input: int = 3,
    ) -> List[LensKnowledge]:
        if not seeds:
            return []

        records: List[LensRecord] = db.query(LensRecord).all()
        record_by_id = {r.lens_id: r for r in records}
        known_ids: Set[str] = {item.lens_id for item in seeds}
        ordered: List[LensKnowledge] = list(seeds)
        frontier: List[LensKnowledge] = list(seeds)

        for depth in range(max_depth):
            if not frontier:
                break

            next_frontier: List[LensKnowledge] = []
            for cand in frontier:
                for dep_id in self._find_dependency_lens_ids(
                    cand,
                    records,
                    exclude_ids=known_ids,
                    limit=max_matches_per_input,
                    available_user_assets=available_user_assets,
                ):
                    rec = record_by_id.get(dep_id)
                    if not rec:
                        continue
                    lk = self._lens_knowledge_from_record(
                        lens_id=dep_id,
                        score=max(cand.score - 0.01 * (depth + 1), 0.0),
                        rec=rec,
                        examples_by_id=examples_by_id,
                    )
                    if not lk:
                        continue
                    known_ids.add(dep_id)
                    ordered.append(lk)
                    next_frontier.append(lk)

            frontier = next_frontier

        return ordered

    def _find_dependency_lens_ids(
        self,
        candidate: LensKnowledge,
        records: List[LensRecord],
        *,
        exclude_ids: Set[str],
        limit: int,
        available_user_assets: Optional[Dict[str, str]] = None,
    ) -> List[str]:
        found: List[str] = []
        seen: Set[str] = set()

        for input_asset in candidate.inputs or []:
            if self._matches_available_user_asset(
                input_name=input_asset.name,
                input_type=input_asset.type,
                available_user_assets=available_user_assets,
            ):
                continue
            if self._is_user_supplied_input(input_asset.name, input_asset.type):
                continue

            matches: List[Tuple[int, str]] = []
            for rec in records:
                if rec.lens_id in exclude_ids or rec.lens_id == candidate.lens_id:
                    continue
                score = self._dependency_match_score(
                    input_name=input_asset.name,
                    input_type=input_asset.type,
                    outputs=rec.outputs or [],
                )
                if score > 0:
                    matches.append((score, rec.lens_id))

            matches.sort(key=lambda item: (-item[0], item[1]))
            for _, dep_id in matches[:limit]:
                if dep_id not in seen:
                    seen.add(dep_id)
                    found.append(dep_id)

        return found

    @staticmethod
    def _is_user_supplied_input(name: str, asset_type: str) -> bool:
        kind = RetrievalService._asset_kind(name, asset_type)
        lname = (name or "").strip().lower()
        return kind == "base_image" or lname == "style_reference_image"

    @staticmethod
    def _dependency_match_score(
        *,
        input_name: str,
        input_type: str,
        outputs: List[Dict],
    ) -> int:
        input_kind = RetrievalService._asset_kind(input_name, input_type)
        if input_kind == "generic_image":
            return 0

        best = 0
        for out in outputs or []:
            output_name = str(out.get("name", ""))
            output_type = str(out.get("type", ""))
            output_kind = RetrievalService._asset_kind(output_name, output_type)

            if output_name == input_name:
                best = max(best, 4)
            if output_kind and output_kind == input_kind:
                best = max(best, 3)
            if input_kind == "generic_reference":
                if output_kind in {"pose", "depth", "canny"}:
                    best = max(best, 4)
                elif output_kind in {"style_reference", "generic_image"}:
                    best = max(best, 2)
            if input_kind == "style_reference":
                if output_kind == "style_reference":
                    best = max(best, 4)
                elif output_kind == "generic_image":
                    best = max(best, 2)
            if input_kind == "mask" and output_name.endswith("_result") and output_kind == "mask":
                best = max(best, 2)

        return best

    @classmethod
    def _rerank_by_available_user_assets(
        cls,
        items: List[LensKnowledge],
        *,
        available_user_assets: Optional[Dict[str, str]] = None,
    ) -> List[LensKnowledge]:
        if not items or not available_user_assets:
            return items

        rescored: List[Tuple[float, LensKnowledge]] = []
        for item in items:
            adjusted_score = float(item.score) + cls._available_asset_adjustment(
                item,
                available_user_assets=available_user_assets,
            )
            rescored.append((adjusted_score, item.model_copy(update={"score": adjusted_score})))

        rescored.sort(key=lambda pair: (-pair[0], pair[1].lens_id))
        return [item for _, item in rescored]

    @classmethod
    def _available_asset_adjustment(
        cls,
        item: LensKnowledge,
        *,
        available_user_assets: Dict[str, str],
    ) -> float:
        adjustment = 0.0

        for input_asset in item.inputs or []:
            if cls._matches_available_user_asset(
                input_name=input_asset.name,
                input_type=input_asset.type,
                available_user_assets=available_user_assets,
            ):
                kind = cls._asset_kind(input_asset.name, input_asset.type)
                if kind == "mask":
                    adjustment += 3.0
                elif kind in {"style_reference", "generic_reference"}:
                    adjustment += 2.0
                else:
                    adjustment += 1.0

        for output_asset in item.outputs or []:
            if cls._matches_available_user_asset(
                input_name=output_asset.name,
                input_type=output_asset.type,
                available_user_assets=available_user_assets,
            ):
                kind = cls._asset_kind(output_asset.name, output_asset.type)
                if kind == "mask":
                    adjustment -= 2.5
                elif kind in {"style_reference", "generic_reference"}:
                    adjustment -= 1.5
                else:
                    adjustment -= 0.5

        return adjustment

    @classmethod
    def _matches_available_user_asset(
        cls,
        *,
        input_name: str,
        input_type: str,
        available_user_assets: Optional[Dict[str, str]] = None,
    ) -> bool:
        if not available_user_assets:
            return False

        normalized_assets = {
            str(k).strip(): str(v)
            for k, v in (available_user_assets or {}).items()
            if str(k).strip() and v not in [None, ""]
        }
        if input_name in normalized_assets:
            return True

        target_kind = cls._asset_kind(input_name, input_type)
        aliases_by_kind = {
            "mask": {"mask", "user_mask", "painted_mask", "mask_result"},
            "style_reference": {"style_reference_image", "style_image", "reference_style_image"},
            "generic_reference": {"ref_image_1", "reference_image", "reference_asset"},
        }
        return bool(aliases_by_kind.get(target_kind, set()) & set(normalized_assets.keys()))

    def _inject_semantic_chain_candidates(
        self,
        db: Session,
        *,
        items: List[LensKnowledge],
        task_desc: str,
        examples_by_id: Dict[str, List[LensExample]],
    ) -> List[LensKnowledge]:
        wanted_ids = self._wanted_lens_ids_for_task(task_desc)
        if not wanted_ids:
            return items

        existing_ids = {item.lens_id for item in items}
        missing_ids = [lens_id for lens_id in wanted_ids if lens_id not in existing_ids]
        if not missing_ids:
            return items

        records: List[LensRecord] = (
            db.query(LensRecord).filter(LensRecord.lens_id.in_(missing_ids)).all()
        )
        record_by_id = {record.lens_id: record for record in records}

        boosted: List[LensKnowledge] = list(items)
        base_score = max((float(item.score) for item in items), default=0.5)
        for idx, lens_id in enumerate(missing_ids):
            record = record_by_id.get(lens_id)
            if not record:
                continue
            lk = self._lens_knowledge_from_record(
                lens_id=lens_id,
                score=base_score + 0.25 - idx * 0.01,
                rec=record,
                examples_by_id=examples_by_id,
            )
            if lk:
                boosted.append(lk)

        return boosted

    @staticmethod
    def _wanted_lens_ids_for_task(task_desc: str) -> List[str]:
        text = task_desc or ""
        wanted: List[str] = []

        if RetrievalService._looks_like_scene_preserving_task(text):
            wanted.extend(["lens_flux_reference", "lens_pose_extract"])

        if RetrievalService._looks_like_relighting_task(text):
            wanted.extend(["lens_relighting", "lens_depth_extract"])

        if RetrievalService._looks_like_delivery_task(text):
            wanted.append("lens_upscale_4x")

        deduped: List[str] = []
        seen: Set[str] = set()
        for lens_id in wanted:
            if lens_id not in seen:
                seen.add(lens_id)
                deduped.append(lens_id)
        return deduped

    @staticmethod
    def _looks_like_scene_preserving_task(task_desc: str) -> bool:
        text = task_desc or ""
        preserve_markers = ["保持", "保留", "姿势", "姿态", "构图", "主体"]
        scene_markers = ["背景", "场景", "环境", "海边", "沙滩", "森林", "街道", "房间"]
        return any(k in text for k in preserve_markers) and any(k in text for k in scene_markers)

    @staticmethod
    def _looks_like_relighting_task(task_desc: str) -> bool:
        keywords = ["光", "光影", "黄昏", "傍晚", "照下", "打光", "柔和"]
        return any(k in (task_desc or "") for k in keywords)

    @staticmethod
    def _looks_like_delivery_task(task_desc: str) -> bool:
        keywords = ["放大", "超分", "高清", "清晰", "高质量", "画质要好", "画质更好"]
        return any(k in (task_desc or "") for k in keywords)

    @staticmethod
    def _asset_kind(name: str, asset_type: str) -> str:
        tokens = f"{name} {asset_type}".lower()
        if "base_image" in tokens:
            return "base_image"
        if "mask" in tokens:
            return "mask"
        if "depth" in tokens:
            return "depth"
        if "canny" in tokens or "edge" in tokens:
            return "canny"
        if "pose" in tokens or "skeleton" in tokens:
            return "pose"
        if "style_reference" in tokens:
            return "style_reference"
        if "ref_image" in tokens:
            return "generic_reference"
        if "image" in tokens:
            return "generic_image"
        return tokens.strip()


def build_task_desc(*, user_message: str, history_summary: str = "") -> str:
    """
    最小 task_desc 组装器：后续可扩展为更智能的摘要拼接策略。
    """
    if history_summary:
        return f"历史摘要：{history_summary}\n用户本轮：{user_message}"
    return user_message
