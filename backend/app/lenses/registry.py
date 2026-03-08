"""
MuseLens 透镜注册表 (Lens Registry)

从本地 JSON 文件加载 ComfyUI 工作流，并硬编码创建 3 个 LensTemplate 实例。
每个实例精确声明了自己的 Inputs/Outputs 及其在 JSON 中的节点映射坐标。

注册表充当全局的"透镜字典"，供 Compiler / Executor 按 lens_id 检索使用。
"""

import json
import os
from app.schemas.lens import (
    LensTemplate, LensLayer, LensInput, LensOutput,
    InputType, NodeMapping,
)


# ============================================================
# 工具函数：加载本地 JSON 工作流文件
# ============================================================

# lens JSON 文件所在目录 (backend/lens/)
_LENS_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "lens")


def _load_workflow(filename: str) -> dict:
    """读取一个 ComfyUI JSON 工作流文件并返回 dict"""
    filepath = os.path.join(_LENS_DIR, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)


# ============================================================
# 实例化 3 个 LensTemplate
# ============================================================

# ----------------------------------------------------------
# 1. lens_sam2_matting (A1 视觉解析层 — SAM2 语义抠图)
# ----------------------------------------------------------
# 节点映射:
#   Node 1  (LoadImage)                       <- base_image (输入)
#   Node 8  (GroundingDinoSAM2Segment)        <- prompt     (输入, text)
#   Node 14 (SaveImage, title=[OUTPUT] Mask)  -> mask_result (输出)
# ----------------------------------------------------------
lens_sam2_matting = LensTemplate(
    lens_id="lens_sam2_matting",
    layer=LensLayer.A1,
    description="SAM2 语义抠图：根据文本 prompt 提取目标主体的遮罩 (Mask)",
    raw_workflow=_load_workflow("lens_sam2_matting .json"),
    inputs=[
        LensInput(
            name="base_image",
            type=InputType.IMAGE,
            mapping=NodeMapping(node_id="1", field_name="image"),
        ),
        LensInput(
            name="prompt",
            type=InputType.TEXT,
            mapping=NodeMapping(node_id="8", field_name="prompt"),
        ),
    ],
    outputs=[
        LensOutput(
            name="mask_result",
            mapping=NodeMapping(node_id="14", field_name="images"),
        ),
    ],
)


# ----------------------------------------------------------
# 2. lens_depth_extract (A1 视觉解析层 — 深度图提取)
# ----------------------------------------------------------
# 节点映射:
#   Node 1 (LoadImage)                         <- base_image (输入)
#   Node 3 (SaveImage, title=[OUTPUT] Depth)   -> depth_map  (输出)
# ----------------------------------------------------------
lens_depth_extract = LensTemplate(
    lens_id="lens_depth_extract",
    layer=LensLayer.A1,
    description="DepthAnythingV2 深度图提取：生成画面的 3D 深度信息",
    raw_workflow=_load_workflow("lens_depth_extract.json"),
    inputs=[
        LensInput(
            name="base_image",
            type=InputType.IMAGE,
            mapping=NodeMapping(node_id="1", field_name="image"),
        ),
    ],
    outputs=[
        LensOutput(
            name="depth_map",
            mapping=NodeMapping(node_id="3", field_name="images"),
        ),
    ],
)


# ----------------------------------------------------------
# 3. lens_inpaint_bg (A2 像素修改层 — 局部重绘/换背景)
# ----------------------------------------------------------
# 节点映射:
#   Node 1  (LoadImage, title=[INPUT] Base_Image)     <- base_image      (输入)
#   Node 2  (LoadImage, title=[INPUT] Mask_Target)     <- mask_target     (输入)
#   Node 8  (CLIPTextEncode, title=[PARAM] Positive)   <- positive_prompt (输入, text)
#   Node 11 (SaveImage, title=[OUTPUT] Result_Image)   -> result_image    (输出)
# ----------------------------------------------------------
lens_inpaint_bg = LensTemplate(
    lens_id="lens_inpaint_bg",
    layer=LensLayer.A2,
    description="SDXL 局部重绘：基于遮罩对指定区域进行语义重构（如换背景）",
    raw_workflow=_load_workflow("lens_inpaint_bg.json"),
    inputs=[
        LensInput(
            name="base_image",
            type=InputType.IMAGE,
            mapping=NodeMapping(node_id="1", field_name="image"),
        ),
        LensInput(
            name="mask_target",
            type=InputType.IMAGE,
            mapping=NodeMapping(node_id="2", field_name="image"),
        ),
        LensInput(
            name="positive_prompt",
            type=InputType.TEXT,
            mapping=NodeMapping(node_id="8", field_name="text"),
        ),
    ],
    outputs=[
        LensOutput(
            name="result_image",
            mapping=NodeMapping(node_id="11", field_name="images"),
        ),
    ],
)


# ============================================================
# 全局注册表：lens_id -> LensTemplate
# ============================================================

LENS_REGISTRY: dict[str, LensTemplate] = {
    lens_sam2_matting.lens_id: lens_sam2_matting,
    lens_depth_extract.lens_id: lens_depth_extract,
    lens_inpaint_bg.lens_id: lens_inpaint_bg,
}


def get_lens(lens_id: str) -> LensTemplate:
    """根据 lens_id 从注册表中检索透镜，找不到则抛出 KeyError"""
    if lens_id not in LENS_REGISTRY:
        raise KeyError(f"透镜 '{lens_id}' 未在注册表中找到。可用: {list(LENS_REGISTRY.keys())}")
    return LENS_REGISTRY[lens_id]
