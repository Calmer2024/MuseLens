"""
简化版 RouterService 实现。

该版本不依赖真实的 LLM 或向量数据库，而是：
- 使用内置的 Lens 注册表做一个最小可用的“RAG”；
- 利用关键词规则，将常见中文需求解析为固定的透镜序列；
- 在信息缺失时生成 ClarifyQuestion，等待前端回填答案；
- 最终产出可直接交给 MuseDNACompiler 的 DAGBlueprint。

后续可以在不改变对外接口的前提下，将内部实现替换为
真正的 LLM + pgvector 方案。
"""

from __future__ import annotations

import os
import re
import uuid
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from app.schemas.lens import DAGBlueprint, DAGStep
from app.schemas.router import (
    ClarifyQuestion,
    QuestionBind,
    QuestionBindTarget,
    QuestionType,
    RouterAnswerRequest,
    RouterCompileRequest,
    RouterResponse,
    RouterRouteRequest,
    RouterStatus,
)
from app.schemas.planner import PlannerQuestion
from app.services.planner_service import PlannerService
from app.services.rag_client import (
    BaseLensRAGClient,
    InMemoryLensRAGClient,
    LensCandidate,
    PgVectorLensRAGClient,
)
from app.services.retrieval_service import RetrievalService, build_task_desc
from app.services.router_graph import invoke_router_v2_graph
from app.services.router_session_store import router_session_store


@dataclass
class _RouterSession:
    """Router 内部使用的简易会话状态，暂存于内存中。"""

    session_id: str
    user_id: str
    original_prompt: str
    base_image: str
    answers: Dict[str, Any] = field(default_factory=dict)


