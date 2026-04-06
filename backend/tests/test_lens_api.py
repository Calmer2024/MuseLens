"""Integration tests for the lens management API."""

import json
import os
import tempfile
import base64

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.lenses import registry
from app.main import app


@pytest.fixture(scope="function")
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_get_db():
        db = session_local()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    db = session_local()
    yield db
    db.close()
    engine.dispose()
    app.dependency_overrides.clear()
    registry.LENS_REGISTRY.clear()
    registry.load_builtin_lenses_into_memory()


@pytest.fixture(scope="function")
def client(test_db):
    return TestClient(app)


@pytest.fixture(scope="function")
def temp_workflow_file():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as f:
        workflow_content = {
            "1": {"inputs": {"image": "test.png"}, "class_type": "LoadImage"},
            "2": {"inputs": {"text": "test prompt"}, "class_type": "CLIPTextEncode"},
        }
        json.dump(workflow_content, f)
        temp_path = f.name

    yield temp_path

    if os.path.exists(temp_path):
        os.remove(temp_path)


def test_register_lens_via_api_creates_record(client, temp_workflow_file):
    payload = {
        "lens_id": "lens_api_test_1",
        "layer": "A1",
        "description": "API 测试透镜",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
        ],
        "outputs": [
            {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "prompt", "type": "text", "description": "提示词", "mapping": {"node_id": "2", "field_name": "text"}}
        ],
    }

    response = client.post("/api/v1/lenses/register", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["lens_id"] == "lens_api_test_1"
    assert data["layer"] == "A1"
    assert data["description"] == "API 测试透镜"
    assert "created_at" in data
    assert "updated_at" in data


def test_register_lens_with_invalid_workflow_path_returns_422(client):
    payload = {
        "lens_id": "lens_api_bad_path",
        "layer": "A1",
        "description": "坏路径测试",
        "workflow_file_path": "/nonexistent/workflow.json",
        "inputs": [],
        "outputs": [],
        "params": [],
    }

    response = client.post("/api/v1/lenses/register", json=payload)

    assert response.status_code == 422
    assert "未找到" in response.json()["detail"]


def test_register_lens_twice_updates_existing(client, temp_workflow_file):
    payload_v1 = {
        "lens_id": "lens_api_update",
        "layer": "A1",
        "description": "初始版本",
        "workflow_file_path": temp_workflow_file,
        "inputs": [],
        "outputs": [],
        "params": [],
    }
    assert client.post("/api/v1/lenses/register", json=payload_v1).status_code == 200

    payload_v2 = {
        "lens_id": "lens_api_update",
        "layer": "A2",
        "description": "更新版本",
        "workflow_file_path": temp_workflow_file,
        "inputs": [],
        "outputs": [],
        "params": [
            {"name": "new_param", "type": "float", "description": "新参数", "mapping": {"node_id": "2", "field_name": "value"}}
        ],
    }

    response = client.post("/api/v1/lenses/register", json=payload_v2)
    assert response.status_code == 200
    data = response.json()
    assert data["layer"] == "A2"
    assert data["description"] == "更新版本"


def test_list_lenses_returns_all_registered(client, temp_workflow_file):
    for i in range(2):
        payload = {
            "lens_id": f"lens_api_list_{i}",
            "layer": "A1",
            "description": f"列表测试 {i}",
            "workflow_file_path": temp_workflow_file,
            "inputs": [],
            "outputs": [],
            "params": [],
        }
        client.post("/api/v1/lenses/register", json=payload)

    response = client.get("/api/v1/lenses/")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2
    assert {item["lens_id"] for item in data} == {"lens_api_list_0", "lens_api_list_1"}


def test_list_lenses_empty_when_no_lenses(client):
    response = client.get("/api/v1/lenses/")
    assert response.status_code == 200
    assert response.json() == []


def test_get_lens_detail_returns_full_info(client, temp_workflow_file):
    payload = {
        "lens_id": "lens_api_detail",
        "layer": "A2",
        "description": "详情测试",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "input_1", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
        ],
        "outputs": [
            {"name": "output_1", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "param_1", "type": "text", "description": "参数1", "mapping": {"node_id": "2", "field_name": "text"}}
        ],
    }
    client.post("/api/v1/lenses/register", json=payload)

    response = client.get("/api/v1/lenses/lens_api_detail")
    assert response.status_code == 200
    data = response.json()
    assert data["lens_id"] == "lens_api_detail"
    assert len(data["inputs"]) == 1
    assert len(data["outputs"]) == 1
    assert len(data["params"]) == 1
    assert data["inputs"][0]["name"] == "input_1"


