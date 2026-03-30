import json
import os
import tempfile

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.lenses import registry
from app.schemas.lens import DAGBlueprint, DAGStep
from app.services.blueprint_validator import blueprint_validator


@pytest.fixture(scope="function")
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    s = SessionLocal()
    yield s
    s.close()
    engine.dispose()
    registry.LENS_REGISTRY.clear()
    registry.load_builtin_lenses_into_memory()


@pytest.fixture(scope="function")
def workflow_file():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump({"1": {"inputs": {"text": ""}, "class_type": "CLIPTextEncode"}}, f)
        path = f.name
    yield path
    if os.path.exists(path):
        os.remove(path)


def test_validator_checks_asset_refs_and_outputs(db, workflow_file):
    data = {
        "lens_id": "lens_val_a1",
        "layer": "A1",
        "description": "输出mask",
        "workflow_file_path": workflow_file,
        "inputs": [{"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}],
        "outputs": [{"name": "mask_result", "type": "mask", "mapping": {"node_id": "1", "field_name": "images"}}],
        "params": [{"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "1", "field_name": "text"}}],
    }
    registry.register_lens(db, data)

    blueprint = DAGBlueprint(
        initial_inputs={"user_base_image": "x.png"},
        steps=[
            DAGStep(
                step_id="s1",
                lens_id="lens_val_a1",
                input_links={"base_image": "$user_base_image"},
                params={"prompt": "杯子"},
            )
        ],
    )

    errors = blueprint_validator.validate(db, blueprint)
    assert errors == []


def test_validator_reports_missing_asset_ref(db, workflow_file):
    data = {
        "lens_id": "lens_val_a1b",
        "layer": "A1",
        "description": "",
        "workflow_file_path": workflow_file,
        "inputs": [{"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}],
        "outputs": [{"name": "mask_result", "type": "mask", "mapping": {"node_id": "1", "field_name": "images"}}],
        "params": [],
    }
    registry.register_lens(db, data)

    blueprint = DAGBlueprint(
        initial_inputs={},
        steps=[
            DAGStep(
                step_id="s1",
                lens_id="lens_val_a1b",
                input_links={"base_image": "$user_base_image"},
                params={},
            )
        ],
    )
    errors = blueprint_validator.validate(db, blueprint)
    assert any(e.code == "MISSING_ASSET_REF" for e in errors)


def test_validator_reports_missing_required_input_slot(db, workflow_file):
    data = {
        "lens_id": "lens_val_ref",
        "layer": "A2",
        "description": "",
        "workflow_file_path": workflow_file,
        "inputs": [
            {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}},
            {"name": "ref_image_1", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}},
        ],
        "outputs": [{"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}],
        "params": [{"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "1", "field_name": "text"}}],
    }
    registry.register_lens(db, data)

    blueprint = DAGBlueprint(
        initial_inputs={"user_base_image": "x.png"},
        steps=[
            DAGStep(
                step_id="s1",
                lens_id="lens_val_ref",
                input_links={"base_image": "$user_base_image"},
                params={"prompt": "replace background"},
            )
        ],
    )

    errors = blueprint_validator.validate(db, blueprint)
    assert any(e.code == "MISSING_REQUIRED_INPUT" for e in errors)

