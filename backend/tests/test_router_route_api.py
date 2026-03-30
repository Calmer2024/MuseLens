import json
import os
import tempfile
from typing import List

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base, get_db
from app.lenses import registry
from app.main import app
from app.schemas.lens import DAGBlueprint, DAGStep
from app.schemas.planner import MissingParam, PlannerOutput, PlannerParamRef, PlannerQuestion
from app.schemas.router import RouterRouteRequest, RouterStatus
from app.services.planner_service import MockPlannerService, SequenceMockPlannerService
from app.services.retrieval_service import RetrievalService
from app.services.router_service import RouterService


class _FakeRAGClient:
    def __init__(self, lens_id: str) -> None:
        self._lens_id = lens_id

    def search_lenses(self, query_text: str, k: int = 5):
        from app.services.rag_client import LensCandidate
        from app.schemas.lens import LensTemplate, LensLayer

        tmpl = LensTemplate(
            lens_id=self._lens_id,
            layer=LensLayer.A1,
            description="",
            raw_workflow={},
            inputs=[],
            outputs=[],
            params=[],
        )
        return [LensCandidate(lens_id=self._lens_id, score=0.9, template=tmpl)]


@pytest.fixture(scope="function")
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    db = TestingSessionLocal()
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
def workflow_file():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump({"1": {"inputs": {"text": ""}, "class_type": "CLIPTextEncode"}}, f)
        path = f.name
    yield path
    if os.path.exists(path):
        os.remove(path)


