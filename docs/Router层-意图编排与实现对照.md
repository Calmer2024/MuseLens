# Router 层：意图编排设计说明与实现对照

本文面向 **Router 作为「有思考能力的编排协调者」** 的定位，按「检索、推理、会话」分离的思路展开；并与 **当前 MuseLens 后端实现** 对照标注——**已实现**、**部分实现**、**规划/未实现**，避免与「仅关键词抽取 + 向量匹配」的简化方案混淆。

> **相关文档**  
> - 运行方式、接口索引、知识库文件路径： [Router架构与Lens知识库指南](./Router架构与Lens知识库指南.md)  
> - pgvector 与向量同步： [RAG_pgvector 接入与扩展指南](./RAG_pgvector%20接入与扩展指南.md)  
> - 单透镜 md 格式： [backend/app/lenses/docs/LENS_DOC_FORMAT.md](../backend/app/lenses/docs/LENS_DOC_FORMAT.md)

---

## 〇、测试是否覆盖数据库？如何复现？

### 0.1 默认 `pytest` 测的是什么？

- **会测到数据库访问路径**：大量用例在 **`SQLite :memory:`** 上执行，启动时 `Base.metadata.create_all()` 建表，与生产相同的 **SQLAlchemy ORM + 会话提交** 逻辑。  
- 涉及表包括但不限于：`lenses`、`lens_examples`、`router_sessions` 等（取决于用例）。连接常用 **`StaticPool`**，避免多线程下内存库不可见问题。  
- 因此：**不是「纯 mock 掉 DB」**，而是 **在内存数据库里跑通真实 CRUD + Router/Retrieval 链路**（Planner 多用 `MockPlannerService` 避免真 LLM）。

### 0.2 与 PostgreSQL / pgvector / 真 LLM 的差异

| 类型 | 说明 |
|------|------|
| **PostgreSQL 集成** | `test_postgres_backend_integration.py` 等需在环境中设置 **`MUSELENS_TEST_POSTGRES_DSN`**，否则 **skip**。 |
| **pgvector 端到端** | 如 `test_pgvector_retrieval_e2e.py` 需 **`MUSELENS_PG_DSN`** 等，未配置则 **skip**。 |
| **真实 Planner LLM** | `test_planner_service_real_llm.py` 需 **`MUSELENS_TEST_REAL_LLM=1`** 等，默认 **skip**。 |

### 0.3 推荐复现命令（与你本地 Muselens 环境一致）

在仓库 **`backend` 目录下**执行（保证能 `import app`）：

```bash
conda activate Muselens
cd backend
python -m pytest tests/ -q
```

查看 **skip 原因**：

```bash
python -m pytest tests/ -q -rs
```

使用 **Docker** 启动带 PostgreSQL 的后端联调，见根目录 `docker-compose.backend.yml` 与 [后端Docker一键启动说明](./后端Docker一键启动说明.md)。

---

## 一、定位：不再是「_extract_xxx + 向量匹配」

### 1.1 目标形态

- **Router** 不负责「猜几个正则、抽槽位再硬编码管线」，而是：在 **会话上下文** 下，协调 **检索（RAG）→ 智能编排（Planner / LLM）→ 静态校验**，必要时 **补全候选知识（enrich）** 与 **多轮追问**。  
- **追问** 由 **参数是否齐备 / Planner 是否仍不确定** 驱动（`missing_params`、`clarification_questions`、校验器对必填参数的检查），**不是**简单判断「有没有 prompt / 有没有图」——尽管规则兜底路径里仍可能存在这类启发式（见 §8）。  
- **与数据库、向量库结合**：Catalog 存在关系库；候选 Lens 由 RAG（内存或 **pgvector**）召回，再拼 **结构化 LensKnowledge** 给 Planner。

### 1.2 当前实现摘要（Router v2）

- **主路径**：`RouterService.route_with_db` 在具备 **DB + 已配置 Planner** 时，走 **[LangGraph](../backend/app/services/router_graph.py) 编排**：  
  `retrieve → plan → validate →（条件）enrich → plan → finalize`。  
- **Planner**：OpenAI 兼容 API，`PlannerService` 用 **工具调用** 约束输出为 `PlannerOutput`（含 `DAGBlueprint`、`missing_params`、`clarification_questions`）。  
- **校验**：`BlueprintValidator` 检查 DAG 引用、Lens 是否存在、`collected_params` 与必填参数等。

