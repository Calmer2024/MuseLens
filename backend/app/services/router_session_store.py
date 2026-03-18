from __future__ import annotations

import uuid
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from app.models.router_session_model import RouterSessionRecord


_UNSET = object()


class RouterSessionStore:
    """
    Router 会话状态存储（SQLAlchemy）。

    说明：
    - 这里仅做最小 CRUD 封装，便于 RouterService 状态机调用。
    - 会话结构的具体语义由上层 Router/Planner 约定。
    """

    def get(self, db: Session, session_id: str) -> Optional[RouterSessionRecord]:
        return (
            db.query(RouterSessionRecord)
            .filter(RouterSessionRecord.session_id == session_id)
            .first()
        )

    def create(
        self,
        db: Session,
        *,
        user_id: str,
        original_prompt: str,
        base_image: str,
        base_image_meta: Optional[Dict[str, Any]] = None,
    ) -> RouterSessionRecord:
        rec = RouterSessionRecord(
            session_id=str(uuid.uuid4()),
            user_id=user_id,
            original_prompt=original_prompt or "",
            base_image=base_image or "",
            base_image_meta=base_image_meta or {},
            history_summary="",
            lens_history=[],
            pending_blueprint=None,
            pending_questions=[],
            collected_params={},
        )
        db.add(rec)
        db.commit()
        db.refresh(rec)
        return rec

    def upsert_json_fields(
        self,
        db: Session,
        session_id: str,
        *,
        history_summary: Optional[str] = None,
        lens_history: Optional[list] = None,
        pending_blueprint: Any = _UNSET,
        pending_questions: Optional[list] = None,
        collected_params: Optional[dict] = None,
    ) -> RouterSessionRecord:
        rec = self.get(db, session_id)
        if not rec:
            raise ValueError(f"Router session '{session_id}' not found")

        if history_summary is not None:
            rec.history_summary = history_summary
        if lens_history is not None:
            rec.lens_history = lens_history
        if pending_blueprint is not _UNSET:
            rec.pending_blueprint = pending_blueprint
        if pending_questions is not None:
            rec.pending_questions = pending_questions
        if collected_params is not None:
            rec.collected_params = collected_params

        db.commit()
        db.refresh(rec)
        return rec


router_session_store = RouterSessionStore()

