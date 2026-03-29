"""Database-backed lens registry with builtin bootstrap helpers."""

from __future__ import annotations

import json
from copy import deepcopy
from pathlib import Path
from typing import Any, Dict, Iterable, List

from sqlalchemy.orm import Session

from app.models.lens_model import LensRecord
from app.schemas.lens import (
    AssetType,
    LensAsset,
    LensLayer,
    LensParam,
    LensTemplate,
    NodeMapping,
    ParamType,
)


_LENSES_DIR = Path(__file__).resolve().parents[2] / "lens"
_LENS_CONFIG_DIR = Path(__file__).resolve().parent / "config"


def _iter_builtin_config_files(config_dir: Path | str | None = None) -> Iterable[Path]:
    cfg_dir = Path(config_dir) if config_dir is not None else _LENS_CONFIG_DIR
    if not cfg_dir.exists():
        return []
    return sorted(cfg_dir.glob("*.lens.json"))


def _resolve_workflow_path(workflow_file_path: str) -> str:
    path = Path(workflow_file_path)
    if path.is_file():
        return str(path.resolve())

    fallback = (_LENSES_DIR / workflow_file_path).resolve()
    if fallback.is_file():
        return str(fallback)

    raise FileNotFoundError(
        "工作流文件未找到："
        f"{workflow_file_path}\n尝试的路径：\n  1. {path}\n  2. {fallback}"
    )


def _load_workflow(workflow_file_path: str) -> dict:
    path = Path(_resolve_workflow_path(workflow_file_path))
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def _build_assets(items: List[Dict[str, Any]]) -> List[LensAsset]:
    result: List[LensAsset] = []
    for item in items or []:
        mapping_data = item["mapping"]
        result.append(
            LensAsset(
                name=str(item["name"]),
                type=AssetType(str(item["type"])),
                mapping=NodeMapping(
                    node_id=str(mapping_data["node_id"]),
                    field_name=str(mapping_data["field_name"]),
                ),
            )
        )
    return result


def _build_params(items: List[Dict[str, Any]]) -> List[LensParam]:
    result: List[LensParam] = []
    for item in items or []:
        mapping_data = item["mapping"]
        result.append(
            LensParam(
                name=str(item["name"]),
                type=ParamType(str(item["type"])),
                description=str(item.get("description", "")),
                mapping=NodeMapping(
                    node_id=str(mapping_data["node_id"]),
                    field_name=str(mapping_data["field_name"]),
                ),
            )
        )
    return result


def _config_to_data(cfg: Dict[str, Any]) -> Dict[str, Any]:
    workflow_file_path = cfg.get("workflow_file_path") or cfg.get("workflow_file")
    if not workflow_file_path:
        raise ValueError("Lens 配置缺少 workflow_file_path/workflow_file")

    return {
        "lens_id": str(cfg["lens_id"]),
        "layer": str(cfg["layer"]),
        "description": str(cfg.get("description", "")),
        "workflow_file_path": str(workflow_file_path),
        "inputs": cfg.get("inputs", []),
        "outputs": cfg.get("outputs", []),
        "params": cfg.get("params", []),
    }


def _record_to_template(record: LensRecord) -> LensTemplate:
    return LensTemplate(
        lens_id=record.lens_id,
        layer=LensLayer(record.layer),
        description=record.description or "",
        raw_workflow=_load_workflow(record.workflow_file_path),
        inputs=_build_assets(record.inputs or []),
        outputs=_build_assets(record.outputs or []),
        params=_build_params(record.params or []),
    )


def _data_to_template(data: Dict[str, Any]) -> LensTemplate:
    return LensTemplate(
        lens_id=str(data["lens_id"]),
        layer=LensLayer(str(data["layer"])),
        description=str(data.get("description", "")),
        raw_workflow=_load_workflow(str(data["workflow_file_path"])),
        inputs=_build_assets(data.get("inputs", [])),
        outputs=_build_assets(data.get("outputs", [])),
        params=_build_params(data.get("params", [])),
    )


LENS_REGISTRY: Dict[str, LensTemplate] = {}


def load_builtin_lenses_into_memory(config_dir: Path | str | None = None) -> Dict[str, LensTemplate]:
    """Load builtin lens configs directly into memory without touching the DB."""
    loaded: Dict[str, LensTemplate] = {}
    for cfg_path in _iter_builtin_config_files(config_dir):
        try:
            with cfg_path.open("r", encoding="utf-8") as f:
                cfg = json.load(f)
            data = _config_to_data(cfg)
            template = _data_to_template(data)
            loaded[template.lens_id] = template
        except Exception as exc:
            print(f"[Registry] 警告：加载内置 lens 失败，file={cfg_path} reason={exc}")

    LENS_REGISTRY.clear()
    LENS_REGISTRY.update(loaded)
    return deepcopy(LENS_REGISTRY)


def seed_builtin_lenses_into_db(db: Session, config_dir: Path | str | None = None) -> Dict[str, LensTemplate]:
    """Insert builtin lens configs into the database if needed."""
    seeded: Dict[str, LensTemplate] = {}
    for cfg_path in _iter_builtin_config_files(config_dir):
        try:
            with cfg_path.open("r", encoding="utf-8") as f:
                cfg = json.load(f)
            data = _config_to_data(cfg)
            template = register_lens(db, data)
            seeded[template.lens_id] = template
        except Exception as exc:
            print(f"[Registry] 警告：seed 内置 lens 失败，file={cfg_path} reason={exc}")
    return deepcopy(seeded)


def get_lens(lens_id: str) -> LensTemplate:
    if lens_id not in LENS_REGISTRY:
        available = list(LENS_REGISTRY.keys())
        raise KeyError(
            f"透镜 '{lens_id}' 未在注册表中找到。"
            f" 当前可用透镜（共 {len(available)} 个）：{available}"
        )
    return LENS_REGISTRY[lens_id]


def reload_registry(db: Session) -> Dict[str, LensTemplate]:
    new_registry: Dict[str, LensTemplate] = {}
    for record in db.query(LensRecord).all():
        try:
            template = _record_to_template(record)
            new_registry[template.lens_id] = template
        except Exception as exc:
            print(f"[Registry] 警告：加载透镜 '{record.lens_id}' 失败，已跳过。原因：{exc}")

    LENS_REGISTRY.clear()
    LENS_REGISTRY.update(new_registry)
    return deepcopy(LENS_REGISTRY)


def register_lens(db: Session, data: Dict[str, Any]) -> LensTemplate:
    workflow_file_path = _resolve_workflow_path(str(data["workflow_file_path"]))
    lens_id = str(data["lens_id"])

    record = db.query(LensRecord).filter(LensRecord.lens_id == lens_id).first()
    if record is None:
        record = LensRecord(lens_id=lens_id)
        db.add(record)

    record.layer = str(data["layer"])
    record.description = str(data.get("description", ""))
    record.workflow_file_path = workflow_file_path
    record.inputs = data.get("inputs", [])
    record.outputs = data.get("outputs", [])
    record.params = data.get("params", [])

    db.commit()
    db.refresh(record)

    template = _record_to_template(record)
    LENS_REGISTRY[lens_id] = template
    return template


def unregister_lens(db: Session, lens_id: str) -> bool:
    record = db.query(LensRecord).filter(LensRecord.lens_id == lens_id).first()
    if record is None:
        return False

    db.delete(record)
    db.commit()
    LENS_REGISTRY.pop(lens_id, None)
    return True


try:
    load_builtin_lenses_into_memory()
except Exception as exc:
    print(f"[Registry] 警告：初始化内置 lens 注册表失败：{exc}")