class RouterService:
    """
    负责将用户自然语言意图编译为 DAGBlueprint，或在信息不足时产生追问。

    当前实现采用规则驱动，仅支持 A1 抠图 + A2 局部重绘 的典型管线：
      lens_sam2_matting -> lens_inpaint_bg
    你可以在此基础上逐步引入 LLM 与真实 RAG 逻辑。
    """

    def __init__(
        self,
        rag_client: Optional[BaseLensRAGClient] = None,
        *,
        retrieval: Optional[RetrievalService] = None,
        planner: Optional[PlannerService] = None,
    ) -> None:
        # 简单的内存会话存储，后续可替换为 Redis / 数据库
        self._sessions: Dict[str, _RouterSession] = {}
        # RAG 客户端：默认使用内存版，实现最小可用的“RAG”
        self._rag_client: BaseLensRAGClient = rag_client or InMemoryLensRAGClient()
        self._retrieval = retrieval or RetrievalService(self._rag_client)
        self._planner = planner or PlannerService()

    # ------------------------------------------------------------------
    # 对外主入口
    # ------------------------------------------------------------------
    def compile_or_ask(self, req: RouterCompileRequest) -> RouterResponse:
        """
        根据用户请求尝试生成可执行蓝图；若信息不足则返回追问列表。
        """
        # 1. 会话解析 / 创建
        if req.session_id and req.session_id in self._sessions:
            sess = self._sessions[req.session_id]
            user_prompt = req.user_prompt or sess.original_prompt
            base_image = req.base_image or sess.base_image
        else:
            if not req.user_prompt:
                raise ValueError("新会话必须提供 user_prompt")
            if not req.base_image:
                raise ValueError("新会话必须提供 base_image")
            session_id = str(uuid.uuid4())
            sess = _RouterSession(
                session_id=session_id,
                user_id=req.user_id,
                original_prompt=req.user_prompt,
                base_image=req.base_image,
            )
            self._sessions[session_id] = sess
            user_prompt = req.user_prompt
            base_image = req.base_image

        # 2. 基于规则的“意图解析”与参数提取
        target_obj = self._extract_target_object(user_prompt)
        replace_with = self._extract_replace_object(user_prompt)

        # 3. 透镜检索（RAG）：当前使用内存版实现，后续可平滑替换为 pgvector
        retrieved_lenses: List[LensCandidate] = self._retrieve_lenses(user_prompt)

        # 如果会话中已经有补充答案，则优先采用答案覆盖缺失信息
        if "q_target_object" in sess.answers and not target_obj:
            target_obj = str(sess.answers["q_target_object"])
        if "q_replace_with" in sess.answers and not replace_with:
            replace_with = str(sess.answers["q_replace_with"])

        # 4. 构造步骤草案（当前仍为固定的 A1->A2 管线）
        steps: List[DAGStep] = [
            DAGStep(
                step_id="step_1_matting",
                lens_id="lens_sam2_matting",
                input_links={"base_image": "$user_base_image"},
                params={"prompt": target_obj or ""},
            ),
            DAGStep(
                step_id="step_2_inpaint",
                lens_id="lens_inpaint_bg",
                input_links={
                    "base_image": "$user_base_image",
                    "mask_target": "$step_1_matting.mask_result",
                },
                params={"positive_prompt": replace_with or ""},
            ),
        ]

        questions: List[ClarifyQuestion] = []

        # 若缺少目标物体，生成追问
        if not target_obj:
            questions.append(
                ClarifyQuestion(
                    id="q_target_object",
                    prompt="你想要替换掉画面中的哪个物体？",
                    type=QuestionType.TEXT,
                    options=[],
                    required=True,
                    binds=[
                        QuestionBind(
                            step_id="step_1_matting",
                            lens_id="lens_sam2_matting",
                            target=QuestionBindTarget.PARAM,
                            name="prompt",
                        )
                    ],
                )
            )

        # 若缺少替换目标，生成追问
        if not replace_with:
            questions.append(
                ClarifyQuestion(
                    id="q_replace_with",
                    prompt="你希望替换成什么内容？请用一句话描述。",
                    type=QuestionType.TEXT,
                    options=[],
                    required=True,
                    binds=[
                        QuestionBind(
                            step_id="step_2_inpaint",
                            lens_id="lens_inpaint_bg",
                            target=QuestionBindTarget.PARAM,
                            name="positive_prompt",
                        )
                    ],
                )
            )

        retrieved_ids = [c.lens_id for c in retrieved_lenses]

        # 5. 如有追问，返回 need_clarification
        if questions:
            return RouterResponse(
                session_id=sess.session_id,
                status=RouterStatus.NEED_CLARIFICATION,
                thought_process="根据当前提示词无法完整确定抠图目标或重绘内容，需要向用户补充询问。",
                questions=questions,
                blueprint=None,
                extra={
                    "draft_steps": [s.model_dump() for s in steps],
                    "retrieved_lenses": retrieved_ids,
                },
            )

        # 6. 若信息已经足够，直接生成 Blueprint 并做静态校验
        blueprint = DAGBlueprint(
            initial_inputs={"user_base_image": base_image}, steps=steps
        )
        self._validate_links(blueprint)

        return RouterResponse(
            session_id=sess.session_id,
            status=RouterStatus.READY,
            thought_process=(
                "根据用户的自然语言需求，选择了 A1 抠图透镜 lens_sam2_matting "
                "和 A2 局部重绘透镜 lens_inpaint_bg，并完成了资产连线与参数注入。"
            ),
            questions=[],
            blueprint=blueprint,
            extra={"retrieved_lenses": retrieved_ids},
        )

    def route(self, req: RouterRouteRequest) -> RouterResponse:
        """
        Router v2 的统一入口。

        当前阶段作为薄适配层：
        - 若 answers 非空：转调 answer
        - 否则：将 user_message 映射到现有 compile_or_ask 的 user_prompt
        """
        # 兼容旧签名：若未注入 DB（例如旧调用路径），退回规则版
        return self.route_with_db(req, db=None)

    def route_with_db(self, req: RouterRouteRequest, db: Optional[Session]) -> RouterResponse:
        """
        真正的 Router v2 状态机入口（支持 DB 会话持久化）。

        - db=None 时：退回规则版 compile_or_ask/answer
        - db!=None 时：走 Retrieval + Planner + Validator + SessionStore
        """
        if db is None:
            if req.answers:
                return self.answer(
                    RouterAnswerRequest(session_id=req.session_id or "", answers=req.answers)
                )
            return self.compile_or_ask(
                RouterCompileRequest(
                    user_id=req.user_id,
                    user_prompt=req.user_message,
                    base_image=req.base_image,
                    session_id=req.session_id,
                )
            )
        # Planner 未配置时，退回旧规则版，避免 API 直接变为 FAILED
        if not self._planner.is_configured():
            if req.answers:
                return self.answer(
                    RouterAnswerRequest(session_id=req.session_id or "", answers=req.answers)
                )
            return self.compile_or_ask(
                RouterCompileRequest(
                    user_id=req.user_id,
                    user_prompt=req.user_message,
                    base_image=req.base_image,
                    session_id=req.session_id,
                )
            )

        # --- v2：持久化会话 ---
        try:
            sess = None
            if req.session_id:
                sess = router_session_store.get(db, req.session_id)
            if not sess:
                if not req.user_message:
                    raise ValueError("新会话必须提供 user_message")
                if not req.base_image:
                    raise ValueError("新会话必须提供 base_image")
                sess = router_session_store.create(
                    db,
                    user_id=req.user_id,
                    original_prompt=req.user_message,
                    base_image=req.base_image,
                    base_image_meta=req.base_image_meta,
                )

            # 1) 若本轮有 answers，则写入 collected_params
            collected_params = dict(sess.collected_params or {})
            if req.answers:
                for k, v in req.answers.items():
                    # 约定：问题ID= lens_id.param_name
                    if isinstance(k, str) and "." in k:
                        collected_params[k] = v
                    else:
                        # 兜底：仍保留
                        collected_params[str(k)] = v

            # 2) 构造 task_desc（优先本轮 user_message；无则退回 original_prompt）
            user_message = req.user_message or sess.original_prompt or ""
            task_desc = build_task_desc(
                user_message=user_message, history_summary=sess.history_summary or ""
            )

            # 3+) LangGraph：retrieve → plan → validate →（可选）enrich → plan → finalize
            return invoke_router_v2_graph(
                self,
                db=db,
                sess=sess,
                req=req,
                task_desc=task_desc,
                collected_params=collected_params,
            )
        except Exception as exc:
            return RouterResponse(
                session_id=req.session_id or "",
                status=RouterStatus.FAILED,
                thought_process=f"Router v2 处理失败：{exc}",
                questions=[],
                blueprint=None,
                extra={},
            )

    def answer(self, req: RouterAnswerRequest) -> RouterResponse:
        """
        根据前端提交的追问答案，继续完成 DAG 编译。
        """
        if req.session_id not in self._sessions:
            raise ValueError(f"会话 {req.session_id} 不存在或已过期。")

        sess = self._sessions[req.session_id]

        # 累积保存答案
        sess.answers.update(req.answers)

        # 使用补充的信息重新尝试编译
        compile_req = RouterCompileRequest(
            user_id=sess.user_id,
            user_prompt=sess.original_prompt,
            base_image=sess.base_image,
            session_id=sess.session_id,
        )

        # 重新跑一遍主流程
        resp = self.compile_or_ask(compile_req)

        # 在重新编译前，将答案显式回填到参数中（避免再次触发追问）
        if resp.questions:
            # 如果仍有问题，优先保证不死循环，而是提示前端
            resp.thought_process += "（注意：多轮追问仍未补齐全部关键信息，建议检查规则或输入。）"
            return resp

        # 无需再次追问，直接在 READY 的 blueprint 中应用答案
        if not resp.blueprint:
            return resp

        for qid, val in sess.answers.items():
            if qid == "q_target_object":
                # 回填到第一步抠图的 prompt
                for step in resp.blueprint.steps:
                    if step.step_id == "step_1_matting":
                        step.params["prompt"] = str(val)
            elif qid == "q_replace_with":
                for step in resp.blueprint.steps:
                    if step.step_id == "step_2_inpaint":
                        step.params["positive_prompt"] = str(val)

        # 再次校验
        self._validate_links(resp.blueprint)
        return resp

    # ------------------------------------------------------------------
    # 内部工具方法
    # ------------------------------------------------------------------
    def _retrieve_lenses(self, user_prompt: str) -> List[LensCandidate]:
        """
        使用 RAG 客户端根据自然语言提示词召回候选透镜列表。

        当前实现基于 InMemoryLensRAGClient，后续可以在不改变签名的前提下
        替换为 PgVectorLensRAGClient 或其它实现。
        """
        if not user_prompt:
            return []
        try:
            return self._rag_client.search_lenses(user_prompt, k=5)
        except Exception:
            # 为了 Router 的稳健性，RAG 失败时直接退回空结果，
            # 由后续的固定管线与追问机制兜底。
            return []

    @staticmethod
    def _extract_target_object(text: str) -> Optional[str]:
        """
        从中文自然语言中粗略提取“被替换的目标物体”。
        该实现极为简化，仅作为示例，后续可由 LLM/规则替换。
        """
        # 简单匹配常见物体词
        candidates = ["水杯", "杯子", "茶杯", "玻璃杯"]
        for c in candidates:
            if c in text:
                return c
        return None

    @staticmethod
    def _extract_replace_object(text: str) -> Optional[str]:
        """
        从中文自然语言中粗略提取“希望替换成的内容”。
        """
        # 这里我们示例处理“多肉”一类需求
        if "多肉" in text:
            return "一盆多肉植物"

        # 若出现“换成XXX”结构，尝试简单抽取
        m = re.search(r"换成(.+?)[，。,.]", text)
        if m:
            return m.group(1).strip()

        return None

    @staticmethod
    def _validate_links(blueprint: DAGBlueprint) -> None:
        """
        静态图校验：确保所有以 $ 开头的变量引用都能在
        initial_inputs 或前序步骤的输出变量中找到。

        当前实现利用约定：输出变量键为 f"{step_id}.{output_name}"，
        其中 output_name 对应 LensTemplate.outputs 里的 name。
        由于本 RouterService 目前只关心变量名连线是否自洽，
        不依赖具体的 LensTemplate 输出定义，因此只做名义级别校验。
        """
        available = set(blueprint.initial_inputs.keys())

        for step in blueprint.steps:
            # 校验输入引用
            for _, v in step.input_links.items():
                if not v.startswith("$"):
                    continue
                key = v[1:]
                if key not in available:
                    raise ValueError(
                        f"路由校验失败：步骤 {step.step_id} 引用了不存在的资产变量 '{key}'。"
                    )

            # 将当前步骤的潜在输出变量名加入可用集合
            # 注意：这里我们不强制知道 outputs 列表，而是按照常用约定添加常见名称，
            # 仅作为示例。真实实现应当结合 LensTemplate.outputs 来动态生成。
            available.add(f"{step.step_id}.mask_result")
            available.add(f"{step.step_id}.result_image")

    @staticmethod
    def _to_clarify_questions(items: List[PlannerQuestion]) -> List[ClarifyQuestion]:
        """
        将 PlannerQuestion 转换为 Router 对外的 ClarifyQuestion。
        约定：问题 ID = lens_id.param_name，便于 answer 回填到 collected_params。
        """
        result: List[ClarifyQuestion] = []
        for it in items or []:
            qid = f"{it.param_ref.lens_id}.{it.param_ref.param_name}"
            result.append(
                ClarifyQuestion(
                    id=qid,
                    prompt=it.question_text,
                    type=QuestionType.TEXT,
                    options=list(it.options or []),
                    required=bool(it.required),
                    binds=[
                        QuestionBind(
                            step_id=None,
                            lens_id=it.param_ref.lens_id,
                            target=QuestionBindTarget.PARAM,
                            name=it.param_ref.param_name,
                        )
                    ],
                )
            )
        return result


