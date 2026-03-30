import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.lens_example_model import LensExampleRecord
from app.models.lens_model import LensRecord
from app.services.retrieval_service import RetrievalService


class _FakeRAGClient:
    def __init__(self, lens_id: str, score: float = 0.9) -> None:
        self._lens_id = lens_id
        self._score = score

    def search_lenses(self, query_text: str, k: int = 5):
        from app.schemas.lens import LensLayer, LensTemplate
        from app.services.rag_client import LensCandidate

        tmpl = LensTemplate(
            lens_id=self._lens_id,
            layer=LensLayer.A1,
            description="",
            raw_workflow={},
            inputs=[],
            outputs=[],
            params=[],
        )
        return [LensCandidate(lens_id=self._lens_id, score=self._score, template=tmpl)]


@pytest.fixture(scope="function")
def db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    s = session_local()
    yield s
    s.close()
    engine.dispose()


def test_retrieval_enriches_catalog_and_examples(db):
    lens_id = "lens_retrieval_test"
    db.add(
        LensRecord(
            lens_id=lens_id,
            layer="A2",
            description="测试透镜描述",
            workflow_file_path="dummy.json",
            inputs=[],
            outputs=[],
            params=[
                {
                    "name": "prompt",
                    "type": "text",
                    "description": "提示词",
                    "required": True,
                    "default": None,
                    "mapping": {"node_id": "1", "field_name": "text"},
                }
            ],
        )
    )
    db.add(
        LensExampleRecord(
            lens_id=lens_id,
            nl_desc="把杯子换成多肉",
            params_example={"prompt": "一盆多肉"},
        )
    )
    db.commit()

    service = RetrievalService(_FakeRAGClient(lens_id))
    items = service.retrieve(db, task_desc="测试", top_k=3)

    assert len(items) == 1
    one = items[0]
    assert one.lens_id == lens_id
    assert one.layer == "A2"
    assert one.description == "测试透镜描述"
    assert one.params and one.params[0].name == "prompt"
    assert one.examples and one.examples[0].nl_desc == "把杯子换成多肉"


def test_retrieve_by_lens_ids(db):
    lens_id = "lens_by_ids_only"
    db.add(
        LensRecord(
            lens_id=lens_id,
            layer="A2",
            description="按 id 拉取",
            workflow_file_path="dummy.json",
            inputs=[],
            outputs=[],
            params=[
                {
                    "name": "prompt",
                    "type": "text",
                    "description": "提示",
                    "required": False,
                    "mapping": {},
                }
            ],
        )
    )
    db.commit()

    service = RetrievalService(_FakeRAGClient("unrelated_lens"))
    items = service.retrieve_by_lens_ids(db, [lens_id], score_by_id={lens_id: 0.5})

    assert len(items) == 1
    assert items[0].lens_id == lens_id
    assert items[0].score == 0.5
    assert items[0].params and items[0].params[0].name == "prompt"


def test_retrieve_expands_mask_dependency_candidates(db):
    db.add_all(
        [
            LensRecord(
                lens_id="lens_flux_inpaint",
                layer="A2",
                description="局部遮罩重绘",
                workflow_file_path="dummy.json",
                inputs=[
                    {"name": "base_image", "type": "image"},
                    {"name": "mask", "type": "mask"},
                ],
                outputs=[{"name": "result_image", "type": "image"}],
                params=[
                    {
                        "name": "prompt",
                        "type": "text",
                        "description": "局部替换提示词",
                        "required": True,
                        "mapping": {},
                    }
                ],
            ),
            LensRecord(
                lens_id="lens_sam2_matting",
                layer="A1",
                description="文本分割并输出遮罩",
                workflow_file_path="dummy.json",
                inputs=[{"name": "base_image", "type": "image"}],
                outputs=[{"name": "mask_result", "type": "image"}],
                params=[
                    {
                        "name": "prompt",
                        "type": "text",
                        "description": "分割目标",
                        "required": True,
                        "mapping": {},
                    }
                ],
            ),
        ]
    )
    db.commit()

    service = RetrievalService(_FakeRAGClient("lens_flux_inpaint"))
    items = service.retrieve(db, task_desc="把图中的女人替换成一只猪", top_k=3)
    lens_ids = [item.lens_id for item in items]

    assert lens_ids[0] == "lens_flux_inpaint"
    assert "lens_sam2_matting" in lens_ids


def test_retrieve_expands_depth_dependency_candidates(db):
    db.add_all(
        [
            LensRecord(
                lens_id="lens_relighting",
                layer="A3",
                description="全局光影重构",
                workflow_file_path="dummy.json",
                inputs=[
                    {"name": "base_image", "type": "image"},
                    {"name": "depth_map", "type": "depth_map"},
                ],
                outputs=[{"name": "result_image", "type": "image"}],
                params=[
                    {
                        "name": "prompt",
                        "type": "text",
                        "description": "光影描述",
                        "required": True,
                        "mapping": {},
                    }
                ],
            ),
            LensRecord(
                lens_id="lens_depth_extract",
                layer="A1",
                description="深度提取",
                workflow_file_path="dummy.json",
                inputs=[{"name": "base_image", "type": "image"}],
                outputs=[{"name": "depth_map", "type": "depth_map"}],
                params=[],
            ),
        ]
    )
    db.commit()

    service = RetrievalService(_FakeRAGClient("lens_relighting"))
    items = service.retrieve(db, task_desc="调整为黄昏光从右上角照下", top_k=3)
    lens_ids = [item.lens_id for item in items]

    assert lens_ids[0] == "lens_relighting"
    assert "lens_depth_extract" in lens_ids
