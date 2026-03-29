"""
PostgreSQL 上的端到端栈测试：透镜注册 / Retrieval 拼装 / Router v2 状态机 / 会话落库。

- 默认使用 Mock Planner，不依赖外网 LLM。
- 真实 LLM 见 test_planner_service_real_llm 与文末 opt-in 用例。
"""

from __future__ import annotations

import json
import os
import tempfile

import pytest

from app.lenses import registry
from app.models.lens_example_model import LensExampleRecord
from app.models.lens_model import LensRecord
from app.models.router_session_model import RouterSessionRecord
from app.schemas.lens import DAGBlueprint, DAGStep
from app.schemas.planner import MissingParam, PlannerOutput, PlannerParamRef, PlannerQuestion
from app.schemas.router import RouterRouteRequest, RouterStatus
from app.services.planner_service import MockPlannerService, PlannerService, SequenceMockPlannerService
from app.services.rag_client import InMemoryLensRAGClient
from app.services.retrieval_service import RetrievalService
from app.services.router_service import RouterService


@pytest.fixture(scope="function")
def workflow_file():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(
            {
                "1": {"inputs": {"image": "in.png"}, "class_type": "LoadImage"},
                "2": {"inputs": {"text": ""}, "class_type": "CLIPTextEncode"},
            },
            f,
        )
        path = f.name
    yield path
    if os.path.exists(path):
        os.remove(path)


