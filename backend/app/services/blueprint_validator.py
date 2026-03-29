from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Set

from sqlalchemy.orm import Session

from app.lenses import registry
from app.models.lens_model import LensRecord
from app.schemas.lens import DAGBlueprint, ParamType


@dataclass
class ValidationError:
    code: str
    message: str


class BlueprintValidator:
    """
    对 Planner 产出的 DAGBlueprint 做静态校验。

    校验维度：
    - DAGStep 引用合法性（变量存在、step_id 唯一）
    - lens_id 存在且可加载（Catalog/Registry）
    - 参数名存在、类型基本匹配
    - 可选：必填参数（若 Catalog 中存在 required=true 标注）
    """

    def validate(
        self,
        db: Session,
        blueprint: DAGBlueprint,
        *,
        collected_params: Optional[Dict[str, Any]] = None,
    ) -> List[ValidationError]:
        errors: List[ValidationError] = []
        collected_params = collected_params or {}

        # 0) step_id 唯一
        seen: Set[str] = set()
        for s in blueprint.steps:
            if s.step_id in seen:
                errors.append(
                    ValidationError(
                        code="DUP_STEP_ID",
                        message=f"重复的 step_id: {s.step_id}",
                    )
                )
            seen.add(s.step_id)

        # 1) 资产引用校验
        available: Set[str] = set(blueprint.initial_inputs.keys())

        for step in blueprint.steps:
            # 1.1 lens_id 校验（Catalog存在 + Registry可加载）
            if not self._lens_exists(db, step.lens_id):
                errors.append(
                    ValidationError(
                        code="UNKNOWN_LENS",
                        message=f"步骤 {step.step_id} 引用了不存在的 lens_id '{step.lens_id}'",
                    )
                )
                # lens 不存在则无法进一步做该步的 params/outputs 校验
                continue

            tmpl = None
            try:
                tmpl = registry.get_lens(step.lens_id)
            except Exception as exc:
                errors.append(
                    ValidationError(
                        code="LENS_TEMPLATE_LOAD_FAILED",
                        message=f"无法加载 lens 模板 '{step.lens_id}': {exc}",
                    )
                )
                continue

            # 1.2 输入引用必须存在
            for slot_name, v in step.input_links.items():
                if not isinstance(v, str) or not v.startswith("$"):
                    continue
                key = v[1:]
                if key not in available:
                    errors.append(
                        ValidationError(
                            code="MISSING_ASSET_REF",
                            message=(
                                f"步骤 {step.step_id} 的输入槽位 '{slot_name}' "
                                f"引用了不存在的资产变量 '{key}'"
                            ),
                        )
                    )

            # 1.3 参数名/类型校验 + 必填校验
            errors.extend(
                self._validate_step_params(
                    db,
                    step_id=step.step_id,
                    lens_id=step.lens_id,
                    params=step.params,
                    collected_params=collected_params,
                    template_param_types={p.name: p.type for p in tmpl.params},
                )
            )

            # 1.4 将该 step 的 outputs 加入可用集合（step_id.output_name）
            for out in tmpl.outputs:
                available.add(f"{step.step_id}.{out.name}")

        return errors

    @staticmethod
    def _lens_exists(db: Session, lens_id: str) -> bool:
        return (
            db.query(LensRecord.lens_id)
            .filter(LensRecord.lens_id == lens_id)
            .first()
            is not None
        )

    @staticmethod
    def _load_required_params_from_catalog(db: Session, lens_id: str) -> Set[str]:
        rec = db.query(LensRecord).filter(LensRecord.lens_id == lens_id).first()
        if not rec:
            return set()
        raw_params = rec.params or []  # PostgreSQL JSONB 自动反序列化
        required = set()
        for p in raw_params:
            if p.get("required") is True:
                name = str(p.get("name", "")).strip()
                if name:
                    required.add(name)
        return required

    def _validate_step_params(
        self,
        db: Session,
        *,
        step_id: str,
        lens_id: str,
        params: Dict[str, Any],
        collected_params: Dict[str, Any],
        template_param_types: Dict[str, ParamType],
    ) -> List[ValidationError]:
        errors: List[ValidationError] = []

        # 参数名必须存在于模板 params
        for k in params.keys():
            if k not in template_param_types:
                errors.append(
                    ValidationError(
                        code="UNKNOWN_PARAM",
                        message=f"步骤 {step_id} 的参数 '{k}' 不存在于 lens '{lens_id}' 的 schema 中",
                    )
                )

        # 参数类型粗校验
        for k, v in params.items():
            ptype = template_param_types.get(k)
            if not ptype:
                continue
            if not self._value_matches_param_type(v, ptype):
                errors.append(
                    ValidationError(
                        code="PARAM_TYPE_MISMATCH",
                        message=f"步骤 {step_id} 参数 '{k}' 类型不匹配，期望 {ptype.value}",
                    )
                )

        # 必填参数校验（若 Catalog 标注了 required=true）
        required = self._load_required_params_from_catalog(db, lens_id)
        for name in required:
            key = f"{lens_id}.{name}"
            has_value = (name in params and params.get(name) not in [None, ""]) or (
                key in collected_params and collected_params.get(key) not in [None, ""]
            )
            if not has_value:
                errors.append(
                    ValidationError(
                        code="MISSING_REQUIRED_PARAM",
                        message=f"步骤 {step_id} 缺少必填参数 '{name}'（lens={lens_id}）",
                    )
                )

        return errors

    @staticmethod
    def _value_matches_param_type(value: Any, ptype: ParamType) -> bool:
        if value is None:
            return True
        if ptype == ParamType.TEXT:
            return isinstance(value, str)
        if ptype == ParamType.FLOAT:
            return isinstance(value, (int, float)) and not isinstance(value, bool)
        if ptype == ParamType.INT:
            return isinstance(value, int) and not isinstance(value, bool)
        if ptype == ParamType.BOOLEAN:
            return isinstance(value, bool)
        return True


blueprint_validator = BlueprintValidator()

