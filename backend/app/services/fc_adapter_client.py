from __future__ import annotations

import os
from typing import Any

import httpx


class FCAdapterClient:
    def __init__(self) -> None:
        self.base_url = os.getenv("MUSELENS_FC_ADAPTER_BASE_URL", "http://fc-adapter:8080").rstrip("/")
        self.api_token = os.getenv("MUSELENS_FC_ADAPTER_TOKEN", "").strip()
        self.timeout_seconds = float(os.getenv("MUSELENS_FC_ADAPTER_TIMEOUT_S", "600"))

    def _headers(self) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if self.api_token:
            headers["Authorization"] = f"Bearer {self.api_token}"
        return headers

    async def create_job(
        self,
        *,
        workflow_json: dict[str, Any],
        asset_bindings: list[dict[str, Any]],
        output_bindings: list[dict[str, Any]],
        output_prefix: str,
        session_id: str,
        step_id: str,
    ) -> dict[str, Any]:
        payload = {
            "workflow_json": workflow_json,
            "asset_bindings": asset_bindings,
            "output_bindings": output_bindings,
            "output_prefix": output_prefix,
            "session_id": session_id,
            "step_id": step_id,
        }
        async with httpx.AsyncClient(timeout=self.timeout_seconds) as client:
            response = await client.post(
                f"{self.base_url}/jobs",
                json=payload,
                headers=self._headers(),
            )
        response.raise_for_status()
        return response.json()


fc_adapter_client = FCAdapterClient()