@pytest.mark.integration
def test_retrieval_merges_catalog_and_examples_from_postgres(postgres_test_db, workflow_file):
    """注册透镜 + example 行后，Retrieval 应拼出 LensKnowledge（含 examples）。"""
    db = postgres_test_db["db"]
    lens_id = "lens_e2e_retrieval"

    registry.register_lens(
        db,
        {
            "lens_id": lens_id,
            "layer": "A2",
            "description": "抠图换背景 局部重绘",
            "workflow_file_path": workflow_file,
            "inputs": [
                {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
            ],
            "outputs": [
                {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
            ],
            "params": [
                {"name": "prompt", "type": "text", "description": "提示词", "mapping": {"node_id": "2", "field_name": "text"}}
            ],
        },
    )
    db.add(
        LensExampleRecord(
            lens_id=lens_id,
            nl_desc="把杯子换成多肉",
            params_example={"prompt": "多肉"},
        )
    )
    db.commit()

    ex_count = db.query(LensExampleRecord).filter(LensExampleRecord.lens_id == lens_id).count()
    assert ex_count >= 1

    rag = InMemoryLensRAGClient()
    retrieval = RetrievalService(rag)
    rows = retrieval.retrieve(db, task_desc="抠图 换背景 杯子", top_k=5)
    assert rows, "InMemory RAG 应能命中已注册透镜"
    hit = next(r for r in rows if r.lens_id == lens_id)
    assert "抠图" in (hit.description or "") or "重绘" in (hit.description or "")
    assert hit.examples, "examples 应从 lens_examples 表合并进来"


@pytest.mark.integration
def test_router_v2_ready_mock_planner_persists_session(postgres_test_db, workflow_file):
    """Router v2 + Mock Planner(READY)：蓝图合法、会话写入 router_sessions。"""
    db = postgres_test_db["db"]
    lens_id = "lens_e2e_ready"

    registry.register_lens(
        db,
        {
            "lens_id": lens_id,
            "layer": "A2",
            "description": "测试就绪",
            "workflow_file_path": workflow_file,
            "inputs": [
                {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
            ],
            "outputs": [
                {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
            ],
            "params": [
                {"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "2", "field_name": "text"}}
            ],
        },
    )

    bp = DAGBlueprint(
        initial_inputs={"user_base_image": "upload.png"},
        steps=[
            DAGStep(
                step_id="s1",
                lens_id=lens_id,
                input_links={"base_image": "$user_base_image"},
                params={"prompt": "ok"},
            )
        ],
    )
    planner = MockPlannerService(
        PlannerOutput(
            blueprint=bp,
            missing_params=[],
            clarification_questions=[],
            thought="mock ready",
        )
    )
    router = RouterService(rag_client=InMemoryLensRAGClient(), retrieval=RetrievalService(InMemoryLensRAGClient()), planner=planner)  # type: ignore[arg-type]

    resp = router.route_with_db(
        RouterRouteRequest(user_id="u1", user_message="抠图测试", base_image="upload.png"),
        db=db,
    )

    assert resp.status == RouterStatus.READY
    assert resp.blueprint is not None
    assert lens_id in (resp.extra.get("retrieved_lenses") or [])

    sess = db.query(RouterSessionRecord).filter(RouterSessionRecord.session_id == resp.session_id).first()
    assert sess is not None
    assert sess.user_id == "u1"
    assert (sess.lens_history or []) != []


@pytest.mark.integration
def test_router_v2_clarification_then_answer_mock_planner(postgres_test_db, workflow_file):
    """首轮追问落库，次轮带 answers 后 READY。"""
    db = postgres_test_db["db"]
    lens_id = "lens_e2e_clar"

    registry.register_lens(
        db,
        {
            "lens_id": lens_id,
            "layer": "A2",
            "description": "追问测试",
            "workflow_file_path": workflow_file,
            "inputs": [
                {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
            ],
            "outputs": [
                {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
            ],
            "params": [
                {
                    "name": "prompt",
                    "type": "text",
                    "description": "",
                    "required": True,
                    "mapping": {"node_id": "2", "field_name": "text"},
                }
            ],
        },
    )

    bp_shell = DAGBlueprint(
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
    out_ask = PlannerOutput(
        blueprint=bp_shell,
        missing_params=[MissingParam(lens_id=lens_id, param_name="prompt", reason="缺参")],
        clarification_questions=[
            PlannerQuestion(
                param_ref=PlannerParamRef(lens_id=lens_id, param_name="prompt"),
                question_text="请输入 prompt",
                required=True,
            )
        ],
        thought="need prompt",
    )
    out_ready = PlannerOutput(
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
        missing_params=[],
        clarification_questions=[],
        thought="filled from collected",
    )

    planner = SequenceMockPlannerService([out_ask, out_ready])
    router = RouterService(rag_client=InMemoryLensRAGClient(), retrieval=RetrievalService(InMemoryLensRAGClient()), planner=planner)  # type: ignore[arg-type]

    r1 = router.route_with_db(
        RouterRouteRequest(user_id="u1", user_message="帮我改图", base_image="upload.png"),
        db=db,
    )
    assert r1.status == RouterStatus.NEED_CLARIFICATION
    assert r1.questions
    sid = r1.session_id

    sess_mid = db.query(RouterSessionRecord).filter(RouterSessionRecord.session_id == sid).first()
    assert sess_mid is not None
    assert sess_mid.pending_questions

    r2 = router.route_with_db(
        RouterRouteRequest(
            user_id="u1",
            session_id=sid,
            answers={f"{lens_id}.prompt": "多肉植物"},
        ),
        db=db,
    )
    assert r2.status == RouterStatus.READY
    assert r2.blueprint is not None


@pytest.mark.integration
def test_router_v2_enrich_then_ready_sequence_planner(postgres_test_db, workflow_file):
    """首轮 Planner 报缺参触发 enrich 后二次 plan，最终 READY。"""
    db = postgres_test_db["db"]
    lens_id = "lens_e2e_enrich"

    registry.register_lens(
        db,
        {
            "lens_id": lens_id,
            "layer": "A2",
            "description": "enrich 测试",
            "workflow_file_path": workflow_file,
            "inputs": [
                {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
            ],
            "outputs": [
                {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
            ],
            "params": [
                {"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "2", "field_name": "text"}}
            ],
        },
    )

    bp1 = DAGBlueprint(
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
    # 首轮：无 blueprint，仅 missing，触发 enrich + 第二次 plan
    out_sparse = PlannerOutput(
        blueprint=None,
        missing_params=[MissingParam(lens_id=lens_id, param_name="prompt", reason="需要 enrich")],
        clarification_questions=[
            PlannerQuestion(
                param_ref=PlannerParamRef(lens_id=lens_id, param_name="prompt"),
                question_text="请提供 prompt",
                required=True,
            )
        ],
        thought="sparse",
    )
    out_ready = PlannerOutput(
        blueprint=DAGBlueprint(
            initial_inputs={"user_base_image": "upload.png"},
            steps=[
                DAGStep(
                    step_id="s1",
                    lens_id=lens_id,
                    input_links={"base_image": "$user_base_image"},
                    params={"prompt": "补全后"},
                )
            ],
        ),
        missing_params=[],
        clarification_questions=[],
        thought="after enrich",
    )

    planner = SequenceMockPlannerService([out_sparse, out_ready])
    router = RouterService(rag_client=InMemoryLensRAGClient(), retrieval=RetrievalService(InMemoryLensRAGClient()), planner=planner)  # type: ignore[arg-type]

    resp = router.route_with_db(
        RouterRouteRequest(user_id="u1", user_message="enrich 流程", base_image="upload.png"),
        db=db,
    )
    assert resp.status == RouterStatus.READY
    assert resp.blueprint is not None


@pytest.mark.integration
def test_router_api_postgres_mock_planner_via_endpoint(postgres_test_db, workflow_file, client, monkeypatch):
    """HTTP /router/route 与 PostgreSQL 依赖注入路径：替换 endpoint 内 router_service。"""
    import app.api.v1.endpoints.router as router_endpoint

    db = postgres_test_db["db"]
    lens_id = "lens_e2e_http"

    registry.register_lens(
        db,
        {
            "lens_id": lens_id,
            "layer": "A2",
            "description": "http e2e",
            "workflow_file_path": workflow_file,
            "inputs": [
                {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
            ],
            "outputs": [
                {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
            ],
            "params": [
                {"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "2", "field_name": "text"}}
            ],
        },
    )

    bp = DAGBlueprint(
        initial_inputs={"user_base_image": "a.png"},
        steps=[
            DAGStep(
                step_id="s1",
                lens_id=lens_id,
                input_links={"base_image": "$user_base_image"},
                params={"prompt": "x"},
            )
        ],
    )
    planner = MockPlannerService(
        PlannerOutput(blueprint=bp, missing_params=[], clarification_questions=[], thought="http")
    )
    svc = RouterService(
        rag_client=InMemoryLensRAGClient(),
        retrieval=RetrievalService(InMemoryLensRAGClient()),
        planner=planner,  # type: ignore[arg-type]
    )
    monkeypatch.setattr(router_endpoint, "router_service", svc)

    r = client.post(
        "/api/v1/router/route",
        json={"user_id": "u1", "user_message": "测试", "base_image": "a.png"},
    )
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "ready"
    assert body["blueprint"] is not None


@pytest.mark.integration
def test_planner_real_llm_with_postgres_catalog_candidates(postgres_test_db, workflow_file):
    """
    真实 LLM：在已注册透镜的 Catalog 上调用 PlannerService.plan（不经 HTTP）。

    需：MUSELENS_TEST_REAL_LLM=1，且 .env 或环境中已配置 MUSELENS_LLM_*。
    """
    if os.getenv("MUSELENS_TEST_REAL_LLM", "").strip() != "1":
        pytest.skip("设置 MUSELENS_TEST_REAL_LLM=1 以启用真实 LLM 集成测试")

    db = postgres_test_db["db"]
    lens_a = "lens_e2e_llm_a"
    lens_b = "lens_e2e_llm_b"

    for lid, desc in [
        (lens_a, "目标分割抠图 matting 输出 mask"),
        (lens_b, "图像局部重绘 inpaint 换背景"),
    ]:
        registry.register_lens(
            db,
            {
                "lens_id": lid,
                "layer": "A2",
                "description": desc,
                "workflow_file_path": workflow_file,
                "inputs": [
                    {"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}
                ],
                "outputs": [
                    {"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}
                ],
                "params": [
                    {
                        "name": "prompt",
                        "type": "text",
                        "description": "自然语言说明",
                        "mapping": {"node_id": "2", "field_name": "text"},
                    }
                ],
            },
        )

    retrieval = RetrievalService(InMemoryLensRAGClient())
    know = retrieval.retrieve(db, task_desc="把图中的杯子换成多肉植物", top_k=5)
    assert know, "Retrieval 应返回候选"
    candidates = [k.model_dump() for k in know]

    planner = PlannerService(timeout_s=45)
    if not planner.is_configured():
        pytest.skip("未配置 MUSELENS_LLM_API_KEY / MUSELENS_LLM_MODEL")

    from app.schemas.planner import PlannerInput

    out = planner.plan(
        PlannerInput(
            task_desc="把图中的杯子换成多肉植物",
            base_image_meta={},
            candidates=candidates,
            session_context={},
        )
    )
    assert out.thought
    ids_in_cand = {c["lens_id"] for c in candidates}
    if out.blueprint:
        for step in out.blueprint.steps:
            assert step.lens_id in ids_in_cand
    else:
        assert out.missing_params or out.clarification_questions