def test_get_lens_detail_nonexistent_returns_404(client):
    response = client.get("/api/v1/lenses/nonexistent_lens")
    assert response.status_code == 404
    assert "不存在" in response.json()["detail"]


def test_delete_lens_removes_record(client, temp_workflow_file):
    payload = {
        "lens_id": "lens_api_delete",
        "layer": "A1",
        "description": "待删除",
        "workflow_file_path": temp_workflow_file,
        "inputs": [],
        "outputs": [],
        "params": [],
    }
    client.post("/api/v1/lenses/register", json=payload)
    assert "lens_api_delete" in registry.LENS_REGISTRY

    response = client.delete("/api/v1/lenses/lens_api_delete")
    assert response.status_code == 200
    assert "成功注销" in response.json()["detail"]
    assert "lens_api_delete" not in registry.LENS_REGISTRY
    assert client.get("/api/v1/lenses/lens_api_delete").status_code == 404


def test_delete_nonexistent_lens_returns_404(client):
    response = client.delete("/api/v1/lenses/nonexistent_lens")
    assert response.status_code == 404
    assert "不存在" in response.json()["detail"]


def test_reload_registry_via_api(client, temp_workflow_file, test_db):
    from app.models.lens_model import LensRecord

    test_db.add(
        LensRecord(
            lens_id="lens_api_reload_test",
            layer="A1",
            description="重载测试",
            workflow_file_path=temp_workflow_file,
            inputs=[],
            outputs=[],
            params=[],
        )
    )
    test_db.commit()
    registry.LENS_REGISTRY.clear()

    response = client.post("/api/v1/lenses/reload")
    assert response.status_code == 200
    data = response.json()
    assert "已重载" in data["detail"]
    assert data["lens_ids"] == ["lens_api_reload_test"]
    assert "lens_api_reload_test" in registry.LENS_REGISTRY


