from __future__ import annotations

from typing import Any, Dict, List

from pydantic import BaseModel, Field


class LensExample(BaseModel):
    nl_desc: str = Field(default="", description="自然语言示例描述")
    params_example: Dict[str, Any] = Field(
        default_factory=dict, description="对应的参数示例（JSON）"
    )


class LensParamSchema(BaseModel):
    name: str
    type: str
    description: str = ""
    required: bool = False
    default: Any = None


class LensAssetSchema(BaseModel):
    name: str
    type: str
    description: str = ""


class LensKnowledge(BaseModel):
    lens_id: str
    score: float = 0.0
    layer: str = ""
    description: str = ""
    inputs: List[LensAssetSchema] = Field(default_factory=list)
    outputs: List[LensAssetSchema] = Field(default_factory=list)
    params: List[LensParamSchema] = Field(default_factory=list)
    examples: List[LensExample] = Field(default_factory=list)

