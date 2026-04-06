from __future__ import annotations

import io
import json
import os
import uuid
from typing import Any
from urllib.parse import urlencode, urlparse

import httpx
import websockets
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from minio import Minio


def _to_bool(value: str | None, default: bool = False) -> bool:
    if value is None or value == "":
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


FC_TOKEN = os.getenv("MUSELENS_FC_ADAPTER_TOKEN", "").strip()
COMFY_BASE_URL = os.getenv("MUSELENS_FC_COMFY_BASE_URL", "").rstrip("/")
MINIO_ENDPOINT = os.getenv("MUSELENS_MINIO_ENDPOINT", "minio:9000").strip()
MINIO_ACCESS_KEY = os.getenv("MUSELENS_MINIO_ACCESS_KEY", "").strip()
MINIO_SECRET_KEY = os.getenv("MUSELENS_MINIO_SECRET_KEY", "").strip()
MINIO_SECURE = _to_bool(os.getenv("MUSELENS_MINIO_SECURE"), False)
INPUT_BUCKET = os.getenv("MUSELENS_MINIO_BUCKET_INPUT", "muselens-input").strip()
OUTPUT_BUCKET = os.getenv("MUSELENS_MINIO_BUCKET_OUTPUT", "muselens-output").strip()
TEMP_BUCKET = os.getenv("MUSELENS_MINIO_BUCKET_TEMP", "muselens-temp").strip()

minio_client = Minio(
    MINIO_ENDPOINT,
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=MINIO_SECURE,
)

app = FastAPI(title="MuseLens FC Adapter", version="1.0.0")
job_store: dict[str, dict[str, Any]] = {}


class AssetBinding(BaseModel):
    asset_name: str
    object_ref: str
    node_id: str
    field_name: str


class OutputBinding(BaseModel):
    output_name: str
    node_id: str


class JobCreateRequest(BaseModel):
    workflow_json: dict[str, Any]
    asset_bindings: list[AssetBinding] = Field(default_factory=list)
    output_bindings: list[OutputBinding] = Field(default_factory=list)
    output_prefix: str
    session_id: str
    step_id: str


class JobResponse(BaseModel):
    job_id: str
    status: str
    output_assets: dict[str, str] = Field(default_factory=dict)
    error: str | None = None


def _require_auth(authorization: str | None) -> None:
    if not FC_TOKEN:
        return
    expected = f"Bearer {FC_TOKEN}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="Unauthorized")


def _parse_object_ref(value: str) -> tuple[str, str]:
    if "://" in value:
        parsed = urlparse(value)
        return parsed.netloc, parsed.path.lstrip("/")
    bucket, key = value.split("/", 1)
    return bucket, key


def _ensure_bucket(bucket: str) -> None:
    if not minio_client.bucket_exists(bucket):
        minio_client.make_bucket(bucket)


async def _upload_input_asset(
    client: httpx.AsyncClient,
    *,
    object_ref: str,
    filename: str,
) -> str:
    bucket, key = _parse_object_ref(object_ref)
    response = minio_client.get_object(bucket, key)
    try:
        data = response.read()
    finally:
        response.close()
        response.release_conn()

    files = {"image": (filename, io.BytesIO(data), "application/octet-stream")}
    payload = {"type": "input", "overwrite": "true"}
    upload_response = await client.post(f"{COMFY_BASE_URL}/upload/image", data=payload, files=files)
    upload_response.raise_for_status()
    body = upload_response.json()
    return str(body.get("name") or filename)


def _build_ws_url(client_id: str) -> str:
    parsed = urlparse(COMFY_BASE_URL)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    return f"{scheme}://{parsed.netloc}/ws?{urlencode({'clientId': client_id})}"


async def _wait_for_completion(prompt_id: str, client_id: str) -> None:
    async with websockets.connect(_build_ws_url(client_id)) as ws:
        while True:
            message = await ws.recv()
            if not isinstance(message, str):
                continue
            payload = json.loads(message)
            if payload.get("type") != "executing":
                continue
            data = payload.get("data") or {}
            if data.get("node") is None and data.get("prompt_id") == prompt_id:
                return


async def _execute_job(req: JobCreateRequest) -> dict[str, str]:
    workflow_json = req.workflow_json.copy()
    client_id = str(uuid.uuid4())

    async with httpx.AsyncClient(timeout=httpx.Timeout(600.0)) as client:
        for binding in req.asset_bindings:
            _, key = _parse_object_ref(binding.object_ref)
            filename = key.split("/")[-1] or f"{binding.asset_name}.png"
            comfy_filename = await _upload_input_asset(client, object_ref=binding.object_ref, filename=filename)
            workflow_json.setdefault(binding.node_id, {}).setdefault("inputs", {})[binding.field_name] = comfy_filename

        prompt_response = await client.post(
            f"{COMFY_BASE_URL}/prompt",
            json={"prompt": workflow_json, "client_id": client_id},
        )
        prompt_response.raise_for_status()
        prompt_id = prompt_response.json()["prompt_id"]

        await _wait_for_completion(prompt_id, client_id)

        history_response = await client.get(f"{COMFY_BASE_URL}/history/{prompt_id}")
        history_response.raise_for_status()
        history = history_response.json()
        prompt_history = history.get(prompt_id)
        if not prompt_history:
            raise RuntimeError(f"Prompt history not found for {prompt_id}")

        outputs = prompt_history.get("outputs") or {}
        uploaded: dict[str, str] = {}
        for binding in req.output_bindings:
            node_output = outputs.get(binding.node_id) or {}
            images = node_output.get("images") or []
            if not images:
                continue
            image_info = images[0]
            view_response = await client.get(
                f"{COMFY_BASE_URL}/view",
                params={
                    "filename": image_info["filename"],
                    "subfolder": image_info.get("subfolder", ""),
                    "type": image_info.get("type", "output"),
                },
            )
            view_response.raise_for_status()

            file_name = image_info["filename"]
            object_key = "/".join(
                part for part in [req.output_prefix.strip("/"), f"{uuid.uuid4().hex}_{file_name}"] if part
            )
            _ensure_bucket(OUTPUT_BUCKET)
            minio_client.put_object(
                OUTPUT_BUCKET,
                object_key,
                io.BytesIO(view_response.content),
                len(view_response.content),
                content_type=view_response.headers.get("content-type", "application/octet-stream"),
            )
            uploaded[binding.output_name] = f"minio://{OUTPUT_BUCKET}/{object_key}"

        return uploaded


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/jobs/{job_id}", response_model=JobResponse)
def get_job(job_id: str, authorization: str | None = Header(default=None)) -> JobResponse:
    _require_auth(authorization)
    payload = job_store.get(job_id)
    if not payload:
        raise HTTPException(status_code=404, detail="Job not found")
    return JobResponse(**payload)


@app.post("/jobs", response_model=JobResponse)
async def create_job(req: JobCreateRequest, authorization: str | None = Header(default=None)) -> JobResponse:
    _require_auth(authorization)
    job_id = str(uuid.uuid4())
    job_store[job_id] = {"job_id": job_id, "status": "queued", "output_assets": {}, "error": None}
    try:
        outputs = await _execute_job(req)
        job_store[job_id] = {"job_id": job_id, "status": "succeeded", "output_assets": outputs, "error": None}
    except Exception as exc:
        job_store[job_id] = {"job_id": job_id, "status": "failed", "output_assets": {}, "error": str(exc)}
    return JobResponse(**job_store[job_id])


@app.post("/assets/from-object")
def create_asset_alias(
    object_ref: str,
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    _require_auth(authorization)
    return {"object_ref": object_ref}
