"""
MuseLens 核心数据结构 — 透镜协议 (Lens Protocol)

将 ComfyUI 的 JSON 工作流封装为支持动态参数注入的 Pydantic 模型。
核心思想：每个透镜 (Lens) 声明自己的 Inputs/Outputs 以及它们在 JSON 中的节点坐标 (NodeMapping)，
运行时通过 inject_inputs() 将外部参数精确写入对应节点字段，实现"透镜即对象"。
"""

import copy
from enum import Enum
from pydantic import BaseModel, Field


# ============================================================
# 枚举定义
# ============================================================

class LensLayer(str, Enum):
    """透镜所属的功能层级 (对应标准透镜库 v4.1 的五层架构)"""
    A1 = "A1"  # 视觉解析层 (Vision Parser)
    A2 = "A2"  # 像素修改与语义重构层 (Modifier & Reconstructor)
    A3 = "A3"  # 光影与物理渲染层 (Relighting Engine)
    A4 = "A4"  # 风格流形层 (Style Manifold)
    A5 = "A5"  # 保护与修复层 (Preservation & Upscale)


class InputType(str, Enum):
    """透镜输入的数据类型"""
    IMAGE = "image"  # 图片路径 — 注入到 LoadImage 节点的 image 字段
    TEXT = "text"    # 文本字符串 — 注入到 CLIPTextEncode 等节点的 text/prompt 字段


# ============================================================
# 节点映射 (NodeMapping)
# ============================================================

class NodeMapping(BaseModel):
    """
    记录一个输入/输出在 ComfyUI JSON 中的精确坐标。
    
    例如: node_id="1", field_name="image"
    表示该值需要写入 workflow["1"]["inputs"]["image"]
    """
    node_id: str = Field(..., description="ComfyUI JSON 中的节点 ID (字符串格式)")
    field_name: str = Field(..., description="该节点 inputs 下的字段名")


# ============================================================
# 透镜输入/输出定义
# ============================================================

class LensInput(BaseModel):
    """
    透镜的一个输入槽位。
    
    name: 语义化的输入名称 (如 "base_image", "prompt")，供外部传参时使用。
    type: 输入的数据类型，决定注入行为。
    mapping: 指向 JSON 中具体节点字段的坐标。
    """
    name: str = Field(..., description="输入参数的语义名称，如 'base_image'、'prompt'")
    type: InputType = Field(..., description="输入类型：image 或 text")
    mapping: NodeMapping = Field(..., description="对应的 ComfyUI JSON 节点坐标")


class LensOutput(BaseModel):
    """
    透镜的一个输出槽位。
    
    name: 语义化的输出名称 (如 "mask_result", "depth_map")。
    mapping: 指向 SaveImage 节点的坐标，用于运行后从 History API 提取结果文件名。
    """
    name: str = Field(..., description="输出资产的语义名称，如 'mask_result'")
    mapping: NodeMapping = Field(..., description="对应的 SaveImage 节点坐标")


# ============================================================
# 透镜模板 (LensTemplate) — 核心封装
# ============================================================

class LensTemplate(BaseModel):
    """
    完整的透镜定义，是注册表 (Registry) 中的基本单元。
    
    封装了原始 ComfyUI JSON 工作流及其输入输出的元信息。
    通过 inject_inputs() 方法实现参数的动态注入。
    """
    lens_id: str = Field(..., description="透镜的唯一标识符，如 'lens_sam2_matting'")
    layer: LensLayer = Field(..., description="所属的功能层级")
    description: str = Field(default="", description="透镜的功能描述")
    raw_workflow: dict = Field(..., description="原始的 ComfyUI JSON 工作流 (作为模板)")
    inputs: list[LensInput] = Field(default_factory=list, description="输入槽位列表")
    outputs: list[LensOutput] = Field(default_factory=list, description="输出槽位列表")

    def inject_inputs(self, params: dict[str, str]) -> dict:
        """
        将外部参数注入到工作流模板中，返回可直接提交给 ComfyUI 的完整 JSON。
        
        工作原理：
        1. 深拷贝 raw_workflow，避免污染模板原始数据。
        2. 遍历 self.inputs，如果 params 中包含对应的 name，
           就按 mapping 坐标将值写入 workflow[node_id]["inputs"][field_name]。
        
        Args:
            params: 键为 LensInput.name，值为实际参数 (文件路径或文本字符串)。
                    例如: {"base_image": "photo.png", "prompt": "a cat"}
        
        Returns:
            注入参数后的完整工作流 JSON (dict)，可直接提交 ComfyUI /prompt API。
        
        Raises:
            KeyError: 如果 params 中缺少必需的输入参数。
        """
        # 深拷贝，保护模板不被修改
        workflow = copy.deepcopy(self.raw_workflow)

        for inp in self.inputs:
            if inp.name not in params:
                raise KeyError(
                    f"透镜 '{self.lens_id}' 缺少必需的输入参数: '{inp.name}'"
                )
            
            # 按照映射坐标注入值
            node_id = inp.mapping.node_id
            field_name = inp.mapping.field_name
            workflow[node_id]["inputs"][field_name] = params[inp.name]

        return workflow
