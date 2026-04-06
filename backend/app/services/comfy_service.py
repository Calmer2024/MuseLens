from __future__ import annotations

from typing import Any

from app.services.fc_adapter_client import fc_adapter_client


class AsyncComfyRunner:
    """
    Production runner that delegates ComfyUI execution to the FC adapter service.
    """

    async def run_workflow(
        self,
        *,
        workflow_json: dict[str, Any],
        asset_bindings: list[dict[str, Any]],
        output_bindings: list[dict[str, Any]],
        output_prefix: str,
        session_id: str,
        step_id: str,
    ) -> dict[str, str]:
        response = await fc_adapter_client.create_job(
            workflow_json=workflow_json,
            asset_bindings=asset_bindings,
            output_bindings=output_bindings,
            output_prefix=output_prefix,
            session_id=session_id,
            step_id=step_id,
        )
        if response.get("status") != "succeeded":
            raise RuntimeError(response.get("error") or "FC adapter job failed.")
        output_assets = response.get("output_assets") or {}
        return {str(key): str(value) for key, value in output_assets.items()}

    async def close(self) -> None:
        return None
