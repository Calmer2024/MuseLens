# Lens 注册与 LLM 知识库指南

本文档面向同伴/团队成员，解释如何向后端注册一个“透镜（Lens）”，并让它具备用于 LLM Planner 的知识（few-shot examples）与可检索向量（pgvector）。

## 1. 注册透镜要提供什么

后端通过 `POST /api/v1/lenses/register` 将透镜写入数据库，并同步到内存注册表（`registry.LENS_REGISTRY`）。

注册透镜的请求体结构主要包含：

- `lens_id`：透镜唯一 ID（例如 `lens_inpaint_bg`）
- `layer`：功能层级（`A1` ~ `A5`）
- `description`：透镜功能描述（给检索/LLM 理解用）
- `workflow_file_path`：ComfyUI 工作流 JSON 的本地路径（绝对路径或 `backend/lens/` 下的文件名）
- `inputs`：输入资产插槽列表
- `outputs`：输出资产插槽列表
- `params`：可调参数插槽列表
- `examples`（新增）：few-shot 自然语言示例，用于 LLM Planner 的知识补全

### inputs / outputs / params 的格式

每个条目都是类似下面的结构（`node_id` 对应 ComfyUI 的节点 ID）：

- `inputs[]`（资产）
  - `name`：语义名称（例如 `base_image`）
  - `type`：资产类型（例如 `image` / `mask`）
  - `mapping`
    - `node_id`
    - `field_name`
- `params[]`（参数）
  - `name`：参数语义名称（例如 `prompt` / `positive_prompt`）
  - `type`：参数类型（例如 `text` / `float`）
  - `description`：参数说明（给 LLM 理解）
  - `mapping`
    - `node_id`
    - `field_name`

## 2. examples（LLM few-shot 知识）怎么写

`examples` 字段是一个列表，每个元素包含：

- `nl_desc`：一段自然语言示例描述（越贴近真实用户输入越好）
- `params_example`：该示例对应的参数落地示例（JSON 对象）

示例（概念）：

```json
{
  "lens_id": "lens_inpaint_bg",
  "examples": [
    {
      "nl_desc": "把照片里的背景换成海边日落，并且主体保持不变。",
      "params_example": { "positive_prompt": "a beautiful beach, sunset" }
    }
  ]
}
```

### examples 如何被使用

当 Router（v2）触发并进入 Retrieval + Planner 流程时：

1. RAG 召回候选 `lens_id`
2. `RetrievalService` 会去数据库的 `lens_examples` 表读取该 lens 的 `nl_desc / params_example`
3. Planner LLM 将 examples 与参数 schema 一起用于更灵活地填参/生成 DAGBlueprint

## 3. 数据落到哪里（你关心的三张表）

1. `lenses`（Lens 元数据）
   - 由 `LensRecord` 存储：`lens_id/layer/description/workflow_file_path/inputs_json/outputs_json/params_json`
2. `lens_examples`（LLM few-shot examples）
   - 由 `LensExampleRecord` 存储：`lens_id/nl_desc/params_example`
3. `lens_embeddings`（pgvector 向量库，可选）
   - 由同步脚本将透镜（及其 examples）编码为向量写入
   - 当环境变量选择 `MUSELENS_RAG_BACKEND=pgvector` 时，RAG 检索会走该向量库

## 4. 如何启用 “LLM + pgvector”

### 4.1 配置环境变量

必须配置 Planner 的 LLM：

- `MUSELENS_LLM_API_KEY`
- `MUSELENS_LLM_MODEL`
- （可选）`MUSELENS_LLM_BASE_URL`，默认为 `https://api.openai.com/v1`

并启用 pgvector RAG：

- `MUSELENS_RAG_BACKEND=pgvector`
- `MUSELENS_PG_DSN=postgresql://user:pass@host:5432/db`

同时建议让后端数据库（写入 lenses/lens_examples）也指向同一个 Postgres：

- `MUSELENS_DB_URL`（例如 `postgresql+psycopg://...`）

### 4.2 同步向量库（两种方式）

方式 A：手动同步（第一次/批量新增后）

```powershell
cd D:\Repositories\MuseLens\backend
$env:MUSELENS_PG_DSN="postgresql://user:pass@localhost:5432/muselens"
$env:MUSELENS_RAG_PG_BACKEND="pgvector"
python -m app.scripts.sync_lens_embeddings_cli
```

方式 B：注册透镜时自动同步（已实现时）

当检测到 `MUSELENS_RAG_BACKEND=pgvector` 后，`POST /api/v1/lenses/register` 会在注册成功后触发 embeddings 同步（尽量保证“注册后立刻可检索”）。

## 5. 如何注册透镜（一次完整请求示例）

建议用 Swagger 测试（`http://127.0.0.1:8000/docs`），也可以直接调用 API。

下面是一个精简示例（你需要根据实际 workflow 节点与字段名补齐 inputs/outputs/params mapping）：

```json
{
  "lens_id": "lens_my_new_lens",
  "layer": "A2",
  "description": "你的透镜功能描述",
  "workflow_file_path": "lens_my_new_lens.json",
  "inputs": [
    {
      "name": "base_image",
      "type": "image",
      "mapping": { "node_id": "1", "field_name": "image" }
    }
  ],
  "outputs": [
    {
      "name": "result_image",
      "type": "image",
      "mapping": { "node_id": "10", "field_name": "images" }
    }
  ],
  "params": [
    {
      "name": "positive_prompt",
      "type": "text",
      "description": "要重绘成什么内容",
      "mapping": { "node_id": "8", "field_name": "text" }
    }
  ],
  "examples": [
    {
      "nl_desc": "把背景改成夜景霓虹，主体保持清晰。",
      "params_example": { "positive_prompt": "neon night city, cinematic lighting" }
    }
  ]
}
```

将上述 JSON 作为 `POST /api/v1/lenses/register` 的请求 body 即可。

## 6. 如何让 Router 使用这些信息（LLM 入口）

调用统一入口：

- `POST /api/v1/router/route`

请求体（`RouterRouteRequest`）关键字段：

- `user_message`：用户自然语言意图（新会话必填）
- `base_image`：源图像资产名（例如 ComfyUI input 里的文件名）
- `user_id`（可以给固定值）
- `session_id`（可选：新会话可不传；后续追问要传回）

第一次调用示例（概念）：

```json
{
  "user_id": "test-user",
  "user_message": "把背景换成海边日落，并保留人物不变。",
  "base_image": "upload_raw.png"
}
```

Router 可能返回两种状态：

- `need_clarification`：缺少关键参数时追问
- `ready`：返回 `blueprint`（DAGBlueprint），此后由编译/执行链路继续工作