---

## 二、整体分层：把「检索、推理、会话」拆开

下面四层与 **当前代码模块** 对应；**加粗**为理想中可进一步拆分的表结构，括号内为 **实现现状**。

### 1）Lens Catalog & 存储层（结构化 + 可选向量）

| 理想组件 | 作用 | 实现现状 |
|----------|------|----------|
| **Lens 主表**（id、描述、层级、工作流路径等） | 权威元数据 | **`lenses` 表** [`LensRecord`](../backend/app/models/lens_model.py)，`params` 为 **JSON 数组**（非独立 `lens_param` 表，信息等价、查询方式不同） |
| **参数 schema** | Planner/校验依据 | 存于 `lenses.params` JSON；**可选** [`<lens_id>.md`](../backend/app/lenses/docs/LENS_DOC_FORMAT.md) **frontmatter 叠加** required/default/description |
| **few-shot 示例** | `LensKnowledge.examples` | **`lens_examples` 表**（注册 API 写入）；与 md 中 `examples` 合并进 Retrieval |
| **语义向量** | pgvector Top-K | 表 **`lens_embeddings`**（见 RAG 指南），由同步脚本维护；**默认 RAG 为内存版**，配置后可切 **pgvector** |

### 2）Retrieval 层（只做「找知识」）

- **职责**：根据 `task_desc`（用户意图 + 可选 `history_summary`）召回 **候选 Lens**，并拼 **结构化候选列表**（schema + examples），**不做**最终选路与填参。  
- **实现**：[`RetrievalService`](../backend/app/services/retrieval_service.py) —— RAG 取 `lens_id` → 读 `lenses` / `lens_examples` / 可选 md → 输出 [`LensKnowledge`](../backend/app/schemas/retrieval.py) 列表，序列化后作为 Planner 的 `candidates`。  
- **enrich**：[`retrieve_by_lens_ids`](../backend/app/services/retrieval_service.py) 在 Planner 已暴露缺失或校验需要时，**按 id 精确补全**同一套结构化知识，**不再走向量召回**。

### 3）Planning & Parameter Filling 层（LLM 智能编排器）

- **职责**：在 **仅允许使用 candidates 内 lens_id / 参数名** 的约束下，产出 DAG、`missing_params`、自然语言追问等。  
- **实现**：[`PlannerService`](../backend/app/services/planner_service.py)；输入输出为 [`PlannerInput` / `PlannerOutput`](../backend/app/schemas/planner.py)。  
- **本质**：RAG 提供「说明书」，LLM 做「选模块 + 拓扑 + 填参/标缺失」，与「仅向量最近邻」不同。

### 4）Router 层（协调者 + 会话 + 校验）

- **职责**：会话读写、构造 `task_desc` 与 `PlannerInput.session_context`、触发 Retrieval 与 Planner、**静态校验**、持久化 `pending_*` / `collected_params`、组装 `RouterResponse`。  
- **实现**：[`RouterService`](../backend/app/services/router_service.py) + [`router_graph`](../backend/app/services/router_graph.py) + [`router_session_store`](../backend/app/services/router_session_store.py) + [`blueprint_validator`](../backend/app/services/blueprint_validator.py)。

---

## 三、Router 对外的输入 / 输出抽象

### 3.1 HTTP 统一入口（实现）

- 前缀 **`/api/v1/router`**。  
- **推荐**：`POST /route`，请求体 [`RouterRouteRequest`](../backend/app/schemas/router.py)：`session_id`、`user_message`、`base_image`、`base_image_meta`、`answers` 等。  
- 兼容：`/compile_or_ask`、`/answer` 内部转为 `RouterRouteRequest`。  
- 响应 [`RouterResponse`](../backend/app/schemas/router.py)：`status` ∈ `need_clarification` | `ready` | `failed`，含 `questions`、`blueprint`、`thought_process`、`extra` 等。

与理想设计的差异多为 **命名**（如 `failed` vs `ERROR`）及 **调试字段** 是否单独 `debug`——当前可把 `extra` / `thought_process` 作调试信息。

### 3.2 Router 是否执行 Lens？

- **否**。Router 只产出可执行的 **`DAGBlueprint`**（或追问）；执行由编译器/执行器其它模块完成（与本文范围无关）。

---

## 四、会话管理：Session State 设计

持久化模型 [`RouterSessionRecord`](../backend/app/models/router_session_model.py) 表 **`router_sessions`**，与理想 SessionState 对应关系如下：

