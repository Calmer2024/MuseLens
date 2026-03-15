## MuseLens 开发日志 · Router 阶段 3

### 一、本阶段目标与完成情况

- **目标**：在 Router 阶段 2 的基础上，完成 **PostgreSQL + pgvector 的 RAG 接入**与 **透镜配置扩展**，并建立本阶段的全面自动化测试，具体包括：
  - 将 Lens 语料编码为向量并同步到 pgvector 表，支持「新增透镜配置 + 重跑同步」即可扩展；
  - Router 通过环境变量在「内存版 RAG」与「pgvector 版 RAG」之间切换；
  - 新增若干透镜配置（A1 深度图、A1 抠图、A2 局部重绘），并纳入 LENS_REGISTRY；
  - 对 RAG 客户端、透镜同步服务、Router、透镜注册表进行完整的单元/集成级测试。
- **当前完成度**：
  - 实现了 **Lens 向量同步服务**（`lens_embedding_sync.py`）：从 LENS_REGISTRY 抽取语料、使用与 PgVectorLensRAGClient 一致的 `default_encode_text_to_vector` 编码、写入/更新 `lens_embeddings` 表；
  - 提供 **一键同步 CLI**（`app/scripts/sync_lens_embeddings_cli.py`），支持通过环境变量指定 DSN 与表名；
  - **RouterService** 支持通过环境变量 `MUSELENS_RAG_BACKEND=pgvector` 与 `MUSELENS_PG_DSN` 选用 PgVectorLensRAGClient；
  - 新增 **三个透镜配置**：`lens_depth_extract`（A1 深度图）、`lens_sam2_matting`（A1 抠图）、`lens_inpaint_bg`（A2 局部重绘），并纳入全局 LENS_REGISTRY；
  - 编写 **RAG + pgvector 接入与扩展指南**（`docs/RAG_pgvector 接入与扩展指南.md`）；
  - 建立 **全面自动化测试**：共 **27 个用例**，覆盖透镜注册表、Lens 向量同步、RAG 客户端（含 default_encode_text_to_vector、InMemory、PgVector 占位）、Router（compile_or_ask、answer、_validate_links、extra、异常会话等），在 `Muselens` conda 环境下全部通过。

> 结论：Router 阶段 3 完成了 pgvector 从「骨架」到「可落库、可切换」的闭环，并补齐了本阶段功能的自动化测试与文档，为后续 LLM 编排与生产环境部署提供了稳定基线。

---

### 二、本阶段涉及的项目结构

#### 1. Lens 向量同步（pgvector 落库）

- **`backend/app/services/lens_embedding_sync.py`**
  - `_build_lens_corpus(tmpl)`：为单个 LensTemplate 构造用于编码的文本语料（lens_id、layer、description、参数名与描述）；
  - `_to_vector_literal(vec)`：将 Python 向量序列转为 pgvector 文本字面量 `[0.1,0.2,...]`；
  - `ensure_lens_embeddings_schema(dsn, table_name)`：确保 pgvector 扩展与 `lens_embeddings` 表（含 ivfflat 索引）存在；
  - `sync_lens_embeddings(dsn, table_name, encode_text_to_vector, registry)`：将给定 registry（默认 LENS_REGISTRY）中所有透镜向量 upsert 到表，返回成功条数；**显式传入 `registry={}` 时直接返回 0 且不连接数据库**。
- **`backend/app/scripts/sync_lens_embeddings_cli.py`**
  - 入口：`python -m app.scripts.sync_lens_embeddings_cli`；
  - 从环境变量读取 `MUSELENS_PG_DSN`、`MUSELENS_RAG_PGVECTOR_TABLE`，调用 `ensure_lens_embeddings_schema` 与 `sync_lens_embeddings`。

#### 2. RAG 客户端与 Router 环境切换

- **`backend/app/services/rag_client.py`**（本阶段调整）
  - `EMBEDDING_DIM = 256`：默认向量维度，与 pgvector 表定义一致；
  - `default_encode_text_to_vector(text, dim)`：无外部服务的简易 embedding（分词 + 桶计数 + L2 归一化），与 InMemoryLensRAGClient 的 _tokenize 风格一致，便于测试与 pgvector 联调；
  - `PgVectorLensRAGClient`：继续使用延迟导入 psycopg，默认使用 `default_encode_text_to_vector` 作为编码函数。
- **`backend/app/services/router_service.py`**（本阶段调整）
  - `_create_rag_client_from_env()`：
    - `MUSELENS_RAG_BACKEND=pgvector` 且提供 `MUSELENS_PG_DSN` 时，返回 `PgVectorLensRAGClient(dsn, table_name)`；
    - 否则返回 `InMemoryLensRAGClient()`；
  - 全局单例：`router_service = RouterService(rag_client=_create_rag_client_from_env())`。

