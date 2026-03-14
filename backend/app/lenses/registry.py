"""
MuseLens 透镜注册表 (Lens Registry)

通过「配置文件 + ComfyUI JSON 模板」自动加载 LensTemplate，实现数据与代码分离。
"""

import json
import os
from glob import glob
from typing import Dict

from app.schemas.lens import (
    LensTemplate, LensLayer, LensAsset, LensParam,
    AssetType, ParamType, NodeMapping,
)


# ============================================================
# 路径约定
# ============================================================

# ComfyUI 工作流 JSON 所在目录 (backend/lens/)
_LENS_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "lens")

# Lens 配置文件所在目录 (backend/app/lenses/config/)
_LENS_CONFIG_DIR = os.path.join(os.path.dirname(__file__), "config")


def _load_workflow(filename: str) -> dict:
    """读取一个 ComfyUI JSON 工作流文件并返回 dict"""
    filepath = os.path.join(_LENS_DIR, filename)
    with open(filepath, "r", encoding="utf-8") as f:
        return json.load(f)


def _load_lens_from_config(config_path: str) -> LensTemplate:
    """
    根据单个 Lens 配置文件 (.lens.json) 构建 LensTemplate 实例。
    配置格式详见文档《Lens 规范文档 + 新建 Lens checklist》。
    """
    with open(config_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    lens_id = data["lens_id"]
    layer = LensLayer(data["layer"])
    description = data.get("description", "")
    workflow_file = data["workflow_file"]

    raw_workflow = _load_workflow(workflow_file)

    def _build_assets(items, is_input: bool) -> list[LensAsset]:
        result: list[LensAsset] = []
        for item in items or []:
            mapping_data = item["mapping"]
            mapping = NodeMapping(
                node_id=str(mapping_data["node_id"]),
                field_name=str(mapping_data["field_name"]),
            )
            asset = LensAsset(
                name=item["name"],
                type=AssetType(item["type"]),
                mapping=mapping,
            )
            result.append(asset)
        return result

    def _build_params(items) -> list[LensParam]:
        result: list[LensParam] = []
        for item in items or []:
            mapping_data = item["mapping"]
            mapping = NodeMapping(
                node_id=str(mapping_data["node_id"]),
                field_name=str(mapping_data["field_name"]),
            )
            param = LensParam(
                name=item["name"],
                type=ParamType(item["type"]),
                description=item.get("description", ""),
                mapping=mapping,
            )
            result.append(param)
        return result

    inputs = _build_assets(data.get("inputs", []), is_input=True)
    outputs = _build_assets(data.get("outputs", []), is_input=False)
    params = _build_params(data.get("params", []))

    return LensTemplate(
        lens_id=lens_id,
        layer=layer,
        description=description,
        raw_workflow=raw_workflow,
        inputs=inputs,
        outputs=outputs,
        params=params,
    )


def _build_registry() -> Dict[str, LensTemplate]:
    """
    从配置目录自动扫描 .lens.json 配置，构建全局 LENS_REGISTRY。
    """
    registry: Dict[str, LensTemplate] = {}

    # 若目录不存在，则保持空注册表，避免导入时报错
    if not os.path.isdir(_LENS_CONFIG_DIR):
        return registry

    pattern = os.path.join(_LENS_CONFIG_DIR, "*.lens.json")
    for config_path in glob(pattern):
        lens = _load_lens_from_config(config_path)
        if lens.lens_id in registry:
            raise ValueError(
                f"重复的 lens_id '{lens.lens_id}'，配置文件冲突。请确保每个 lens_id 只在一个配置中定义。"
            )
        registry[lens.lens_id] = lens

    return registry


# ============================================================
# 全局注册表：lens_id -> LensTemplate
# ============================================================

LENS_REGISTRY: Dict[str, LensTemplate] = _build_registry()


def get_lens(lens_id: str) -> LensTemplate:
    """根据 lens_id 从注册表中检索透镜，找不到则抛出 KeyError"""
    if lens_id not in LENS_REGISTRY:
        raise KeyError(f"透镜 '{lens_id}' 未在注册表中找到。可用: {list(LENS_REGISTRY.keys())}")
    return LENS_REGISTRY[lens_id]

