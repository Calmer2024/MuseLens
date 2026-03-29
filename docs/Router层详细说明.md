# MuseLens Router 层详细说明

本文对 **Router 层**做一次性综合整理：子层划分、已实现能力、核心实现路径、Lens 注册需准备的内容，以及后续改进方向。更细的「意图编排与测试对照」见 [Router层-意图编排与实现对照.md](./Router层-意图编排与实现对照.md)；运行与知识库路径见 [Router架构与Lens知识库指南.md](./Router架构与Lens知识库指南.md)。

---

## 一、Router 层在系统中的位置

- **对外**：HTTP `POST /api/v1/router/route`（及兼容的 `/compile_or_ask`、`/answer`），请求体为 `RouterRouteRequest`，响应为 `RouterResponse`（`ready` / `need_clarification` / `failed`）。
- **对内**：在用户自然语言与 **可执行的 DAGBlueprint（多 Lens 串联）** 之间做桥梁；不负责真正调 ComfyUI 跑图（那是 Compiler / Comfy 层）。
- **依赖**：PostgreSQL（Lens 目录表、会话表）、可选 pgvector（语义召回）、OpenAI 兼容 LLM（Planner）、内存/磁盘上的 Lens 注册表与工作流 JSON。

---

## 二、细分小层（从下到上）

Router 主路径（**Router v2**）不是单一函数，而是由下列模块协作：

| 小层 | 模块（代码入口） | 职责 |
|------|------------------|------|
| **会话持久化** | `router_session_store`、`RouterSessionRecord` | 创建/读取 `router_sessions` 行，保存 `collected_params`、`pending_blueprint`、`pending_questions`、`lens_history` 等，支撑多轮。 |
| **RAG 召回** | `rag_client`：`InMemoryLensRAGClient` / `PgVectorLensRAGClient` | 根据 `task_desc` 做 Top-K **lens_id** 召回（关键词相似度或向量）。 |
| **检索拼装（Catalog）** | `RetrievalService` | 用召回的 id 查 **`lenses` / `lens_examples` 表**，合并可选的 **`load_lens_doc`（`*.md`）**，输出 **`LensKnowledge` 列表** 给 Planner。 |
| **智能编排** | `PlannerService` | 调用 LLM（OpenAI 兼容 `chat/completions` + tool），在 **候选 Lens 集合** 内产出 **`PlannerOutput`**：`DAGBlueprint`、`missing_params`、`clarification_questions`。 |
| **图编排运行时** | `router_graph`（LangGraph） | 固定流水线：`retrieve → plan → validate →（条件）enrich → plan → finalize`。 |
| **静态校验** | `BlueprintValidator` | 校验 step 引用、`lens_id` 存在性、参数名与类型、与 `collected_params` 等。 |
| **规则兜底（旧路径）** | `RouterService.compile_or_ask` / `answer` | 当 **未配置 LLM**（`PlannerService.is_configured()` 为假）时，退回关键词规则管线（如 A1+A2 固定模板），不跑 LangGraph v2。 |

**编排协调者**在代码上体现为 **`RouterService.route_with_db`**：有 DB 且 Planner 已配置时走 **LangGraph**；否则走规则路径。

---

## 三、已实现功能（能力清单）

| 能力 | 说明 |
|------|------|
| **统一路由入口** | `POST /api/v1/router/route`：新会话带 `user_message` + `base_image`；追问轮次带 `session_id` + `answers`（键一般为 `lens_id.param_name`）。 |
| **检索 → Planner → 校验** | LangGraph 多节点；`task_desc` 由 `build_task_desc` 组装（用户句 + 可选历史摘要）。 |
| **pgvector / 内存 RAG** | 环境变量 `MUSELENS_RAG_BACKEND=pgvector` 时使用 `PgVectorLensRAGClient` + `MUSELENS_PG_DSN`；否则内存版。 |
| **Catalog 补全** | 召回 id 后从 DB 拉描述、params、examples；可选叠加 **`app/lenses/docs/<lens_id>.md`**（YAML frontmatter）。 |
| **Enrich 再规划** | Planner 若报缺失或校验提示缺信息，可按 lens_id **再拉全量 LensKnowledge**，**最多再 plan 一次**。 |
| **多轮追问** | `PlannerOutput` 的 `clarification_questions` / `missing_params` 映射为对外 `questions`；会话字段持久化。 |
| **无 blueprint 但需追问** | `finalize` 将「仅有追问、尚无蓝图」与「真失败」区分（见 `router_graph._node_finalize`），避免一律 `failed`。 |
| **Lens CRUD** | `POST /api/v1/lenses/register` 等；注册时可触发 **向量表同步**（pgvector 场景）。 |
| **规则兜底** | 无 API Key/模型时仍可用固定中文规则生成简单 DAG（与 v2 行为不同）。 |

---

## 四、核心功能如何实现（主路径数据流）

### 4.1 LangGraph 流水线（Router v2）

1. **retrieve**  
   - `RetrievalService.retrieve(db, task_desc=...)`  
   - 内部：`rag_client.search_lenses` → 得到有序 `lens_id` → 查表 → `_lens_knowledge_from_record`（含 `load_lens_doc`）→ `List[LensKnowledge]` → 序列化为 `candidates_payload`。

2. **plan**  
   - 构造 `PlannerInput`：`task_desc`、`base_image_meta`、`candidates`、`session_context`（含 `collected_params`、pending 等）。  
   - `PlannerService.plan`：`POST {base_url}/chat/completions`，要求通过 **tool** 返回符合 `PlannerOutput` 的 JSON。