def test_route_endpoint_need_clarification_then_ready(client, test_db, workflow_file, monkeypatch):
    # 注册一个透镜（使 Catalog+Registry 可用）
    registry.register_lens(
        test_db,
        {
            "lens_id": "lens_api_need_param",
            "layer": "A2",
            "description": "需要prompt",
            "workflow_file_path": workflow_file,
            "inputs": [{"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}],
            "outputs": [{"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}],
            "params": [{"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "1", "field_name": "text"}}],
        },
    )

    # 构造 Mock Planner（第一轮追问，第二轮READY）
    blueprint_empty = DAGBlueprint(
        initial_inputs={"user_base_image": "upload.png"},
        steps=[
            DAGStep(
                step_id="s1",
                lens_id="lens_api_need_param",
                input_links={"base_image": "$user_base_image"},
                params={},
            )
        ],
    )
    planner1 = MockPlannerService(
        PlannerOutput(
            blueprint=blueprint_empty,
            missing_params=[MissingParam(lens_id="lens_api_need_param", param_name="prompt", reason="缺少")],
            clarification_questions=[
                PlannerQuestion(
                    param_ref=PlannerParamRef(lens_id="lens_api_need_param", param_name="prompt"),
                    question_text="请输入prompt",
                    required=True,
                )
            ],
            thought="需要prompt",
        )
    )
    planner2 = MockPlannerService(
        PlannerOutput(
            blueprint=DAGBlueprint(
                initial_inputs={"user_base_image": "upload.png"},
                steps=[
                    DAGStep(
                        step_id="s1",
                        lens_id="lens_api_need_param",
                        input_links={"base_image": "$user_base_image"},
                        params={"prompt": "一盆多肉"},
                    )
                ],
            ),
            missing_params=[],
            clarification_questions=[],
            thought="OK",
        )
    )

    rag = _FakeRAGClient("lens_api_need_param")
    retrieval = RetrievalService(rag)

    # 端点模块里的 router_service 单例替换为我们的实例（两轮不同planner，用两次patch）
    import app.api.v1.endpoints.router as router_endpoint

    monkeypatch.setattr(
        router_endpoint,
        "router_service",
        RouterService(rag_client=rag, retrieval=retrieval, planner=planner1),  # type: ignore[arg-type]
    )

    r1 = client.post(
        "/api/v1/router/route",
        json={"user_id": "u1", "user_message": "帮我改图", "base_image": "upload.png"},
    )
    assert r1.status_code == 200
    body1 = r1.json()
    assert body1["status"] == "need_clarification"
    assert body1["questions"][0]["id"] == "lens_api_need_param.prompt"
    session_id = body1["session_id"]

    monkeypatch.setattr(
        router_endpoint,
        "router_service",
        RouterService(rag_client=rag, retrieval=retrieval, planner=planner2),  # type: ignore[arg-type]
    )
    r2 = client.post(
        "/api/v1/router/route",
        json={
            "user_id": "u1",
            "session_id": session_id,
            "answers": {"lens_api_need_param.prompt": "一盆多肉"},
        },
    )
    assert r2.status_code == 200
    body2 = r2.json()
    assert body2["status"] == "ready"
    assert body2["blueprint"] is not None


def test_route_endpoint_reads_lens_examples_from_register_api(
    client, test_db, workflow_file, monkeypatch
):
    """
    验证：
    1) /api/v1/lenses/register 写入的 lens_examples 会被 RetrievalService 读取；
    2) /api/v1/router/route 的 response 会包含 extra.retrieved_lenses；
    3) 追问/READY 流程仍可跑通。
    """
    lens_id = "lens_api_need_example"

    # 先用 Lens 管理 API 注册透镜 + examples
    r_register = client.post(
        "/api/v1/lenses/register",
        json={
            "lens_id": lens_id,
            "layer": "A2",
            "description": "需要 prompt",
            "workflow_file_path": workflow_file,
            "inputs": [
                {
                    "name": "base_image",
                    "type": "image",
                    "mapping": {"node_id": "1", "field_name": "image"},
                }
            ],
            "outputs": [
                {
                    "name": "result_image",
                    "type": "image",
                    "mapping": {"node_id": "1", "field_name": "images"},
                }
            ],
            "params": [
                {
                    "name": "prompt",
                    "type": "text",
                    "description": "",
                    "mapping": {"node_id": "1", "field_name": "text"},
                }
            ],
            "examples": [
                {
                    "nl_desc": "把杯子换成多肉",
                    "params_example": {"prompt": "一盆多肉"},
                }
            ],
        },
    )
    assert r_register.status_code == 200

    class _AssertExamplesPlanner:
        def __init__(self, out: PlannerOutput) -> None:
            self._out = out

        def is_configured(self) -> bool:
            return True

        def plan(self, planner_input):
            # planner_input.candidates 在 RouterService 中是由 RetrievalService 结果 model_dump 组成的 dict list
            cands = planner_input.candidates
            cand = next(c for c in cands if c.get("lens_id") == lens_id)
            examples = cand.get("examples") or []
            assert examples, "expected lens_examples to be present in candidates"
            assert examples[0].get("nl_desc") == "把杯子换成多肉"
            return self._out

    # 第 1 轮：返回追问
    planner1 = _AssertExamplesPlanner(
        PlannerOutput(
            blueprint=DAGBlueprint(
                initial_inputs={"user_base_image": "upload.png"},
                steps=[
                    DAGStep(
                        step_id="s1",
                        lens_id=lens_id,
                        input_links={"base_image": "$user_base_image"},
                        params={},
                    )
                ],
            ),
            missing_params=[
                MissingParam(lens_id=lens_id, param_name="prompt", reason="缺少")
            ],
            clarification_questions=[
                PlannerQuestion(
                    param_ref=PlannerParamRef(
                        lens_id=lens_id, param_name="prompt"
                    ),
                    question_text="请输入prompt",
                    required=True,
                )
            ],
            thought="need prompt",
        )
    )

    # 第 2 轮：返回 READY（不再追问）
    planner2 = _AssertExamplesPlanner(
        PlannerOutput(
            blueprint=DAGBlueprint(
                initial_inputs={"user_base_image": "upload.png"},
                steps=[
                    DAGStep(
                        step_id="s1",
                        lens_id=lens_id,
                        input_links={"base_image": "$user_base_image"},
                        params={"prompt": "一盆多肉"},
                    )
                ],
            ),
            missing_params=[],
            clarification_questions=[],
            thought="OK",
        )
    )

    rag = _FakeRAGClient(lens_id)
    retrieval = RetrievalService(rag)

    import app.api.v1.endpoints.router as router_endpoint

    monkeypatch.setattr(
        router_endpoint,
        "router_service",
        RouterService(rag_client=rag, retrieval=retrieval, planner=planner1),  # type: ignore[arg-type]
    )

    r1 = client.post(
        "/api/v1/router/route",
        json={"user_id": "u1", "user_message": "帮我改图", "base_image": "upload.png"},
    )
    assert r1.status_code == 200
    body1 = r1.json()
    assert body1["status"] == "need_clarification"
    assert body1["questions"][0]["id"] == f"{lens_id}.prompt"
    assert lens_id in (body1["extra"].get("retrieved_lenses") or [])
    session_id = body1["session_id"]

    monkeypatch.setattr(
        router_endpoint,
        "router_service",
        RouterService(rag_client=rag, retrieval=retrieval, planner=planner2),  # type: ignore[arg-type]
    )

    r2 = client.post(
        "/api/v1/router/route",
        json={
            "user_id": "u1",
            "session_id": session_id,
            "answers": {f"{lens_id}.prompt": "一盆多肉"},
        },
    )
    assert r2.status_code == 200
    body2 = r2.json()
    assert body2["status"] == "ready"
    assert body2["blueprint"] is not None
    assert lens_id in (body2["extra"].get("retrieved_lenses") or [])


class _RecordingSequencePlanner(SequenceMockPlannerService):
    """记录每次 plan 的 PlannerInput，用于断言 enrich 后第二轮 candidates。"""

    def __init__(self, outputs: List[PlannerOutput]) -> None:
        super().__init__(outputs)
        self.inputs: List = []

    def plan(self, planner_input):
        self.inputs.append(planner_input)
        return super().plan(planner_input)


def test_route_skill_enrich_on_missing_params_reloads_candidates(test_db, workflow_file):
    """
    首轮 Planner 报 missing_params 时触发 enrich，第二轮 Planner 输入的 candidates
    应包含该 lens 的 params（来自 retrieve_by_lens_ids）；第二次 plan 返回 READY。
    """
    lens_id = "lens_enrich_skill"

    registry.register_lens(
        test_db,
        {
            "lens_id": lens_id,
            "layer": "A2",
            "description": "需要 prompt",
            "workflow_file_path": workflow_file,
            "inputs": [
                {
                    "name": "base_image",
                    "type": "image",
                    "mapping": {"node_id": "1", "field_name": "image"},
                }
            ],
            "outputs": [
                {
                    "name": "result_image",
                    "type": "image",
                    "mapping": {"node_id": "1", "field_name": "images"},
                }
            ],
            "params": [
                {
                    "name": "prompt",
                    "type": "text",
                    "description": "",
                    "mapping": {"node_id": "1", "field_name": "text"},
                }
            ],
        },
    )

    blueprint_round1 = DAGBlueprint(
        initial_inputs={"user_base_image": "upload.png"},
        steps=[
            DAGStep(
                step_id="s1",
                lens_id=lens_id,
                input_links={"base_image": "$user_base_image"},
                params={},
            )
        ],
    )
    out1 = PlannerOutput(
        blueprint=blueprint_round1,
        missing_params=[MissingParam(lens_id=lens_id, param_name="prompt", reason="缺参")],
        clarification_questions=[
            PlannerQuestion(
                param_ref=PlannerParamRef(lens_id=lens_id, param_name="prompt"),
                question_text="请输入 prompt",
                required=True,
            )
        ],
        thought="round1",
    )
    out2 = PlannerOutput(
        blueprint=DAGBlueprint(
            initial_inputs={"user_base_image": "upload.png"},
            steps=[
                DAGStep(
                    step_id="s1",
                    lens_id=lens_id,
                    input_links={"base_image": "$user_base_image"},
                    params={"prompt": "一盆多肉"},
                )
            ],
        ),
        missing_params=[],
        clarification_questions=[],
        thought="round2",
    )

    planner = _RecordingSequencePlanner([out1, out2])
    rag = _FakeRAGClient(lens_id)
    retrieval = RetrievalService(rag)
    service = RouterService(rag_client=rag, retrieval=retrieval, planner=planner)  # type: ignore[arg-type]

    resp = service.route_with_db(
        RouterRouteRequest(user_id="u1", user_message="帮我改图", base_image="upload.png"),
        db=test_db,
    )

    assert resp.status == RouterStatus.READY
    assert resp.blueprint is not None
    assert len(planner.inputs) == 2
    cand = next(c for c in planner.inputs[1].candidates if c.get("lens_id") == lens_id)
    param_names = [p.get("name") for p in (cand.get("params") or [])]
    assert "prompt" in param_names


def test_route_and_run_endpoint_returns_questions_without_execution(
    client, test_db, workflow_file, monkeypatch
):
    lens_id = "lens_api_route_and_run_clarify"

    registry.register_lens(
        test_db,
        {
            "lens_id": lens_id,
            "layer": "A2",
            "description": "需要 prompt",
            "workflow_file_path": workflow_file,
            "inputs": [{"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}],
            "outputs": [{"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}],
            "params": [{"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "1", "field_name": "text"}}],
        },
    )

    planner = MockPlannerService(
        PlannerOutput(
            blueprint=DAGBlueprint(
                initial_inputs={"user_base_image": "upload.png"},
                steps=[
                    DAGStep(
                        step_id="s1",
                        lens_id=lens_id,
                        input_links={"base_image": "$user_base_image"},
                        params={},
                    )
                ],
            ),
            missing_params=[MissingParam(lens_id=lens_id, param_name="prompt", reason="缺少")],
            clarification_questions=[
                PlannerQuestion(
                    param_ref=PlannerParamRef(lens_id=lens_id, param_name="prompt"),
                    question_text="请输入 prompt",
                    required=True,
                )
            ],
            thought="need prompt",
        )
    )

    rag = _FakeRAGClient(lens_id)
    retrieval = RetrievalService(rag)

    import app.api.v1.endpoints.router as router_endpoint

    async def _unexpected_execute(_blueprint):
        raise AssertionError("execute_blueprint should not be called when clarification is needed")

    monkeypatch.setattr(
        router_endpoint,
        "router_service",
        RouterService(rag_client=rag, retrieval=retrieval, planner=planner),  # type: ignore[arg-type]
    )
    monkeypatch.setattr(router_endpoint.compiler, "execute_blueprint", _unexpected_execute)

    resp = client.post(
        "/api/v1/router/route_and_run",
        json={"user_id": "u1", "user_message": "帮我改图", "base_image": "upload.png"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "need_clarification"
    assert body["executed"] is False
    assert body["execution_context"] == {}
    assert body["result_filename"] is None
    assert body["execution_error"] is None
    assert body["questions"][0]["id"] == f"{lens_id}.prompt"


def test_route_and_run_endpoint_executes_ready_blueprint(client, test_db, workflow_file, monkeypatch):
    lens_id = "lens_api_route_and_run_ready"

    registry.register_lens(
        test_db,
        {
            "lens_id": lens_id,
            "layer": "A2",
            "description": "ready 执行测试",
            "workflow_file_path": workflow_file,
            "inputs": [{"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}],
            "outputs": [{"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}],
            "params": [{"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "1", "field_name": "text"}}],
        },
    )

    planner = MockPlannerService(
        PlannerOutput(
            blueprint=DAGBlueprint(
                initial_inputs={"user_base_image": "upload.png"},
                steps=[
                    DAGStep(
                        step_id="s1",
                        lens_id=lens_id,
                        input_links={"base_image": "$user_base_image"},
                        params={"prompt": "一盆多肉"},
                    )
                ],
            ),
            missing_params=[],
            clarification_questions=[],
            thought="ready",
        )
    )

    rag = _FakeRAGClient(lens_id)
    retrieval = RetrievalService(rag)

    import app.api.v1.endpoints.router as router_endpoint

    captured = {}

    async def _fake_execute(blueprint):
        captured["blueprint"] = blueprint.model_dump()
        return {
            "user_base_image": "upload.png",
            "s1.result_image": "result.png",
        }

    monkeypatch.setattr(
        router_endpoint,
        "router_service",
        RouterService(rag_client=rag, retrieval=retrieval, planner=planner),  # type: ignore[arg-type]
    )
    monkeypatch.setattr(router_endpoint.compiler, "execute_blueprint", _fake_execute)

    resp = client.post(
        "/api/v1/router/route_and_run",
        json={"user_id": "u1", "user_message": "帮我改图", "base_image": "upload.png"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "ready"
    assert body["executed"] is True
    assert body["result_filename"] == "result.png"
    assert body["result_url"] == "http://127.0.0.1:8188/view?filename=result.png&type=output"
    assert body["execution_error"] is None
    assert body["execution_context"]["s1.result_image"] == "result.png"
    assert captured["blueprint"]["steps"][0]["lens_id"] == lens_id

