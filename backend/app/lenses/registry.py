"""
MuseLens 透镜注册表 (Lens Registry) — 数据库驱动版

注册表依赖 SQLite 数据库（通过 SQLAlchemy），而不再扫描本地配置文件目录。

设计要点：
  - 数据库只存储 Lens 元数据与工作流文件路径，不存工作流 JSON 内容。
  - 启动时调用 reload_registry() 从数据库构建内存注册表 LENS_REGISTRY。
  - 所有写操作（注册/注销）先写数据库，再同步更新内存注册表，保持一致。
  - get_lens() 始终从内存注册表读取，保证零 I/O 延迟。

对外暴露的接口：
  LENS_REGISTRY           — 全局注册表字典 { lens_id: LensTemplate }
  get_lens(lens_id)       — 按 ID 检索透镜（不存在则 KeyError）
  reload_registry(db)     — 从数据库全量重新加载注册表
  register_lens(db, data) — 注册新透镜（写 DB + 更新内存）
  unregister_lens(db, id) — 注销透镜（删 DB + 更新内存）
"""

from __future__ import annotations

import json
import os
from copy import deepcopy
from typing import Dict, Any, List

from sqlalchemy.orm import Session

from app.schemas.lens import (
    LensTemplate, LensLayer, LensAsset, LensParam,
    AssetType, ParamType, NodeMapping,
)
from app.models.lens_model import LensRecord


# ============================================================
# 工作流文件路径解析
# ============================================================

# 默认工作流目录：backend/lens/（相对本文件向上三级）
_DEFAULT_LENS_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "..", "..", "lens")
)


def _resolve_workflow_path(workflow_file_path: str) -> str:
    """
    将数据库中存储的 workflow_file_path 解析为可读取的绝对路径。

    解析规则：
      1. 若是绝对路径且文件存在 → 直接使用。
      2. 若是相对路径/仅文件名 → 拼接到 backend/lens/ 目录下查找。
      3. 均不存在 → 抛出 FileNotFoundError。
    """
    if os.path.isabs(workflow_file_path) and os.path.isfile(workflow_file_path):
        return workflow_file_path

    fallback = os.path.join(_DEFAULT_LENS_DIR, workflow_file_path)
    if os.path.isfile(fallback):
        return fallback

    raise FileNotFoundError(
        f"工作流文件未找到：'{workflow_file_path}'。\n"
        f"尝试的路径：\n  1. {workflow_file_path}\n  2. {fallback}"
    )


def _load_workflow(workflow_file_path: str) -> dict:
    """从磁盘读取工作流 JSON，返回 dict。"""
    path = _resolve_workflow_path(workflow_file_path)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


# ============================================================
# LensRecord → LensTemplate 转换
# ============================================================

def _build_assets(items: List[Dict[str, Any]]) -> List[LensAsset]:
    result: List[LensAsset] = []
    for item in items:
        mapping_data = item["mapping"]
        asset = LensAsset(
            name=item["name"],
            type=AssetType(item["type"]),
            mapping=NodeMapping(
                node_id=str(mapping_data["node_id"]),
                field_name=str(mapping_data["field_name"]),
            ),
        )
        result.append(asset)
    return result


def _build_params(items: List[Dict[str, Any]]) -> List[LensParam]:
    result: List[LensParam] = []
    for item in items:
        mapping_data = item["mapping"]
        param = LensParam(
            name=item["name"],
            type=ParamType(item["type"]),
            description=item.get("description", ""),
            mapping=NodeMapping(
                node_id=str(mapping_data["node_id"]),
                field_name=str(mapping_data["field_name"]),
            ),
        )
        result.append(param)
    return result


def _record_to_template(record: LensRecord) -> LensTemplate:
    """将数据库行（LensRecord）转换为内存中的 LensTemplate 对象。"""
    raw_workflow = _load_workflow(record.workflow_file_path)
    inputs = _build_assets(json.loads(record.inputs_json or "[]"))
    outputs = _build_assets(json.loads(record.outputs_json or "[]"))
    params = _build_params(json.loads(record.params_json or "[]"))

    return LensTemplate(
        lens_id=record.lens_id,
        layer=LensLayer(record.layer),
        description=record.description or "",
        raw_workflow=raw_workflow,
        inputs=inputs,
        outputs=outputs,
        params=params,
    )


# ============================================================
# 全局内存注册表
# ============================================================