def _create_rag_client_from_env() -> BaseLensRAGClient:
    """
    根据环境变量决定使用哪种 RAG 后端：
    - MUSELENS_RAG_BACKEND=pgvector 时，使用 PostgreSQL + pgvector；
    - 其它情况（默认）：使用内存版 InMemoryLensRAGClient。

    相关环境变量：
    - MUSELENS_PG_DSN：PostgreSQL 连接串，例如：
      postgresql://user:password@localhost:5432/muselens
    - MUSELENS_RAG_PGVECTOR_TABLE（可选）：向量表名称，默认为 lens_embeddings。
    """
    backend = os.getenv("MUSELENS_RAG_BACKEND", "").lower()
    if backend != "pgvector":
        return InMemoryLensRAGClient()

    dsn = os.getenv("MUSELENS_PG_DSN")
    if not dsn:
        raise RuntimeError(
            "已将 MUSELENS_RAG_BACKEND 设置为 'pgvector'，"
            "但未提供 MUSELENS_PG_DSN 环境变量。"
        )

    table_name = os.getenv("MUSELENS_RAG_PGVECTOR_TABLE", "lens_embeddings")
    return PgVectorLensRAGClient(dsn=dsn, table_name=table_name)


router_service = RouterService(rag_client=_create_rag_client_from_env())

