import json

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
        from app.services.rag_client import LensCandidate
        from app.schemas.lens import LensLayer, LensTemplate

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
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return engine, TestingSessionLocal


def test_load_lens_doc_parses_frontmatter():
    doc = load_lens_doc("lens_inpaint_bg")
    assert doc is not None
    assert doc.lens_id == "lens_inpaint_bg"
    assert doc.layer == "A2"

    assert "positive_prompt" in doc.params
    pp = doc.params["positive_prompt"]
    assert pp.required is True
    assert pp.default == ""

    # examples 里应包含 nl_desc + params_example
    assert doc.examples
    assert any(ex.get("nl_desc") for ex in doc.examples)


def test_retrieval_service_overlays_doc_params_and_layer():
    """
    验证 RetrievalService 会用 docs 覆盖数据库里的：
    - layer
    - params[].required/default/description（decision_rules/format_rules 等）
    - examples（doc.examples）
    """

    engine, TestingSessionLocal = _make_test_db()
    db = TestingSessionLocal()
    try:
        lens_id = "lens_depth_extract"
        # 数据库里的 layer 故意设为与 docs 不同，用来验证叠加生效
        db.add(
            LensRecord(
                lens_id=lens_id,
                layer="A1",
                description="db description",
                workflow_file_path="dummy.json",
                inputs_json="[]",
                outputs_json="[]",
                params_json=json.dumps(
                    [
                        {
                            "name": "prompt",
                            "type": "text",
                            "description": "db base prompt description",
                            # 注意：不填 required/default，让 docs 来覆盖
                            "mapping": {"node_id": "1", "field_name": "text"},
                        }
                    ],
                    ensure_ascii=False,
                ),
            )
        )
        db.commit()

        service = RetrievalService(_FakeRAGClient(lens_id=lens_id))
        items = service.retrieve(db, task_desc="提取深度图", top_k=3)
        assert len(items) == 1
        item = items[0]

        # docs 指定 layer=A3；覆盖生效
        assert item.layer == "A3"

        # docs 指定 prompt.required=false, default=""
        assert item.params and item.params[0].name == "prompt"
        prompt_schema = item.params[0]
        assert prompt_schema.required is False
        assert prompt_schema.default == ""

        # merged_description 应包含 docs 的 decision/description 片段
        assert "可选的辅助描述" in prompt_schema.description

        # doc.examples 也应被带上
        assert item.examples
        # lens_depth_extract.md 里 params_example.prompt 应存在
        assert any(ex.params_example.get("prompt") for ex in item.examples)
    finally:
        db.close()
        engine.dispose()