#### 3. 新增透镜配置

- **`backend/app/lenses/config/lens_depth_extract.lens.json`**
  - A1 层，Depth Anything V2 深度图提取，输出 `depth_map`，无 params。
- **`backend/app/lenses/config/lens_inpaint_bg.lens.json`**
  - A2 层，SDXL 局部重绘，输入 `base_image` + `mask_target`，输出 `result_image`，参数 `positive_prompt`。
- **`backend/app/lenses/config/lens_sam2_matting.lens.json`**
  - A1 层，Grounding DINO + SAM2 指定目标抠图，输出 `mask_result`，参数 `prompt`。

上述配置由 `backend/app/lenses/registry.py` 自动扫描 `config/*.lens.json` 加载进 `LENS_REGISTRY`。

#### 4. 文档

- **`docs/RAG_pgvector 接入与扩展指南.md`**
  - 架构概览、数据库准备（Docker / 本机）、一键建表与同步、环境变量说明、扩展新透镜的步骤、向量维度与编码函数说明。

---

### 三、测试与验证

#### 1. 测试文件与用例概览

| 文件 | 说明 |
|------|------|
| **`tests/test_lens_registry.py`** | 新增。校验 LENS_REGISTRY 包含 lens_depth_extract / lens_inpaint_bg / lens_sam2_matting；各模板字段与 schema（layer、params、outputs）；get_lens 正常/异常行为。 |
| **`tests/test_lens_embedding_sync.py`** | 新增。空 registry 返回 0 且不 connect；带 mock psycopg 的 upsert 次数与参数（schema + 2 条 upsert）；默认 encoder 维度；ensure_lens_embeddings_schema 的 SQL 与 commit。 |
| **`tests/test_rag_client.py`** | 扩展。default_encode_text_to_vector 空串/非空/自定义 dim；InMemory 的 k、空查询、LensCandidate 结构；PgVector 在 encode=None 时抛 RuntimeError。 |
| **`tests/test_router_service.py`** | 扩展。_validate_links 非法引用抛 ValueError、合法引用不抛；extra 含 retrieved_lenses；answer 对不存在 session 抛 ValueError。 |
| **`tests/test_pgvector_client_placeholder.py`** | 原有。PgVectorLensRAGClient 在 encode_text_to_vector=None 时 search_lenses 抛 RuntimeError。 |

#### 2. 运行方式与结果

在 `Muselens` conda 环境下：

```bash
conda activate Muselens
cd backend
python -m pytest tests/ -v --tb=short
```

当前结果：**27 passed**，1 条 Pydantic 警告（`ClarifyQuestion.schema` 与 BaseModel 属性同名），不影响功能。

#### 3. 实现细节与兼容性说明

- **Python 3.9**：测试代码使用 `Optional[str]` 而非 `str | None`，保证 3.9 兼容。
- **空 registry 语义**：`sync_lens_embeddings(registry={})` 表示「显式不同步任何透镜」，实现为 `reg = LENS_REGISTRY if registry is None else registry`，空 reg 时直接返回 0。
- **Mock 策略**：`lens_embedding_sync` 在函数内才 `import psycopg`，测试通过 `patch.dict(sys.modules, {"psycopg": mock_psycopg})` 注入 mock，无需真实数据库即可验证逻辑。

---

### 四、阶段小结与后续规划

- **阶段小结**
  - 完成了「Lens 配置 → 语料构建 → 向量编码 → pgvector 落库 → Router 按环境选用 RAG」的完整链路；
  - 新增三个透镜配置并纳入注册表，Router 固定管线（lens_sam2_matting → lens_inpaint_bg）与 LENS_REGISTRY 一致；
  - 通过 27 个自动化用例覆盖本阶段新增与修改的模块，并在 Muselens 环境下全部通过，形成可维护的测试基线。

- **后续规划（面向 Router 阶段 4 及以后）**
  1. **LLM 编排**：将规则版意图解析与固定管线升级为 RAG + LLM 驱动的透镜选择与参数落地；
  2. **会话持久化**：将 Router 会话从内存迁移到 Redis / 数据库，支持多用户与跨进程；
  3. **评测与可观测性**：为 RAG 召回与 Router 决策建立离线评测集与监控指标；
  4. **前端追问 UI**：与 Router 的 NEED_CLARIFICATION / answer 接口对接，完成多轮对话体验。

本文档作为「Router 阶段 3」的开发记录，与 `开发日志-Router阶段1.md`、`开发日志-Router阶段2.md` 及 `RAG_pgvector 接入与扩展指南.md` 一起，形成从规则 Router → RAG 抽象 → pgvector 落地与测试的完整演进日志。