LENS_REGISTRY: Dict[str, LensTemplate] = {}


# ============================================================
# 对外接口
# ============================================================

def get_lens(lens_id: str) -> LensTemplate:
    """
    按 lens_id 从内存注册表检索透镜。
    找不到则抛出 KeyError，并在错误信息中列出可用列表。
    """
    if lens_id not in LENS_REGISTRY:
        available = list(LENS_REGISTRY.keys())
        raise KeyError(
            f"透镜 '{lens_id}' 未在注册表中找到。\n"
            f"当前可用透镜（共 {len(available)} 个）：{available}"
        )
    return LENS_REGISTRY[lens_id]


def reload_registry(db: Session) -> Dict[str, LensTemplate]:
    """
    从数据库全量重新加载注册表，替换当前内存中的 LENS_REGISTRY。
    在 FastAPI 启动时调用一次；也可在运行时动态调用以刷新。

    返回新注册表的副本（便于调用方检查结果）。
    """
    global LENS_REGISTRY

    records = db.query(LensRecord).all()
    new_registry: Dict[str, LensTemplate] = {}

    for rec in records:
        try:
            template = _record_to_template(rec)
            new_registry[template.lens_id] = template
        except Exception as exc:
            # 单个 Lens 加载失败不应阻断整个注册表初始化
            print(f"[Registry] 警告：加载透镜 '{rec.lens_id}' 时出错，已跳过。原因：{exc}")

    LENS_REGISTRY = new_registry
    print(f"[Registry] 注册表已从数据库加载，共 {len(LENS_REGISTRY)} 个透镜：{list(LENS_REGISTRY.keys())}")
    return deepcopy(LENS_REGISTRY)


def register_lens(db: Session, data: Dict[str, Any]) -> LensTemplate:
    """
    注册一个新透镜（或覆盖已有透镜）。

    参数 data 的结构与 .lens.json 配置文件一致：
      {
        "lens_id": str,
        "layer": "A1" | "A2" | ... | "A5",
        "description": str,
        "workflow_file_path": str,   # 绝对路径或 backend/lens/ 下的文件名
        "inputs": [...],
        "outputs": [...],
        "params": [...],
      }

    操作步骤：
      1. 验证工作流文件可读。
      2. 写入（或更新）数据库行。
      3. 将对应的 LensTemplate 写入内存注册表。
      4. 返回新建的 LensTemplate。
    """
    lens_id = data["lens_id"]
    workflow_file_path = data["workflow_file_path"]

    # 提前验证工作流文件存在（快速失败）
    _resolve_workflow_path(workflow_file_path)

    inputs_json = json.dumps(data.get("inputs", []), ensure_ascii=False)
    outputs_json = json.dumps(data.get("outputs", []), ensure_ascii=False)
    params_json = json.dumps(data.get("params", []), ensure_ascii=False)

    existing = db.query(LensRecord).filter(LensRecord.lens_id == lens_id).first()

    if existing:
        # 更新已有记录
        existing.layer = data["layer"]
        existing.description = data.get("description", "")
        existing.workflow_file_path = workflow_file_path
        existing.inputs_json = inputs_json
        existing.outputs_json = outputs_json
        existing.params_json = params_json
        record = existing
    else:
        # 新建记录
        record = LensRecord(
            lens_id=lens_id,
            layer=data["layer"],
            description=data.get("description", ""),
            workflow_file_path=workflow_file_path,
            inputs_json=inputs_json,
            outputs_json=outputs_json,
            params_json=params_json,
        )
        db.add(record)

    db.commit()
    db.refresh(record)

    # 同步更新内存注册表
    template = _record_to_template(record)
    LENS_REGISTRY[lens_id] = template
    print(f"[Registry] 透镜 '{lens_id}' 已注册（{'更新' if existing else '新建'}）。")
    return template


def unregister_lens(db: Session, lens_id: str) -> bool:
    """
    注销透镜：从数据库删除，并从内存注册表移除。

    返回 True 表示成功注销，False 表示该透镜本不存在。
    """
    record = db.query(LensRecord).filter(LensRecord.lens_id == lens_id).first()
    if not record:
        return False

    db.delete(record)
    db.commit()

    LENS_REGISTRY.pop(lens_id, None)
    print(f"[Registry] 透镜 '{lens_id}' 已注销。")
    return True