3. **validate**  
   - 若有 `blueprint`，`BlueprintValidator.validate` 收集错误列表。

4. **条件 enrich**  
   - 若 Planner 仍缺信息或校验失败，且尚未 enrich，则从 `planner_out` 抽取相关 `lens_id`，`retrieve_by_lens_ids` 补全候选，**再回到 plan**。

5. **finalize**  
   - 综合 `blueprint`、校验错误、追问列表，产出 `RouterResponse`（`READY` / `NEED_CLARIFICATION` / `FAILED`），并更新 `router_sessions`。

### 4.2 Planner 的约束（与「只从候选里选 Lens」）

- System/User prompt 要求：**不得臆造 `lens_id`**，参数名必须来自候选 schema。  
- 实现上依赖 **Retrieval** 提供的 `candidates` 足够覆盖业务 Lens；**pgvector 语料**目前主要来自注册表模板 + DB examples（见 `lens_embedding_sync._build_lens_corpus`），**不**自动包含整篇 `*.md` 正文；但 **Planner 侧**在召回后会读到 **合并后的 LensKnowledge（含 md 叠加）**。

### 4.3 会话与追问键

- 追问 ID 约定：`lens_id.param_name`，与 `collected_params` 回填一致。  
- 持久化表：`router_sessions`（见 `RouterSessionRecord`）。

---

## 五、Lens 注册需要写什么内容

注册分 **三部分**：**API 必填结构**、**可选 Markdown 文档**、**运行与向量（pgvector）**。

### 5.1 `POST /api/v1/lenses/register` 请求体（必填/常用字段）

| 字段 | 含义 |
|------|------|
| `lens_id` | 全局唯一 ID，如 `lens_inpaint_bg`。 |
| `layer` | 层级字符串，如 `A1`～`A5`（与产品分层一致）。 |
| `description` | 短描述，供检索与 LLM 理解用途。 |
| `workflow_file_path` | **本机可读的** ComfyUI 导出 JSON 路径（相对 `backend` 或绝对路径）；**必须真实存在**，否则注册会失败。 |
| `inputs` | 资产槽：每项含 `name`、`type`、`mapping`（`node_id` + `field_name` 对应工作流 JSON 里的节点与输入字段）。 |
| `outputs` | 输出资产，结构同 `inputs`。 |
| `params` | 可调参数：每项含 `name`、`type`、`description`（强烈建议写清，供 Planner）、`mapping`。 |
| `examples`（可选） | `nl_desc` + `params_example`，写入 `lens_examples` 表，进入 Retrieval 与向量同步语料。 |

Pydantic 定义见：`backend/app/api/v1/endpoints/lenses.py` 中 `LensRegisterRequest` 及子模型。

### 5.2 可选：`backend/app/lenses/docs/<lens_id>.md`

- 用于 **参数级规则**（`decision_rules`、`format_rules`）、**长说明**、**与 DB 叠加的 examples**。  
- 详细字段与叠加策略见：[backend/app/lenses/docs/LENS_DOC_FORMAT.md](../backend/app/lenses/docs/LENS_DOC_FORMAT.md)。

### 5.3 pgvector 场景

- 注册成功后，若 `MUSELENS_RAG_BACKEND=pgvector` 且配置了 `MUSELENS_PG_DSN`，会尝试 **同步该 lens 的向量**（见 `lenses` 端点内 `sync_lens_embeddings` 调用）。  
- 全量同步也可用：`python -m app.scripts.sync_lens_embeddings_cli`（在 backend 环境、变量齐全时）。

---

## 六、后续可改进方向（与现状差距）

| 方向 | 说明 |
|------|------|
| **向量语料与文档一致** | 当前 embedding 主用 registry + examples；若希望「整篇 md 参与召回」，需在 `lens_embedding_sync` 中扩展 `_build_lens_corpus`（或单独 chunk）。 |
| **Planner 提示词与模型差异** | 不同网关对 **tool_calls** 支持不一；需持续对齐 SiliconFlow/OpenAI 的返回解析与失败重试。 |
| **仅 thought、无结构化追问** | 若模型只在 `thought` 里写散文、不填 `clarification_questions`/`missing_params`，前端仍拿不到 `questions`；需提示词约束或服务端从文本兜底（谨慎）。 |
| **规则路径与 v2 行为统一** | 未配置 LLM 时走规则管线，产品需明确区分或逐步下线规则路径。 |
| **会话过期与清理** | `router_sessions` 增长策略、TTL、与产品会话对齐。 |
| **观测与调试** | 结构化日志（retrieve 的 lens 列表、Planner 原始响应、校验错误码），便于排障。 |

---

## 七、相关代码与文档索引

| 资源 | 路径 |
|------|------|
| 路由入口 | `backend/app/api/v1/endpoints/router.py` |
| Router 服务 | `backend/app/services/router_service.py` |
| LangGraph | `backend/app/services/router_graph.py` |
| Planner | `backend/app/services/planner_service.py` |
| 检索 | `backend/app/services/retrieval_service.py` |
| RAG 客户端 | `backend/app/services/rag_client.py` |
| 校验 | `backend/app/services/blueprint_validator.py` |
| 会话存储 | `backend/app/services/router_session_store.py` |
| Lens 文档加载 | `backend/app/services/lens_docs_service.py` |
| 意图编排对照（长文） | [Router层-意图编排与实现对照.md](./Router层-意图编排与实现对照.md) |

---

*文档随代码演进可继续增补；若接口或 `finalize` 行为变更，请同步更新本节「已实现功能」与「主路径数据流」。*