| 理想字段 | 实现字段 |
|----------|----------|
| `session_id` | `session_id` |
| `user_id` | `user_id` |
| `original_prompt` | `original_prompt` |
| `base_image` / `base_image_meta` | `base_image`、`base_image_meta`（JSON） |
| `history_summary` | `history_summary`（可由后续摘要服务写入） |
| `lens_history` | `lens_history`（JSON 列表） |
| `pending_blueprint` | `pending_blueprint` |
| `pending_questions` | `pending_questions` |
| `collected_params` | `collected_params`，键约定 **`lens_id.param_name`** |

每轮请求：**有 `session_id` 则加载**；否则校验 `user_message` + `base_image` **创建新会话**。

---

## 五、Router 一轮处理流程（状态机 / LangGraph）

与实现 **[LangGraph](../backend/app/services/router_graph.py)** 对齐的高层步骤：

1. **加载 / 更新会话**：合并本轮 `answers` → `collected_params`。  
2. **构造 `task_desc`**：`build_task_desc(user_message, history_summary)`。  
3. **retrieve**：Retrieval → `candidates`。  
4. **plan**：`PlannerInput`（含 `session_context`：`collected_params`、`pending_questions`、`lens_history`、`previous_blueprint`）。  
5. **validate**：`BlueprintValidator`。  
6. **条件 enrich**：若存在缺失/追问/校验问题等且尚未 enrich，则 `retrieve_by_lens_ids` 后 **再 plan 一次**（当前实现为 **最多一轮** enrich）。  
7. **finalize**：`READY` / `NEED_CLARIFICATION` / `FAILED`，并更新 `router_sessions`。

**无 DB 或未配置 Planner** 时：退回 **规则版** `compile_or_ask` / `answer`（关键词 + 固定管线），用于兼容与测试。

---

## 六、层间契约（数据结构）

### 6.1 Router → Retrieval

- 代码级：`RetrievalService.retrieve(db, task_desc=..., top_k=5)`；**filters / enabled_only** 等参数在部分签名中预留，可按产品迭代收紧候选规模（大规模 Lens 场景见 §9）。  
- 输出：`List[LensKnowledge]` → `candidates` 字段为 **Pydantic `model_dump()` 列表** 进入 Planner。

### 6.2 Router → Planner

- [`PlannerInput`](../backend/app/schemas/planner.py)：`task_desc`、`base_image_meta`、`candidates`、`session_context`。  
- [`PlannerOutput`](../backend/app/schemas/planner.py)：`blueprint`、`missing_params`、`clarification_questions`、`thought`。  
- 蓝图结构为项目内 [`DAGBlueprint`](../backend/app/schemas/lens.py)（步骤 `DAGStep`、资产引用 `$step_id.output` 等），与「PipelineBlueprint」概念一致，命名随代码。

### 6.3 Router → Blueprint Validator

- [`BlueprintValidator.validate(db, blueprint, collected_params=...)`](../backend/app/services/blueprint_validator.py)：Lens 是否存在、资产引用、参数名与类型、Catalog **required** 与 `collected_params` 等。  
- 返回：`List[ValidationError]`（非理想中的 `VALID|INVALID` 枚举，语义等价）。

---

## 七、追问机制：参数驱动，而非「有没有 prompt」

### 7.1 设计意图

- **Planner** 声明 **`missing_params` / `clarification_questions`**，表示「参数未填满或不确定」。  
- **校验器** 对 Catalog 级 **required** 参数与 `collected_params` 做检查，与 Planner 声明互补。  
- Router 将追问以 [`ClarifyQuestion`](../backend/app/schemas/router.py) 返回，并持久化 **`pending_blueprint` / `pending_questions`**。

### 7.2 用户回答如何写回？（实现现状）

- 前端在后续请求中带 **`answers`: `{ "lens_id.param_name": 值 }`**。  
- Router **直接合并**到 `collected_params`，**不经过**单独的「轻量 LLM 分类器」把自然语言拆到各参数（你原文 §七.3 所述能力为 **可选增强，当前未实现**）。  
- 若未来引入「只发一段自由文本回答多问」，可增加 **Router 前置小模型** 或 **结构化表单** 强制一问一答，二者择一即可与现有 `collected_params` 衔接。

---

## 八、规则兜底路径（避免与 v2 混淆）

