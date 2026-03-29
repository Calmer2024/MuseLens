## MuseLens 开发日志 · Router 阶段 2

### 一、本阶段目标与完成情况

- **目标**：在 Router 阶段 1 的基础上，为 Router 引入**可替换的 RAG 客户端抽象**，并提供一个开箱即用的默认实现，用于支持：
  - 通过统一接口 `BaseLensRAGClient` 召回与自然语言需求相关的透镜候选；
  - 默认使用内存中的 `LENS_REGISTRY` 做「伪 RAG」，保证在**无数据库 / 无向量服务**的环境下也能工作；
  - 为后续接入 PostgreSQL + pgvector 等真实向量检索方案预留清晰扩展点。
- **当前完成度**：
  - 新增 `RAG` 客户端模块 `rag_client.py`，定义了：
    - `BaseLensRAGClient`：Router 依赖的检索协议接口（`search_lenses`）；
    - `LensCandidate`：透镜召回结果的数据结构；
    - `InMemoryLensRAGClient`：基于 `LENS_REGISTRY` 的内存检索实现；
    - `PgVectorLensRAGClient`：PostgreSQL + pgvector 版本的实现骨架。
  - 对 `RouterService` 进行重构，使其**不再直接依赖具体的 RAG 实现**，而是通过 `BaseLensRAGClient` 抽象进行交互；
  - 为新引入的 RAG 客户端与 Router 行为补充了单元测试（`test_rag_client.py` / `test_router_service.py`），并在 `Muselens` conda 环境下通过 `pytest` 全部跑通（当前统计：4 个用例通过，1 条 Pydantic 警告，不影响功能）。

> 结论：Router 阶段 2 的核心开发工作（RAG 抽象、默认实现与测试）已经完成，当前代码在 `Muselens` 环境下通过全部相关单测，可以作为后续接入真实向量数据库与 LLM 的稳定基线。

---

### 二、RAG 客户端模块设计（`backend/app/services/rag_client.py`）

#### 1. 核心数据结构与抽象接口

- **`LensCandidate`**
  - 字段：`lens_id: str` / `score: float` / `template: LensTemplate`
  - 作为 RAG 召回结果的统一载体，便于 Router 与后续策略逻辑使用。

- **`BaseLensRAGClient` (Protocol)**
  - 方法签名：`search_lenses(self, query_text: str, k: int = 5) -> List[LensCandidate]`
  - 约束：Router 仅依赖此接口，而不关心具体 RAG 实现的存储介质与召回算法；
  - 作用：为将来替换为 pgvector / 远程检索服务 / LLM 检索代理提供清晰的插拔点。

#### 2. 内存实现：`InMemoryLensRAGClient`

- **设计目的**：
  - 不依赖任何外部数据库或向量服务，在仅有 `LENS_REGISTRY` 的情况下即可工作；
  - 作为 Router 的默认 RAG 依赖与单元测试的轻量实现。
- **主要行为**：
  - 初始化：接受一个可选的 `registry: Dict[str, LensTemplate]`，默认使用全局 `LENS_REGISTRY`；
  - `search_lenses(query_text, k)`：
    - 使用 `_tokenize` 对自然语言 query 做极简分词（中英文标点归一为空格，再按空白切分，小写化）；
    - 遍历 Registry 中所有 `LensTemplate`，调用 `_score_template(tokens, tmpl)` 计算一个非常粗糙的「词袋重叠得分」；
    - 按得分从高到低排序，返回前 `k` 个 `LensCandidate`。
- **打分策略 `_score_template`（示例版实现）**：
  - 将 `tmpl.description`、`tmpl.lens_id`、`tmpl.layer.value` 及各参数的 `name`、`description` 拼接为一个大串；
  - 对每个 query token，只要在拼接后的文本中出现一次，就累加 1 分；
  - 该策略刻意保持简单，仅用于示例与测试，后续可以替换为 TF-IDF / 向量相似度等更强方案。

#### 3. pgvector 实现骨架：`PgVectorLensRAGClient`

- **设计目标**：
  - 为接入 PostgreSQL + pgvector 向量数据库提前定义一个可用的类接口；
  - 避免在尚未安装驱动或配置数据库时阻塞整个后端启动。
- **关键设计点**：
  - 构造函数参数：
    - `dsn: str`：数据库连接串；
    - `table_name: str = "lens_embeddings"`：存储透镜向量的表名；
    - `top_k: int = 5`：默认召回数量；
    - `encode_text_to_vector`：外部注入的文本编码函数，负责将 query 转为向量。
  - `search_lenses(query_text, k)` 行为：
    - 若未提供 `encode_text_to_vector`，直接抛出 `RuntimeError`，提示必须接入实际的 embedding 服务；
    - 在方法内部**延迟导入** `psycopg`，避免在模块导入阶段因缺少依赖而失败；
    - 使用 pgvector 特性构造 SQL，按向量相似度（`<->` / `<=>`）排序并限制返回条数；
    - 将查询结果映射为 `LensCandidate` 列表，并与本地 `LENS_REGISTRY` 进行对齐，确保只返回在 Registry 中存在的透镜。

