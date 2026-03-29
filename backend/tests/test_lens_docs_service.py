from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.database import Base
from app.models.lens_model import LensRecord
from app.services.lens_docs_service import load_lens_doc
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


def _make_test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    session_local = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return engine, session_local


def test_load_lens_doc_parses_frontmatter():
    doc = load_lens_doc("lens_inpaint_bg")
    assert doc is not None
    assert doc.lens_id == "lens_inpaint_bg"
    assert doc.layer == "A2"
    assert "positive_prompt" in doc.params
    assert doc.params["positive_prompt"].required is True
    assert doc.params["positive_prompt"].default == ""
    assert doc.examples
    assert any(ex.get("nl_desc") for ex in doc.examples)


def test_retrieval_service_overlays_doc_params_and_layer():
    engine, session_local = _make_test_db()
    db = session_local()
    try:
        lens_id = "lens_depth_extract"
        db.add(
            LensRecord(
                lens_id=lens_id,
                layer="A1",
                description="db description",
                workflow_file_path="dummy.json",
                inputs=[],
                outputs=[],
                params=[
                    {
                        "name": "prompt",
                        "type": "text",
                        "description": "db base prompt description",
                        "mapping": {"node_id": "1", "field_name": "text"},
                    }
                ],
            )
        )
        db.commit()

        service = RetrievalService(_FakeRAGClient(lens_id=lens_id))
        items = service.retrieve(db, task_desc="提取深度图", top_k=3)
        assert len(items) == 1

        item = items[0]
        assert item.layer == "A3"
        assert item.params and item.params[0].name == "prompt"
        prompt_schema = item.params[0]
        assert prompt_schema.required is False
        assert prompt_schema.default == ""
        assert "可选的辅助描述" in prompt_schema.description
        assert item.examples
        assert any(ex.params_example.get("prompt") for ex in item.examples)
    finally:
        db.close()
        engine.dispose()
