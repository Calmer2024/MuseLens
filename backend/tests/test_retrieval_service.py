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