---

### 三、RouterService 与 RAG 的解耦改造（`backend/app/services/router_service.py`）

#### 1. 构造函数注入 RAG 客户端

- 原本的 RouterService 仅依赖规则与固定的透镜序列，本阶段引入了对 RAG 客户端的依赖注入：
  - `__init__(self, rag_client: Optional[BaseLensRAGClient] = None)`：
    - 若未显式传入，则默认构造 `InMemoryLensRAGClient`；
    - 对外暴露统一接口，允许在生产环境中传入 `PgVectorLensRAGClient` 或其它自定义实现。

#### 2. 透镜召回流程 `_retrieve_lenses`

- 新增方法 `_retrieve_lenses(self, user_prompt: str) -> List[LensCandidate]`：
  - 若 `user_prompt` 为空，直接返回空列表；
  - 使用当前注入的 `self._rag_client.search_lenses(user_prompt, k=5)` 做召回；
  - 为保证 Router 稳健性，捕获所有异常并退回空列表（由固定管线与追问机制兜底）。
- `compile_or_ask` 中的变化：
  - 在规则解析之后，会调用 `_retrieve_lenses(user_prompt)` 获取 `retrieved_lenses`；
  - 将召回到的 `lens_id` 列表放入 `RouterResponse.extra["retrieved_lenses"]`，便于调试与前端可视化。

> 通过这一步改造，Router 的「意图解析 + DAG 组装」与「透镜召回策略」实现了解耦，可以在不修改 Router 主逻辑的前提下替换 RAG 实现。

---

### 四、测试与验证（`backend/tests/test_rag_client.py` 等）

#### 1. 新增测试

- **`backend/tests/test_rag_client.py`**（本阶段新增）：
  - 针对 `InMemoryLensRAGClient` 的基本行为做了覆盖，例如：
    - 在给定简单中文提示词的情况下，能够根据 `LENS_REGISTRY` 中的描述/参数匹配出预期透镜；
    - 空字符串或无匹配场景下返回空列表或低分结果；
    - 限制返回数量 `k` 的行为正确。

- **`backend/tests/test_router_service.py`**（在阶段 1 的基础上保持/调整）：
  - 确认在注入默认 `InMemoryLensRAGClient` 后：
    - `compile_or_ask` 的 READY / NEED_CLARIFICATION 流程仍然符合预期；
    - `RouterResponse.extra["retrieved_lenses"]` 中包含合理的透镜 ID 列表。

#### 2. 实际运行结果

- 在 `Muselens` conda 环境中，按照如下方式执行（示例）：

```bash
conda activate Muselens
cd backend
pytest -q
```

- 当前结果：
  - **4 个测试用例全部通过**（包括 Router 与 RAG 客户端相关用例）；
  - 存在 1 条来自 `app/schemas/router.py` 的 Pydantic 警告（`ClarifyQuestion.schema` 字段名与 `BaseModel` 属性同名），不影响功能与本阶段目标，如有需要可在后续重构时统一更名。

---

### 五、阶段小结与后续规划

- **阶段小结**
  - 已完成 Router 与 RAG 能力的抽象隔离，引入 `BaseLensRAGClient` 协议与 `InMemoryLensRAGClient` 默认实现；
  - 为 pgvector 版本 RAG 预留了清晰的实现骨架 `PgVectorLensRAGClient`，并通过延迟导入与显式依赖注入的方式避免对当前开发环境造成侵入；
  - 对新增模块与 Router 行为补充了单元测试，并在标准开发环境中完成了一轮 pytest 验证。

- **后续规划（面向 Router 阶段 3 及以后）**
  1. 落地 PostgreSQL + pgvector 实际存储与召回逻辑，并将 `PgVectorLensRAGClient` 从骨架升级为可用实现；
  2. 在 Router 中引入 LLM（例如通过 OpenAI / Azure / 本地大模型）完成更智能的意图解析与透镜编排；
  3. 完善评测与监控：
     - 为 RAG + Router 建立离线评测集与指标（召回率、匹配准确度、用户满意度）；
     - 增加日志与可观测性，便于调试召回结果与路由决策。

本文档作为「Router 阶段 2」的开发记录，配合 `docs/开发日志-Router阶段1.md` 一起，形成从规则版 Router 到抽象化 RAG 架构的连续演进日志，便于团队成员理解当前能力边界与后续迭代方向。

