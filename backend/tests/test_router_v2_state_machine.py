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
from app.schemas.planner import MissingParam, PlannerOutput, PlannerParamRef, PlannerQuestion
from app.schemas.router import RouterRouteRequest, RouterStatus
from app.services.planner_service import MockPlannerService
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


def test_router_v2_need_clarification_then_ready(db, workflow_file):
    # 注册一个透镜（Catalog+Registry）
    registry.register_lens(
        db,
        {
            "lens_id": "lens_need_param",
            "layer": "A2",
            "description": "需要prompt",
            "workflow_file_path": workflow_file,
            "inputs": [{"name": "base_image", "type": "image", "mapping": {"node_id": "1", "field_name": "image"}}],
            "outputs": [{"name": "result_image", "type": "image", "mapping": {"node_id": "1", "field_name": "images"}}],
            "params": [{"name": "prompt", "type": "text", "description": "", "mapping": {"node_id": "1", "field_name": "text"}}],
        },
    )

    blueprint = DAGBlueprint(
        initial_inputs={"user_base_image": "upload.png"},
        steps=[
            DAGStep(
                step_id="s1",
                lens_id="lens_need_param",
                input_links={"base_image": "$user_base_image"},
                params={},
            )
        ],
    )

    planner_first = PlannerOutput(
        blueprint=blueprint,
        missing_params=[MissingParam(lens_id="lens_need_param", param_name="prompt", reason="需要内容")],
        clarification_questions=[
            PlannerQuestion(
                param_ref=PlannerParamRef(lens_id="lens_need_param", param_name="prompt"),
                question_text="你希望生成什么内容？",
                options=[],
                required=True,
            )
        ],
        thought="缺少prompt",
    )

    rag = _FakeRAGClient("lens_need_param")
    retrieval = RetrievalService(rag)
    service = RouterService(rag_client=rag, retrieval=retrieval, planner=MockPlannerService(planner_first))

    # 第一次：触发追问
    resp1 = service.route_with_db(
        RouterRouteRequest(user_id="u1", user_message="帮我重绘", base_image="upload.png"),
        db=db,
    )
    assert resp1.status == RouterStatus.NEED_CLARIFICATION
    assert resp1.questions and resp1.questions[0].id == "lens_need_param.prompt"
    session_id = resp1.session_id

    # 第二次：回答追问 → Planner 这次给 READY
    planner_second = PlannerOutput(
        blueprint=DAGBlueprint(
            initial_inputs={"user_base_image": "upload.png"},
            steps=[
                DAGStep(
                    step_id="s1",
                    lens_id="lens_need_param",
                    input_links={"base_image": "$user_base_image"},
                    params={"prompt": "一盆多肉"},
                )
            ],
        ),
        missing_params=[],
        clarification_questions=[],
        thought="已补齐",
    )
    service2 = RouterService(rag_client=rag, retrieval=retrieval, planner=MockPlannerService(planner_second))
    resp2 = service2.route_with_db(
        RouterRouteRequest(
            user_id="u1",
            session_id=session_id,
            answers={"lens_need_param.prompt": "一盆多肉"},
        ),
        db=db,
    )
    assert resp2.status == RouterStatus.READY
    assert resp2.blueprint is not None

