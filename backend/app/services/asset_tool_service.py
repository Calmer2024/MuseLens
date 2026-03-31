from __future__ import annotations

from typing import Any, Dict, List


_ASSET_TOOL_SPECS: Dict[str, Dict[str, Any]] = {
    "mask_editor": {
        "tool_id": "mask_editor",
        "label": "遮罩画笔",
        "tool_type": "asset_preparation_tool",
        "control_type": "mask_editor",
        "description": "前端画布涂抹生成可复用的 mask 资产，供 Router、单透镜执行和工作流微调直接消费。",
        "output_asset_name": "mask",
        "output_asset_type": "mask",
        "supported_entrypoints": [
            "router",
            "direct_lens_run",
            "workflow_refine",
            "musedna_run",
        ],
        "save_endpoints": {
            "json": "/api/v1/lenses/mask-assets",
            "upload": "/api/v1/lenses/mask-assets/upload",
        },
        "usage": {
            "router_user_assets_key": "mask",
            "lens_assets_key": "mask",
        },
        "ui_schema": {
            "accepted_mime_types": ["image/png"],
            "supports_data_url": True,
            "supports_file_upload": True,
            "recommended_asset_name": "mask",
        },
    }
}


def get_asset_tools() -> List[Dict[str, Any]]:
    return [dict(tool) for tool in _ASSET_TOOL_SPECS.values()]


def get_asset_tool(tool_id: str) -> Dict[str, Any]:
    tool = _ASSET_TOOL_SPECS.get(tool_id)
    if not tool:
        raise KeyError(tool_id)
    return dict(tool)
