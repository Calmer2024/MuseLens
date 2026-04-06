from __future__ import annotations

import copy
import logging
import os
from typing import Any, Awaitable, Callable, Dict

from app.lenses.registry import get_lens
from app.schemas.lens import DAGBlueprint, LensTemplate
from app.services.comfy_service import AsyncComfyRunner
from app.services.object_storage_service import storage_service


COMFYUI_OUTPUT_DIR = os.environ.get("COMFYUI_OUTPUT_DIR", "/tmp/comfyui/output")
COMFYUI_INPUT_DIR = os.environ.get("COMFYUI_INPUT_DIR", "/tmp/comfyui/input")

logger = logging.getLogger(__name__)

ProgressCallback = Callable[[str, Dict[str, str]], Awaitable[None]]
StepStartedCallback = Callable[[str, str, int, int], Awaitable[None]]


class MuseDNACompiler:
    def __init__(self, input_dir: str | None = None, output_dir: str | None = None):
        self.input_dir = input_dir or COMFYUI_INPUT_DIR
        self.output_dir = output_dir or COMFYUI_OUTPUT_DIR

    def _resolve_asset(self, link_value: str, context: Dict[str, str]) -> str:
        if link_value.startswith("$"):
            var_name = link_value[1:]
            if var_name not in context:
                raise RuntimeError(f"Variable reference {link_value} not found in current context: {list(context.keys())}")
            return str(context[var_name])
        return link_value

    def _inject_params_only(self, template: LensTemplate, params: Dict[str, Any]) -> dict:
        workflow = copy.deepcopy(template.raw_workflow)
        for param in template.params:
            if param.name not in params:
                continue
            workflow[param.mapping.node_id]["inputs"][param.mapping.field_name] = params[param.name]
        return workflow

    def _build_asset_bindings(
        self,
        *,
        template: LensTemplate,
        resolved_assets: Dict[str, str],
    ) -> list[dict[str, str]]:
        bindings: list[dict[str, str]] = []
        for asset in template.inputs:
            if asset.name not in resolved_assets:
                raise ValueError(f"Missing required asset input: {asset.name}")
            bindings.append(
                {
                    "asset_name": asset.name,
                    "object_ref": resolved_assets[asset.name],
                    "node_id": asset.mapping.node_id,
                    "field_name": asset.mapping.field_name,
                }
            )
        return bindings

    def _build_output_bindings(self, template: LensTemplate) -> list[dict[str, str]]:
        return [
            {
                "output_name": asset.name,
                "node_id": asset.mapping.node_id,
            }
            for asset in template.outputs
        ]

    async def execute_blueprint(
        self,
        blueprint: DAGBlueprint,
        progress_callback: ProgressCallback = None,
        step_started_callback: StepStartedCallback = None,
    ) -> Dict[str, str]:
        context = {key: str(value) for key, value in (blueprint.initial_inputs or {}).items()}
        runner = AsyncComfyRunner()
        try:
            total_steps = len(blueprint.steps)
            session_id = blueprint.session_id if hasattr(blueprint, "session_id") else None
            session_id = session_id or "session"
            for idx, step in enumerate(blueprint.steps, start=1):
                if step_started_callback:
                    await step_started_callback(step.step_id, step.lens_id, idx, total_steps)

                lens_template = get_lens(step.lens_id)
                resolved_assets = {
                    asset_name: self._resolve_asset(link_value, context)
                    for asset_name, link_value in step.input_links.items()
                }
                asset_bindings = self._build_asset_bindings(template=lens_template, resolved_assets=resolved_assets)
                output_bindings = self._build_output_bindings(lens_template)
                workflow = self._inject_params_only(lens_template, step.params)
                step_outputs = await runner.run_workflow(
                    workflow_json=workflow,
                    asset_bindings=asset_bindings,
                    output_bindings=output_bindings,
                    output_prefix=storage_service.normalize_key("output", session_id, step.step_id),
                    session_id=session_id,
                    step_id=step.step_id,
                )

                for output_name, object_ref in step_outputs.items():
                    context[f"{step.step_id}.{output_name}"] = object_ref

                if progress_callback:
                    await progress_callback(step.step_id, step_outputs)
        finally:
            await runner.close()

        return context