- 当 **`db is None`** 或 **Planner 未配置** 时：`compile_or_ask` 仍可能使用 **`_extract_target_object` 等简单规则**与固定步骤——这是 **兼容层**，不是 Router v2 的主形态。  
- 文档对外说明「智能编排」时，应默认指 **DB + Planner + LangGraph** 路径。

---

## 九、Lens 很多 / 会话多轮时的扩展性

| 方向 | 说明 |
|------|------|
| **候选规模** | 提高 `top_k` 与向量质量、在 Retrieval 增加 **过滤**（enabled、layer、版本）与 **两阶段检索**；当前基线为单阶段 Top-K + LLM 在 candidates 内取舍。 |
| **多轮会话** | `session_context` 已携带 `lens_history`、`previous_blueprint`、`pending_questions`；Planner 可据此选择「增量追加」或「重排」——**策略在 Prompt 与模型，Router 只传上下文**。 |
| **enrich** | 首轮候选不足时 **按 lens_id 补全 schema/examples**，缓解「向量召回到 id 但 Catalog 展示不全」问题。 |

---

## 十、Lens「知识库」示例写法（给编排器看的材料）

知识库 = **结构化 Catalog** + **可选向量** + **文本叠加层** + **few-shot**。推荐同时维护以下三类（与 [Router架构与Lens知识库指南](./Router架构与Lens知识库指南.md) 一致）。

### 10.1 注册 API 中的 `params` + `examples`（必会进库）

```json
{
  "lens_id": "lens_demo_inpaint",
  "layer": "A2",
  "description": "按提示词对指定区域重绘",
  "workflow_file_path": "your_workflow.json",
  "inputs": [...],
  "outputs": [...],
  "params": [
    {
      "name": "positive_prompt",
      "type": "text",
      "description": "希望生成的主体或场景描述，需具体到可执行",
      "mapping": { "node_id": "1", "field_name": "text" }
    }
  ],
  "examples": [
    {
      "nl_desc": "把背景换成海边日落，人物不变",
      "params_example": { "positive_prompt": "sunset beach, cinematic lighting, keep subject" }
    }
  ]
}
```

### 10.2 可选 Markdown：`backend/app/lenses/docs/<lens_id>.md`

用于叠加 **必填、默认值、追问规则、额外 examples**，格式见 [LENS_DOC_FORMAT.md](../backend/app/lenses/docs/LENS_DOC_FORMAT.md)。**最小示例**：

```yaml
---
lens_id: lens_demo_inpaint
layer: A2
description: |
  对遮罩区域做 inpaint，需明确的 positive_prompt。
params:
  positive_prompt:
    description: "具体描述期望画面，避免空泛词"
    required: true
    decision_rules: |
      若用户只说「改好看」而未给出画面内容，应标记为 missing。
examples:
  - nl_desc: "把杯子换成多肉"
    params_example:
      positive_prompt: "potted succulents on table"
---
正文可写故障排查、与其它 Lens 的衔接说明。
```

### 10.3 向量侧（可选）

- 配置 pgvector 后，对 Lens 描述与 schema 文本做 embedding 写入 **`lens_embeddings`**，供 `PgVectorLensRAGClient` 使用；流程见 [RAG_pgvector 接入与扩展指南](./RAG_pgvector%20接入与扩展指南.md)。

---

## 十一、总结：Router 实现要点（对照你的目标）

| 要点 | 实现情况 |
|------|----------|
| Router 做流程控制 + 会话 + 校验，「选 Lens / 排 DAG / 填参 / 提问」主要在 Planner | **已落实**（+ LangGraph 编排 enrich 重试） |
| 追问围绕参数完整性与 Planner 不确定性 | **已落实**（+ 校验器 required） |
| 四层分工：Catalog / Retrieval / Planner / Router | **已落实**（Catalog 表结构与理想「多表」有差异，见 §二） |
| 与向量库、DB 深度结合 | **已落实**（pgvector 可开关；默认内存 RAG 便于开发） |
| 用户自由文本 → 多参数映射的小 LLM | **未实现**；当前为 **结构化 `answers` 键** |
| 大规模 Lens 的过滤与多阶段检索 | **部分预留**（`top_k`、enabled 等），产品化时可加强 |

---

*若仅保留一份对外总览，可继续维护 [Router架构与Lens知识库指南](./Router架构与Lens知识库指南.md)；本文侧重「意图编排设计 + 实现对照 + 测试复现 + 知识库示例」。*
