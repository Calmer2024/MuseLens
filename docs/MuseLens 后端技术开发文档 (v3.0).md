# MuseLens 后端技术开发文档 (v3.0)

**核心理念：** 对话即调度 (Orchestration) | LLM AOT链接 (Ahead-Of-Time Linking) | 透镜即微服务 (Lens as Microservice) | 后端即沙盒 (Backend as Sandbox)

1. ## 核心架构设计 (Core Architecture)

v3.0 架构彻底抛弃了脆弱的 JSON 内存连线拼接逻辑，转变为 **“基于 LLM 静态变量分配的** **DAG** **盲执行流水线”**。后端不仅是 API 响应者，更是异构算力的隔离调度与物理搬运中枢。

### 1.1 系统分层图 (System Layering)

- **接入层 (Access Layer):** Flutter (Mobile) 与 React (Web) 多端协同。
- **网关****层 (****Gateway****):** FastAPI 构建，负责 WebSocket 长连接维持（处理实时预览流与对话）与 RESTful API 鉴权。
- **编排与链接层 (Orchestration & Linker Layer) [核心重构]:**
  - **LLM** **Router** **(路由器/链接器):** 结合 RAG 检索，将意图解析为 DAG 执行单，并**提前分配好所有透镜输入输出的文件名变量 (****`asset_name`****)**。
  - **Clarification Engine (追问引擎):** 基于有限状态机 (FSM) 处理模糊意图并生成结构化追问。
- **执行与搬运层 (Execution &** **IO** **Layer) [核心重构]:**
  - **Pipeline Executor (盲执行器):** 替代原 DNA Compiler。按 LLM 给定的清单，注入 `Session_ID` 隔离沙盒，发起独立的无头 API 请求。
  - **IO** **搬运工 (File Mover):** 监听 ComfyUI 产物，强制重命名为 LLM 预设的 `asset_name`，移入 `input` 目录完成接力。
- **能力层 (Capability Layer):**
  - **ComfyUI Cluster:** A1-A5 原子透镜的执行引擎。分为 **Draft Workers (****LCM** **预览)** 和 **Commit Workers (SDXL 高清)**，依赖 LRU Cache 实现大模型 0ms 热切换。
- **数据层 (Data Layer):** PostgreSQL (业务/资产快照树), Redis (热点会话/队列), MinIO / 本地 SSD (物理图像搬运与存储)。

### 1.2 核心技术栈清单

| 模块       | 推荐技术              | v3.0 架构说明                                          |
| ---------- | --------------------- | ------------------------------------------------------ |
| Web 框架   | FastAPI               | 处理 WebSocket 全双工通信与沙盒 IO 搬运。              |
| 智能路由   | DeepSeek / OpenAI SDK | 结合 Function Calling 输出强制结构化的 DAG 计划。      |
| 知识检索   | PostgreSQL + pgvector | 使用 HNSW 索引按需检索 A1-A5 透镜能力，防止 LLM 幻觉。 |
| 执行引擎   | ComfyUI Headless API  | 不再接收缝合图，只接收完全独立的微服务原子短图。       |
| 数据库     | PostgreSQL 15         | 使用 UUID[] 数组 + GIN 索引存储树状分支历史。          |
| 缓存与消息 | Redis 7.0             | 存储 Session 上下文、FSM 状态及高低优任务队列。        |

1. ## 后端项目架构图 (Directory Structure)

```Plain
backend/
├── app/
│   ├── api/v1/
│   │   ├── endpoints/
│   │   │   ├── router.py       # 处理意图解析、RAG 召回与 FSM 追问
│   │   │   ├── assets.py       # 资产树操作 (节点快照切换与恢复)
│   │   │   ├── market.py       # 透镜市场接口 (上传/下载 Lens JSON)
│   │   │   └── execute.py      # 接收 DAG，触发混合管线执行 (Draft/Commit)
│   ├── core/
│   ├── db/
│   │   ├── models/
│   │   │   ├── asset_tree.py   # 存储 UUID[] 路径与 DAG 执行快照
│   │   │   └── lens.py         # v3.0 标准透镜协议模型
│   ├── services/
│   │   ├── router_service.py   # LLM Prompt 构建与 AOT 变量分配
│   │   ├── pipeline_executor.py# [重构核心] 沙盒执行与 IO 搬运中枢
│   │   ├── lcm_service.py      # LCM 极速预览管线参数降级服务
│   ├── schemas/
│   │   ├── dag_schema.py       # Pydantic 定义 LLM 输出的严格 DAG 结构
│   │   └── lens_protocol.py    # 标准透镜协议 (定义 Inputs/Outputs)
└── templates/                  # A1-A5 独立闭环的 ComfyUI JSON 模板
```

