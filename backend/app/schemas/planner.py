from __future__ import annotations

from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

from app.schemas.lens import DAGBlueprint


class PlannerParamRef(BaseModel):
    lens_id: str
    param_name: str


class PlannerQuestion(BaseModel):
    param_ref: PlannerParamRef
    question_text: str
    options: List[str] = Field(default_factory=list)
    required: bool = True


class MissingParam(BaseModel):
    lens_id: str
    param_name: str
    reason: str = ""


class PlannerInput(BaseModel):
    task_desc: str
    base_image_meta: Dict[str, Any] = Field(default_factory=dict)
    candidates: List[Dict[str, Any]] = Field(
        default_factory=list,
        description="Retrieval 返回的候选 LensKnowledge 列表（结构化字典）",
    )
    session_context: Dict[str, Any] = Field(
        default_factory=dict,
        description="会话上下文：collected_params/pending_questions/lens_history 等",
    )


class PlannerOutput(BaseModel):
    blueprint: Optional[DAGBlueprint] = None
    missing_params: List[MissingParam] = Field(default_factory=list)
    clarification_questions: List[PlannerQuestion] = Field(default_factory=list)
    thought: str = ""

