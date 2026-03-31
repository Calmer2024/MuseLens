from __future__ import annotations

import os
from typing import Any

from app.lenses.registry import get_lens
from app.services.lens_ui_control_service import get_lens_tweak_controls
from app.services.router_stream_service import router_stream_service


def build_result_url(filename: str) -> str:
    base_url = (os.getenv("COMFYUI_VIEW_BASE_URL") or "http://127.0.0.1:8188").rstrip("/")
    return f"{base_url}/view?filename={filename}&type=output"


def build_input_asset_url(filename: str) -> str:
    base_url = (os.getenv("COMFYUI_VIEW_BASE_URL") or "http://127.0.0.1:8188").rstrip("/")
    return f"{base_url}/view?filename={filename}&type=input"


def infer_result_filename(blueprint, execution_context: dict[str, str]) -> str | None:
    for step in reversed(blueprint.steps):
        candidate = execution_context.get(f"{step.step_id}.result_image")
        if candidate:
            return candidate
    for step in reversed(blueprint.steps):
        step_prefix = f"{step.step_id}."
        for key, value in execution_context.items():
            if key.startswith(step_prefix) and value:
                return value
    return None


def build_step_outputs_from_step_payload(output_assets: dict[str, str]) -> list[dict]:
    outputs: list[dict] = []
    for output_name, filename in output_assets.items():
        outputs.append(
            {
                "output_name": output_name,
                "filename": filename,
                "url": build_result_url(filename),
            }
        )
    return outputs


def build_step_results(blueprint, execution_context: dict[str, str]) -> list[dict]:
    step_results: list[dict] = []

    for step in blueprint.steps:
        outputs: list[dict] = []
        try:
            lens_template = get_lens(step.lens_id)
            output_names = [asset.name for asset in lens_template.outputs]
        except Exception:
            output_names = []

        seen_output_names: set[str] = set()
        for output_name in output_names:
            key = f"{step.step_id}.{output_name}"
            filename = execution_context.get(key)
            if not filename:
                continue
            seen_output_names.add(output_name)
            outputs.append(
                {
                    "output_name": output_name,
                    "filename": filename,
                    "url": build_result_url(filename),
                }
            )

        step_prefix = f"{step.step_id}."
        for key, filename in execution_context.items():
            if not key.startswith(step_prefix):
                continue
            output_name = key[len(step_prefix):]
            if output_name in seen_output_names or not filename:
                continue
            outputs.append(
                {
                    "output_name": output_name,
                    "filename": filename,
                    "url": build_result_url(filename),
                }
            )

        step_results.append(
            {
                "step_id": step.step_id,
                "lens_id": step.lens_id,
                "tweak_controls": get_lens_tweak_controls(step.lens_id),
                "outputs": outputs,
            }
        )

    return step_results


async def execute_blueprint_with_optional_stream(
    *,
    compiler,
    blueprint,
    session_id: str,
    stream_id: str | None,
) -> dict[str, str]:
    if not stream_id:
        return await compiler.execute_blueprint(blueprint)

    step_lens_map = {step.step_id: step.lens_id for step in blueprint.steps}

    async def on_step_started(step_id: str, lens_id: str, step_index: int, total_steps: int) -> None:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "step_started",
                "session_id": session_id,
                "stream_id": stream_id,
                "step_id": step_id,
                "lens_id": lens_id,
                "step_index": step_index,
                "total_steps": total_steps,
            },
        )

    async def on_step_completed(step_id: str, output_assets: dict[str, str]) -> None:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "step_completed",
                "session_id": session_id,
                "stream_id": stream_id,
                "step_id": step_id,
                "lens_id": step_lens_map.get(step_id),
                "outputs": build_step_outputs_from_step_payload(output_assets),
            },
        )

    await router_stream_service.emit(
        stream_id,
        {
            "event": "execution_started",
            "session_id": session_id,
            "stream_id": stream_id,
            "blueprint": blueprint.model_dump(),
        },
    )

    return await compiler.execute_blueprint(
        blueprint,
        progress_callback=on_step_completed,
        step_started_callback=on_step_started,
    )


async def run_blueprint_with_stream_events(
    *,
    compiler,
    blueprint,
    session_id: str,
    stream_id: str,
) -> None:
    try:
        final_context = await execute_blueprint_with_optional_stream(
            compiler=compiler,
            blueprint=blueprint,
            session_id=session_id,
            stream_id=stream_id,
        )
        result_filename = infer_result_filename(blueprint, final_context)
        await router_stream_service.emit(
            stream_id,
            {
                "event": "execution_completed",
                "session_id": session_id,
                "stream_id": stream_id,
                "execution_context": final_context,
                "result_filename": result_filename,
                "result_url": build_result_url(result_filename) if result_filename else None,
                "step_results": build_step_results(blueprint, final_context),
            },
        )
    except Exception as exc:
        await router_stream_service.emit(
            stream_id,
            {
                "event": "execution_failed",
                "session_id": session_id,
                "stream_id": stream_id,
                "error": str(exc),
            },
        )