def test_run_lens_directly_returns_result(client, temp_workflow_file, monkeypatch):
    payload = {
        "lens_id": "lens_api_run_direct",
        "layer": "A2",
        "description": "直连执行测试",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
        ],
        "outputs": [
            {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "prompt", "type": "text", "description": "提示词", "mapping": {"node_id": "2", "field_name": "text"}}
        ],
    }
    assert client.post("/api/v1/lenses/register", json=payload).status_code == 200

    import app.api.v1.endpoints.lenses as lenses_endpoint

    async def _fake_execute(blueprint):
        assert blueprint.steps[0].lens_id == "lens_api_run_direct"
        assert blueprint.steps[0].params["prompt"] == "make it brighter"
        assert blueprint.initial_inputs["base_image"] == "upload.png"
        return {
            "base_image": "upload.png",
            "step_1_direct_lens.result_image": "direct_result.png",
        }

    monkeypatch.setattr(lenses_endpoint.compiler, "execute_blueprint", _fake_execute)

    resp = client.post(
        "/api/v1/lenses/run",
        json={
            "lens_id": "lens_api_run_direct",
            "assets": {"base_image": "upload.png"},
            "params": {"prompt": "make it brighter"},
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["lens_id"] == "lens_api_run_direct"
    assert body["executed"] is True
    assert body["execution_started"] is True
    assert body["result_filename"] == "direct_result.png"
    assert body["result_url"] == "http://127.0.0.1:8188/view?filename=direct_result.png&type=output"
    assert body["blueprint"]["steps"][0]["lens_id"] == "lens_api_run_direct"
    assert body["step_results"][0]["step_id"] == "step_1_direct_lens"
    assert body["step_results"][0]["outputs"][0]["filename"] == "direct_result.png"


def test_run_lens_directly_returns_error_when_assets_missing(client, temp_workflow_file):
    payload = {
        "lens_id": "lens_api_run_missing_asset",
        "layer": "A2",
        "description": "缺失资产测试",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
        ],
        "outputs": [
            {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [],
    }
    assert client.post("/api/v1/lenses/register", json=payload).status_code == 200

    resp = client.post(
        "/api/v1/lenses/run",
        json={
            "lens_id": "lens_api_run_missing_asset",
            "assets": {},
            "params": {},
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["executed"] is False
    assert "缺少必须的输入资产" in body["execution_error"]


def test_new_lens_stream_id_endpoint(client):
    resp = client.get("/api/v1/lenses/stream/new")
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body["stream_id"], str)
    assert len(body["stream_id"]) >= 8


def test_save_mask_asset_endpoint(client, monkeypatch):
    import app.api.v1.endpoints.lenses as lenses_endpoint

    png_bytes = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+yv1cAAAAASUVORK5CYII="
    )
    monkeypatch.setattr(
        lenses_endpoint,
        "upload_user_image",
        lambda **kwargs: "local://muselens-input/input/test-mask.png",
    )
    monkeypatch.setattr(
        lenses_endpoint,
        "build_asset_url",
        lambda ref: f"/api/v1/storage/object?ref={ref}",
    )

    resp = client.post(
        "/api/v1/lenses/mask-assets",
        json={
            "mask_base64": base64.b64encode(png_bytes).decode("ascii"),
            "asset_name": "mask",
            "prompt_hint": "woman",
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["asset_name"] == "mask"
    assert body["prompt_hint"] == "woman"
    assert body["source"] == "mask_editor"
    assert body["mime_type"] == "image/png"
    assert body["byte_size"] > 0
    assert body["width"] == 1
    assert body["height"] == 1
    assert body["filename"] == "local://muselens-input/input/test-mask.png"
    assert body["user_assets_patch"]["mask"] == body["filename"]
    assert body["preview_url"] == f"/api/v1/storage/object?ref={body['filename']}"


def test_upload_mask_asset_endpoint(client, monkeypatch):
    import app.api.v1.endpoints.lenses as lenses_endpoint

    monkeypatch.setattr(
        lenses_endpoint,
        "upload_user_image",
        lambda **kwargs: "local://muselens-input/input/upload-mask.png",
    )
    monkeypatch.setattr(
        lenses_endpoint,
        "build_asset_url",
        lambda ref: f"/api/v1/storage/object?ref={ref}",
    )
    png_bytes = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+yv1cAAAAASUVORK5CYII="
    )
    resp = client.post(
        "/api/v1/lenses/mask-assets/upload",
        files={"file": ("mask.png", png_bytes, "image/png")},
        data={
            "asset_name": "mask",
            "prompt_hint": "subject",
            "source": "mask_editor",
            "metadata_json": json.dumps({"origin": "canvas"}),
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["asset_name"] == "mask"
    assert body["prompt_hint"] == "subject"
    assert body["source"] == "mask_editor"
    assert body["metadata"]["origin"] == "canvas"
    assert body["width"] == 1
    assert body["height"] == 1
    assert body["filename"] == "local://muselens-input/input/upload-mask.png"


def test_get_lens_tweak_controls_endpoint(client, temp_workflow_file):
    payload = {
        "lens_id": "lens_relighting",
        "layer": "A3",
        "description": "光影测试",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}},
            {"name": "depth_map", "type": "image", "mapping": {"node_id": "1", "field_name": "depth"}},
        ],
        "outputs": [
            {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "prompt", "type": "text", "description": "提示词", "mapping": {"node_id": "2", "field_name": "text"}}
        ],
    }
    assert client.post("/api/v1/lenses/register", json=payload).status_code == 200

    resp = client.get("/api/v1/lenses/lens_relighting/tweak-controls")
    assert resp.status_code == 200
    body = resp.json()
    assert body["lens_id"] == "lens_relighting"
    assert body["tweak_controls"][0]["control_id"] == "light_orb"


def test_lens_sam2_matting_no_longer_exposes_mask_editor_as_tweak_control(client):
    resp = client.get("/api/v1/lenses/lens_sam2_matting/tweak-controls")
    assert resp.status_code == 200
    body = resp.json()
    assert body["lens_id"] == "lens_sam2_matting"
    assert body["tweak_controls"] == []


def test_get_asset_tools_endpoint_returns_mask_editor(client):
    resp = client.get("/api/v1/lenses/asset-tools")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) >= 1
    mask_editor = next(item for item in body if item["tool_id"] == "mask_editor")
    assert mask_editor["tool_type"] == "asset_preparation_tool"
    assert mask_editor["output_asset_name"] == "mask"
    assert mask_editor["save_endpoints"]["json"] == "/api/v1/lenses/mask-assets"
    assert mask_editor["save_endpoints"]["upload"] == "/api/v1/lenses/mask-assets/upload"


def test_get_asset_tool_detail_endpoint_returns_mask_editor(client):
    resp = client.get("/api/v1/lenses/asset-tools/mask_editor")
    assert resp.status_code == 200
    body = resp.json()
    assert body["tool_id"] == "mask_editor"
    assert body["usage"]["router_user_assets_key"] == "mask"
    assert body["usage"]["lens_assets_key"] == "mask"


def test_apply_controls_for_lora_filter_translates_without_llm(client, temp_workflow_file):
    payload = {
        "lens_id": "lens_lora_filter",
        "layer": "A4",
        "description": "LoRA 滤镜测试",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
        ],
        "outputs": [
            {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "lora_name", "type": "text", "description": "LoRA 名", "mapping": {"node_id": "2", "field_name": "text"}},
            {"name": "strength_model", "type": "float", "description": "强度", "mapping": {"node_id": "2", "field_name": "value"}},
            {"name": "strength_clip", "type": "float", "description": "强度", "mapping": {"node_id": "2", "field_name": "value2"}},
            {"name": "prompt", "type": "text", "description": "提示词", "mapping": {"node_id": "2", "field_name": "prompt"}},
        ],
    }
    assert client.post("/api/v1/lenses/register", json=payload).status_code == 200

    resp = client.post(
        "/api/v1/lenses/lens_lora_filter/apply-controls",
        json={
            "assets": {"base_image": "upload.png"},
            "current_params": {},
            "control_values": {
                "filter_selector": "ghibli",
                "filter_opacity": 0.65,
            },
            "execute": False,
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["translated_params"]["lora_name"] == "Studio Ghibli Style.safetensors"
    assert body["translated_params"]["strength_model"] == 0.65
    assert body["translated_params"]["strength_clip"] == 0.65
    assert body["execution"] is None


def test_apply_controls_for_relighting_uses_translated_prompt(client, temp_workflow_file, monkeypatch):
    payload = {
        "lens_id": "lens_relighting",
        "layer": "A3",
        "description": "光影测试",
        "workflow_file_path": temp_workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}},
            {"name": "depth_map", "type": "image", "mapping": {"node_id": "1", "field_name": "depth"}},
        ],
        "outputs": [
            {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
        ],
        "params": [
            {"name": "prompt", "type": "text", "description": "提示词", "mapping": {"node_id": "2", "field_name": "text"}},
            {"name": "steps", "type": "int", "description": "步数", "mapping": {"node_id": "2", "field_name": "steps"}},
        ],
    }
    assert client.post("/api/v1/lenses/register", json=payload).status_code == 200

    import app.api.v1.endpoints.lenses as lenses_endpoint
    import app.services.lens_control_translation_service as control_service

    monkeypatch.setattr(
        control_service,
        "_llm_generate_relighting_prompt",
        lambda **kwargs: "strong warm sunset key light from the upper right, cinematic contrast",
    )

    async def _fake_execute(blueprint):
        assert blueprint.steps[0].params["prompt"] == "strong warm sunset key light from the upper right, cinematic contrast"
        assert "steps" in blueprint.steps[0].params
        return {
            "base_image": "upload.png",
            "depth_map": "depth.png",
            "step_1_direct_lens.result_image": "relit.png",
        }

    monkeypatch.setattr(lenses_endpoint.compiler, "execute_blueprint", _fake_execute)

    resp = client.post(
        "/api/v1/lenses/lens_relighting/apply-controls",
        json={
            "assets": {"base_image": "upload.png", "depth_map": "depth.png"},
            "current_params": {"prompt": "initial prompt"},
            "control_values": {
                "light_orb": {
                    "x": 0.8,
                    "y": 0.2,
                    "z": 0.7,
                    "intensity": 0.9,
                    "color_temperature": 3800,
                }
            },
            "execute": True,
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["translated_params"]["prompt"] == "strong warm sunset key light from the upper right, cinematic contrast"
    assert body["execution"]["result_filename"] == "relit.png"
