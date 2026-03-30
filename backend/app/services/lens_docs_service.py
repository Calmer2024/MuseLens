from __future__ import annotations

import os
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

import yaml


@dataclass(frozen=True)
class LensParamDoc:
    name: str
    description: str = ""
    decision_rules: str = ""
    format_rules: str = ""
    required: Optional[bool] = None
    default: Any = None

    def merged_description(self, base_description: str = "") -> str:
        parts: List[str] = []
        if base_description:
            parts.append(base_description)
        if self.description:
            parts.append(self.description)
        if self.decision_rules:
            parts.append(self.decision_rules)
        if self.format_rules:
            parts.append(self.format_rules)
        return "\n\n".join([p for p in parts if p]).strip()


@dataclass(frozen=True)
class LensDoc:
    lens_id: str
    layer: Optional[str] = None
    description: str = ""
    params: Dict[str, LensParamDoc] = None  # type: ignore[assignment]
    examples: List[Dict[str, Any]] = None  # type: ignore[assignment]
    body: str = ""


_CACHE: Dict[str, Tuple[float, LensDoc]] = {}


def _repo_root() -> str:
    # backend/app/services -> backend/app -> backend -> repo root
    return os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def get_lens_docs_dir() -> str:
    """
    Lens 说明文档（markdown + YAML frontmatter）根目录。

    默认：backend/app/lenses/docs
    可通过环境变量覆盖：MUSELENS_LENS_DOCS_DIR
    """

    default_dir = os.path.abspath(
        os.path.join(os.path.dirname(__file__), "..", "lenses", "docs")
    )
    return os.getenv("MUSELENS_LENS_DOCS_DIR") or default_dir


def _lens_doc_path(lens_id: str) -> str:
    return os.path.join(get_lens_docs_dir(), f"{lens_id}.md")


def _parse_yaml_frontmatter(md_text: str) -> Tuple[Dict[str, Any], str]:
    """
    解析形如：
    ---
    key: value
    ---
    markdown body...

    返回 (frontmatter_dict, body_text)
    """

    if not md_text:
        return {}, ""

    # 兼容 Windows 换行
    lines = md_text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, md_text

    end_idx = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_idx = i
            break

    if end_idx is None:
        return {}, md_text

    yaml_text = "\n".join(lines[1:end_idx]).strip()
    body_text = "\n".join(lines[end_idx + 1 :]).strip()

    if not yaml_text:
        return {}, body_text

    parsed = yaml.safe_load(yaml_text)
    if not isinstance(parsed, dict):
        return {}, body_text

    return parsed, body_text


def load_lens_doc(lens_id: str) -> Optional[LensDoc]:
    """
    从 `${MUSELENS_LENS_DOCS_DIR}/{lens_id}.md` 读取并解析说明文档。

    解析失败或文件不存在：返回 None（必须保持与现有系统兼容）。
    """

    path = _lens_doc_path(lens_id)
    if not os.path.isfile(path):
        return None

    # mtime 级别缓存，避免每次请求都读文件
    mtime = os.path.getmtime(path)
    cached = _CACHE.get(path)
    if cached and cached[0] >= mtime:
        return cached[1]

    with open(path, "r", encoding="utf-8") as f:
        md_text = f.read()

    frontmatter, body = _parse_yaml_frontmatter(md_text)
    if not frontmatter and not body:
        return None

    doc_lens_id = str(frontmatter.get("lens_id") or lens_id)
    description = str(frontmatter.get("description") or "")
    layer = frontmatter.get("layer")
    layer = str(layer) if layer is not None else None

    raw_params = frontmatter.get("params") or {}
    params: Dict[str, LensParamDoc] = {}

    # 兼容两种常见写法：
    # 1) list：params: [{name: "...", description: "...", required: true, ...}, ...]
    # 2) map：params: { positive_prompt: { description: "...", required: true, ... }, ... }
    if isinstance(raw_params, list):
        for p in raw_params:
            if not isinstance(p, dict):
                continue
            name = p.get("name")
            if not name:
                continue
            params[str(name)] = LensParamDoc(
                name=str(name),
                description=str(p.get("description") or ""),
                decision_rules=str(p.get("decision_rules") or ""),
                format_rules=str(p.get("format_rules") or ""),
                required=p.get("required", None),
                default=p.get("default", None),
            )
    elif isinstance(raw_params, dict):
        for name, p in raw_params.items():
            if not name:
                continue
            if not isinstance(p, dict):
                continue
            params[str(name)] = LensParamDoc(
                name=str(name),
                description=str(p.get("description") or ""),
                decision_rules=str(p.get("decision_rules") or ""),
                format_rules=str(p.get("format_rules") or ""),
                required=p.get("required", None),
                default=p.get("default", None),
            )

    raw_examples = frontmatter.get("examples") or []
    examples: List[Dict[str, Any]] = []
    if isinstance(raw_examples, list):
        for ex in raw_examples:
            if not isinstance(ex, dict):
                continue
            # 保持与 RetrievalService 的 LensExample 字段命名对齐：
            # - nl_desc
            # - params_example
            if "nl_desc" in ex and "params_example" in ex:
                examples.append(ex)

    # body 作为兜底说明：把正文前几行拼到 description 后面（如果 YAML 没写 description）
    if not description and body:
        snippet = "\n".join(body.splitlines()[:30]).strip()
        description = snippet

    doc = LensDoc(
        lens_id=doc_lens_id,
        layer=layer,
        description=description,
        params=params,
        examples=examples,
        body=body,
    )

    _CACHE[path] = (mtime, doc)
    return doc


def clear_lens_doc_cache() -> None:
    """手工清理缓存（例如调试/运维脚本）。"""

    _CACHE.clear()

