from enum import Enum
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

from app.schemas.lens import DAGBlueprint


class QuestionType(str, Enum):
    """前端可渲染的追问类型。"""

    SINGLE_CHOICE = "single_choice"
    MULTI_CHOICE = "multi_choice"
    SLIDER = "slider"
    TEXT = "text"


class QuestionBindTarget(str, Enum):
    """追问答案要绑定到哪种目标。"""

    PARAM = "param"  # 绑定到 DAGStep.params
    META = "meta"  # 仅参与推理，不直接写入 DAG


class QuestionBind(BaseModel):
    """
    描述一个问题的答案应如何回填到编排计划中。
    """

    step_id: Optional[str] = Field(
        default=None, description="绑定的步骤 ID（可为空，表示全局元信息）"
    )
    lens_id: Optional[str] = Field(
        default=None, description="绑定的透镜 ID（可为空，仅作提示）"
    )
    target: QuestionBindTarget = Field(
        ..., description="答案回填目标类型（参数或元信息）"
    )
    name: str = Field(..., description="目标名称，例如参数名 prompt / positive_prompt")


class ClarifyUiSchema(BaseModel):
    """
    问题的取值范围/约束信息，帮助前端渲染合适控件。
    """

    min: Optional[float] = Field(default=None, description="数值类问题的最小值")
    max: Optional[float] = Field(default=None, description="数值类问题的最大值")
    step: Optional[float] = Field(default=None, description="滑条步进")
    default: Optional[Any] = Field(default=None, description="默认值")
    allow_custom_text: bool = Field(
        default=False, description="是否允许用户输入自定义文本"
    )


class ClarifyQuestion(BaseModel):
    """
    Router 产生的一条追问，用以补齐关键信息或解除歧义。
    """

    id: str = Field(..., description="问题唯一 ID，用于回填答案")
    prompt: str = Field(..., description="展示给用户的问题文案")
    type: QuestionType = Field(..., description="问题类型")
    options: List[str] = Field(
        default_factory=list, description="可选项列表（用于单选/多选）"
    )
    required: bool = Field(default=True, description="是否必答")
    binds: List[QuestionBind] = Field(
        default_factory=list, description="该问题答案绑定到哪些编排槽位"
    )
    ui_schema: ClarifyUiSchema = Field(
        default_factory=ClarifyUiSchema, description="取值约束信息（用于前端渲染控件）"
    )


class RouterStatus(str, Enum):
    """Router 当前状态，用于指导前端/上层逻辑。"""

    NEED_CLARIFICATION = "need_clarification"
    READY = "ready"
    FAILED = "failed"


class RouterResponse(BaseModel):
    """
    Router 对一次编译请求的统一返回结构。
    """

    session_id: str = Field(..., description="当前会话 ID")
    status: RouterStatus = Field(..., description="路由状态")
    thought_process: str = Field(
        default="", description="路由器的内部推理过程，便于调试和可解释性"
    )
    questions: List[ClarifyQuestion] = Field(
        default_factory=list, description="当状态为 need_clarification 时的追问列表"
    )
    blueprint: Optional[DAGBlueprint] = Field(
        default=None, description="当状态为 ready 时可执行的 DAG 蓝图"
    )
    extra: Dict[str, Any] = Field(
        default_factory=dict, description="预留扩展字段，例如召回的透镜列表等"
    )


class RouterCompileRequest(BaseModel):
    """
    触发一次路由编译或追问的请求体。

    如果 session_id 为空则代表新会话；否则在既有会话上继续（通常不需要 user_prompt）。
    """

    user_id: str = Field(..., description="当前用户 ID")
    user_prompt: Optional[str] = Field(
        default=None, description="用户的自然语言指令（新会话时必填）"
    )
    base_image: Optional[str] = Field(
        default=None,
        description="源图像资产名，通常为 ComfyUI input 目录中的文件名，如 'upload_raw.png'",
    )
    session_id: Optional[str] = Field(
        default=None, description="复用的会话 ID（可选）"
    )


class RouterAnswerRequest(BaseModel):
    """
    前端提交追问答案时使用的请求体。
    """

    session_id: str = Field(..., description="要继续的会话 ID")
    answers: Dict[str, Any] = Field(
        default_factory=dict, description="问题 ID -> 用户答案 的映射"
    )


# ============================================================
# Router v2：统一入口（兼容迁移）
# ============================================================


class RouterRouteRequest(BaseModel):
    """
    统一路由入口请求体：
    - 若提供 answers：视为回答追问（等价于 /answer）
    - 否则视为编译/追问（等价于 /compile_or_ask），使用 user_message/base_image

    说明：
    - 后续引入 Planner/Retrieval/会话持久化后，该结构会扩展为更完整的 session/context 输入。
    """

    user_id: str = Field(default="", description="当前用户 ID（兼容旧端点转发时可为空）")
    session_id: Optional[str] = Field(default=None, description="复用的会话 ID（可选）")

    user_message: Optional[str] = Field(
        default=None, description="用户本轮自然语言输入（新会话时通常必填）"
    )
    base_image: Optional[str] = Field(
        default=None,
        description="源图像资产名，通常为 ComfyUI input 目录中的文件名，如 'upload_raw.png'",
    )
    base_image_meta: Dict[str, Any] = Field(
        default_factory=dict, description="可选：base_image 的元信息（尺寸、来源等）"
    )

    answers: Dict[str, Any] = Field(
        default_factory=dict,
        description="若本轮是回答追问，则填入：问题ID->答案。非空时将走 answer 流程。",
    )

