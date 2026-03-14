"""
MuseLens 核心数据结构 — 透镜协议 (Lens Protocol) v2.0

将 ComfyUI 的 JSON 工作流封装为支持动态参数注入的 Pydantic 模型。
此版本实现重大解耦：分为数据流（Asset，决定拓扑）与控制流（Param，供调控）。
同时引入了声明式的 DAG 编排结构（DAGBlueprint 与 DAGStep）。
"""

from enum import Enum
from typing import Dict, Any, List
from pydantic import BaseModel, Field


# ============================================================
# 枚举定义
# ============================================================

class LensLayer(str, Enum):
    """透镜所属的功能层级"""
    A1 = "A1"  # 视觉解析层 (Vision Parser)
    A2 = "A2"  # 像素修改与语义重构层 (Modifier & Reconstructor)
    A3 = "A3"  # 光影与物理渲染层 (Relighting Engine)
    A4 = "A4"  # 风格流形层 (Style Manifold)
    A5 = "A5"  # 保护与修复层 (Preservation & Upscale)


class AssetType(str, Enum):
    """透镜资产的数据类型，决定连线拓扑"""
    IMAGE = "image"
    MASK = "mask"
    DEPTH_MAP = "depth_map"
    CONDITIONING = "conditioning"
    LATENT = "latent"


class ParamType(str, Enum):
    """透镜参数的数据类型，供大模型自由发挥"""
    TEXT = "text"
    FLOAT = "float"
    INT = "int"
    BOOLEAN = "boolean"


# ============================================================
# 节点映射 (NodeMapping)
# ============================================================

class NodeMapping(BaseModel):
    """
    记录一个输入/输出/参数在 ComfyUI JSON 中的精确坐标。
    
    例如: node_id="1", field_name="image"
    表示该值需要写入 workflow["1"]["inputs"]["image"]
    """
    node_id: str = Field(..., description="ComfyUI JSON 中的节点 ID (字符串格式)")
    field_name: str = Field(..., description="该节点 inputs 下的字段名")


# ============================================================
# 透镜资产与参数定义
# ============================================================

class LensAsset(BaseModel):
    """
    透镜的资产（数据流）插槽。
    例如图像、遮罩，决定了透镜之间的连线拓扑（硬连接）。
    """
    name: str = Field(..., description="资产的语义名称，如 'base_image', 'core_mask'")
    type: AssetType = Field(..., description="资产类型")
    mapping: NodeMapping = Field(..., description="对应的 ComfyUI JSON 节点坐标")


class LensParam(BaseModel):
    """
    透镜的参数（控制流）插槽。
    例如提示词、降噪强度等，供 LLM 动态调节。
    """
    name: str = Field(..., description="参数的语义名称，如 'prompt', 'denoise'")
    type: ParamType = Field(..., description="参数类型")
    description: str = Field(default="", description="参数功能和可调范围的文字描述，供 LLM 理解")
    mapping: NodeMapping = Field(..., description="对应的 ComfyUI JSON 节点坐标")


# ============================================================
# 透镜模板 (LensTemplate) — 纯声明式配置
# ============================================================

class LensTemplate(BaseModel):
    """
    完整的透镜定义，是注册表 (Registry) 中的基本单元。
    纯粹的声明式配置：分离了资产和参数，不再含有执行逻辑（如 inject_inputs 被移除了）。
    """
    lens_id: str = Field(..., description="透镜唯一标识符，如 'lens_sam2_matting'")
    layer: LensLayer = Field(..., description="所属的功能层级")
    description: str = Field(default="", description="透镜的功能描述")
    raw_workflow: dict = Field(..., description="原始的 ComfyUI JSON 工作流 (作为模板)")
    
    inputs: List[LensAsset] = Field(default_factory=list, description="所需的输入资产插槽")
    outputs: List[LensAsset] = Field(default_factory=list, description="产生的输出资产插槽")
    params: List[LensParam] = Field(default_factory=list, description="支持调节的控制参数插槽")


# ============================================================
# 动态 DAG 编排系统 (Execution Protocol)
# ============================================================

class DAGStep(BaseModel):
    """
    DAG管线中的单个执行步骤。
    定义了该步使用什么透镜，用什么资产依赖，配什么参数。
    """
    step_id: str = Field(..., description="步骤的自定义标识符，如 'step_1'")
    lens_id: str = Field(..., description="要执行的透镜模板 ID")
    input_links: Dict[str, str] = Field(
        default_factory=dict, 
        description="资产连线：键为 LensAsset 的 name，值为硬文件路径或以 $ 开头的变量引用 (如 '$step_1.core_mask')"
    )
    params: Dict[str, Any] = Field(
        default_factory=dict, 
        description="参数赋值：键为 LensParam 的 name，值为具体的调节值"
    )


class DAGBlueprint(BaseModel):
    """
    执行引擎接受的完整 DAG 蓝图。
    由 LLM 的 Agent 或是业务逻辑层根据用户的意图构建而成。
    """
    initial_inputs: Dict[str, str] = Field(
        default_factory=dict, 
        description="最初始的上下文资产字典：键为外源变量名，值为系统内的真实路径"
    )
    steps: List[DAGStep] = Field(
        default_factory=list,
        description="按拓扑排序排列的有序任务管线"
    )