1. ## 关键技术模块详解 (Key Technical Modules)

### 3.1 智能路由器与 AOT 链接引擎 (Router & Linker)

**功能定义：** 系统的决策大脑，负责**意图拆解 -> RAG 召回 -> 追问拦截 ->** **AOT** **参数与变量分配**。

#### 3.1.1 路由工作流四步曲

1. **意图向量化与 RAG 召回:** 将用户自然语言转化为 Embedding，从 PostgreSQL 向量库召回最相关的 Top-K 个透镜协议（如 `lens_sam2_matting`, `lens_iclight_dir`）。
2. **追问拦截 (Clarification Engine):** 若 LLM 判定用户指令极度模糊（如只说“换个风格”），状态机挂起当前请求，通过 WebSocket 逆向追问：“您想要日漫风还是写实风？”，等待用户回复后拼接上下文。
3. **AOT** **变量分配 (Ahead-Of-Time Linking):** LLM 利用 Function Calling 输出严格的 JSON 数组。它不仅为节点赋参，更**为****工作流****的****Output****资产赋予全局唯一的字符串名称（如** **`mask_cat_v1`****）**，将其填入上游的 Output 和下游的 Input，完成逻辑咬合。
4. **静态图校验 (Pre-flight** **Validation****):** FastAPI 收到 JSON 后，执行前置校验，确保所有后续透镜调用的 Input 变量名，均在前序透镜的 Output 中被声明过。

**LLM** **输出的** **DAG** **Schema 示例：**

```JSON
[
  {
    "step": 1,
    "lens_id": "lens_sam2_matting",
    "inputs": { "BASE_IMAGE": "upload_raw.png" },
    "outputs": { "MASK_RESULT": "mask_sofa_v1" },
    "params": { "target": "sofa" }
  },
  {
    "step": 2,
    "lens_id": "lens_inpaint_bg",
    "inputs": {
      "LATEST_IMAGE": "upload_raw.png",
      "MASK_TARGET": "mask_sofa_v1" // 完美衔接
    },
    "outputs": { "RESULT_IMAGE": "inpaint_result_v1" },
    "params": { "prompt": "a cyberpunk room" }
  }
]
```

### 3.2 盲执行与沙盒 IO 引擎 (Pipeline Executor)

**核心职责：** 取代旧版的“节点拼接”，执行并发隔离与物理文件搬运。

#### 3.2.1 沙盒执行与搬运逻辑

1. **Input** **沙盒化：** 遍历 DAG，在所有的 `asset_name` 前强行拼上 `Session_ID`（如 `req123_mask_sofa_v1.png`），并写入独立 JSON 模板的 `LoadImage` 节点，实现多用户并发隔离。
2. **盲执行：** 将拼好文件名的 JSON 作为独立任务发给 ComfyUI。
3. **Output** **搬运魔法：** 执行完毕后，监听 ComfyUI `output` 目录，找到刚生成的带乱码序号的文件（如 `_00001.png`），**强制剥离后缀，重命名为 LLM 期待的沙盒化名称，并移入** **`input`** **目录**。
4. **增量跳过：** 依靠 `dirty` 标记，如果当前工作流未发生参数变更，直接 `continue` 跳过，下游依然可以从 `input` 里读到上一次生成的缓存文件，实现秒级出图。

### 3.3 混合视觉处理管线 (Hybrid Visual Pipeline)

系统为了平衡“交互速度”与“最终画质”，在 FastAPI 提交任务前进行双轨调度。

- **Draft Mode (预览态):**
  - **触发：** 用户滑动 UI 滑块。
  - **干预策略：** `lcm_service.py` 拦截即将发送的 JSON，自动将 `KSampler` 替换为 LCM 专属配置（步数降至 4-6 步，分辨率强制 512px，CFG=1.5）。
  - **路由：** 任务推入 Redis `queue_draft`，由专属的轻量级 Worker 秒级响应，返回 Base64 缩略图。
- **Commit Mode (终稿态):**
  - **触发：** 用户点击“应用/高清生成”。
  - **干预策略：** 保持 LLM 原始配置（30+步，1024px 高清）。
  - **路由：** 推入 `queue_commit`，由搭载 SDXL 的重型 Worker 渲染，产出并上传至 MinIO。

### 3.4 树状资产管理器 (Tree-Based Asset Manager)

**核心职责：** 实现高级修图软件必备的非破坏性编辑树与亚秒级回滚。

