"""
MuseLens 透镜注册表 (Lens Registry)

从本地 JSON 文件加载 ComfyUI 工作流，并硬编码创建 3 个 LensTemplate 实例。
此版本对应 Phase 2：数据流（Assets）与控制流（Params）彻底分离。
"""

import json
import os
from app.schemas.lens import (
    LensTemplate, LensLayer, LensAsset, LensParam,
    AssetType, ParamType, NodeMapping,
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
lens_sam2_matting = LensTemplate(
    lens_id="lens_sam2_matting",
    layer=LensLayer.A1,
    description="SAM2 语义抠图：根据文本 prompt 提取目标主体的遮罩 (Mask)",
    raw_workflow=_load_workflow("lens_sam2_matting .json"),
    inputs=[
        LensAsset(
            name="base_image",
            type=AssetType.IMAGE,
            mapping=NodeMapping(node_id="1", field_name="image"),
        ),
    ],
    outputs=[
        LensAsset(
            name="mask_result",
            type=AssetType.MASK,
            mapping=NodeMapping(node_id="14", field_name="images"),
        ),
    ],
    params=[
        LensParam(
            name="prompt",
            type=ParamType.TEXT,
            description="需要抠图的目标主体描述，例如 'a cat'",
            mapping=NodeMapping(node_id="8", field_name="prompt"),
        ),
    ]
)


# ----------------------------------------------------------
# 2. lens_depth_extract (A1 视觉解析层 — 深度图提取)
# ----------------------------------------------------------
lens_depth_extract = LensTemplate(
    lens_id="lens_depth_extract",
    layer=LensLayer.A1,
    description="DepthAnythingV2 深度图提取：生成画面的 3D 深度信息",
    raw_workflow=_load_workflow("lens_depth_extract.json"),
    inputs=[
        LensAsset(
            name="base_image",
            type=AssetType.IMAGE,
            mapping=NodeMapping(node_id="1", field_name="image"),
        ),
    ],
    outputs=[
        LensAsset(
            name="depth_map",
            type=AssetType.DEPTH_MAP,
            mapping=NodeMapping(node_id="3", field_name="images"),
        ),
    ],
    params=[]
)


# ----------------------------------------------------------
# 3. lens_inpaint_bg (A2 像素修改层 — 局部重绘/换背景)
# ----------------------------------------------------------
lens_inpaint_bg = LensTemplate(
    lens_id="lens_inpaint_bg",
    layer=LensLayer.A2,
    description="SDXL 局部重绘：基于遮罩对指定区域进行语义重构（如换背景）",
    raw_workflow=_load_workflow("lens_inpaint_bg.json"),
    inputs=[
        LensAsset(
            name="base_image",
            type=AssetType.IMAGE,
            mapping=NodeMapping(node_id="1", field_name="image"),
        ),
        LensAsset(
            name="mask_target",
            type=AssetType.MASK,
            mapping=NodeMapping(node_id="2", field_name="image"),
        ),
    ],
    outputs=[
        LensAsset(
            name="result_image",
            type=AssetType.IMAGE,
            mapping=NodeMapping(node_id="11", field_name="images"),
        ),
    ],
    params=[
        LensParam(
            name="positive_prompt",
            type=ParamType.TEXT,
            description="描述要重绘出来的内容，例如 'a beautiful beach, sunset'",
            mapping=NodeMapping(node_id="8", field_name="text"),
        ),
    ]
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
