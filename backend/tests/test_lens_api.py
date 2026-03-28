"""Integration tests for the lens management API."""

import json
import os
import tempfile

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