![img](https://zcnsewe4uqhg.feishu.cn/space/api/box/stream/download/asynccode/?code=ZmQyZGVkMmZiZmY2ZDZiYmNlNTdiMWY4MzMzYjcyMzBfTGFJY3RqYzVuNWprS3pCaThqSXZaVGNzVHUwT1FpSktfVG9rZW46S2ZETmJwdTBKb085UTd4UHRWWmNMcXFFbjdnXzE3NzI5NzAzNDk6MTc3Mjk3Mzk0OV9WNA)

#### 3.4.1 数据库模型 (PostgreSQL)

摒弃繁重的 JSON 存储，使用 Postgres 的数组与 JSONB 类型固化快照。

```SQL
CREATE TABLE asset_nodes (
    node_id UUID PRIMARY KEY,
    project_id UUID REFERENCES projects(id),
    -- 物化路径数组，存储 [root_id, ..., parent_id, current_id]
    path UUID[] NOT NULL, 
    dag_plan JSONB,        -- 核心：LLM 生成的完整执行清单 (含 asset_name)
    preview_url TEXT,      
    result_url TEXT,       
    created_at TIMESTAMP
);
CREATE INDEX idx_asset_nodes_path ON asset_nodes USING GIN (path);
```

**溯源与分叉：** 用户修改历史节点 `Node_A` 的参数时，生成新的 `Node_B`（`parent_id=Node_A`）。由于底层物理资产已由 `Session_ID` 保存在硬盘/MinIO中，后端的 DAG 盲执行器直接从变动节点读取对应资产继续执行即可。

1. ## 前后端通信协议 (WebSocket)

沿用全双工通信，载荷彻底“轻量化”。

1. **意图与追问 (****Router** **Loop)**

- `Client -> Server`: `{"type": "user_intent", "content": "修一下图"}`
- `Server -> Client`: `{"type": "clarification_request", "question": "请问是美颜还是换背景？", "options": ["美颜", "换背景"]}`

1. **自动编排完成**

- `Server -> Client`: `{"type": "dag_generated", "dag_plan": [...] }` (下发包含所有滑块和步骤的 UI 渲染结构)

1. **增量微调与流转 (Execution Loop)**

- `Client -> Server`: `{"type": "preview_request", "dag_plan": [...]}` (前端将某个步骤的 `dirty` 设为 `true` 并发送)
- `Server -> Client`: `{"type": "preview_result", "blob": "data:image/jpeg;base64,..."}` (极速返回 LCM 小图)

1. ## 数据存储策略 (Storage Strategy)

| 数据类型       | 存储方案         | v3.0 策略细节                                                |
| -------------- | ---------------- | ------------------------------------------------------------ |
| 资产快照树     | PostgreSQL       | 使用 Path Array (UUID[]) 存储拓扑结构，dag_plan 存储该节点完整的 AOT 变量链路快照。 |
| 透镜标准库     | PostgreSQL       | 存储官方 A1-A5 透镜的 JSON Protocol (含 Inputs/Outputs 定义) 及特征向量 (pgvector)。 |
| 物理资产与成品 | MinIO / 本地 SSD | input/output 作为执行期的“热交换区”；MinIO 长期存储高清终稿。 |
| 会话与队列     | Redis            | 存储 FSM 追问上下文；管理 queue_draft (高优) 和 queue_commit (低优)。 |

1. ## 异常处理、部署与性能榨取 (Defense & Performance)

为确保“微服务盲执行”在生产环境中的绝对稳定，系统设立以下纪律：

1. **LRU** **缓存最大化 (****显存****驻留):** 所有 A1-A5 原生工作流的 JSON 模板中，同类大模型（如 `sd_xl_base.safetensors`）的命名必须绝对一致。利用 ComfyUI 的 LRU 机制，实现透镜切换时的 **0ms 模型加载**。
2. **Impact** **Switch** **物理旁路:** 不需要的功能绝不使用参数 `0.0` 静默。后端通过控制 `Impact Switch` 的 `select=2` 走直通分支，实现冗余节点 **0** **显存****占用**。
3. **飞行前强制安检 (Pre-flight Check):** FastAPI 发出 HTTP 盲请求前，必须校验 `inputs` 中的变量是否已在上下文中声明，拦截一切 LLM 幻觉。
4. **僵尸文件** **GC** **(****Garbage Collection****):** 沙盒搬运产生的大量带有 `req_xxxx` 前缀的临时遮罩和中间件，由 Celery 定时脚本每 12 小时执行物理清理，释放磁盘。