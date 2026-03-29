# MuseLens 智能路由引擎 (Lens Router) 开发实施计划

基于当前的系统架构设计与后端代码现状，我们将分四个阶段逐步实现系统的核心决策大脑——**智能路由引擎与 AOT 链接编译器**。

## 🎯 总体目标
将目前硬编码的顺序执行流程，升级为能够解析自然语言意图、动态执行图结构的 **智能决策分发系统**。使得任何用户的复杂需求（如“先抠出沙发，然后把背景换成赛博朋克风”）能够被准确编译为 ComfyUI 的确定性运行管线（Muse DNA）。

---

## 📅 阶段一：定义核心 Schema 与静态图校验 (Pre-flight Validation)

**目标**：打造一个可靠的“黑盒编译器”。不论业务数据如何生成，只需确保接收到的 JSON 格式合法且无悬空引用即可执行动态拓扑。

### 1.1 数据结构定义层 (`app/schemas/router.py`)
利用 Pydantic 严格定义 `LensStep` (DAG 中的一个节点)：
- **`LensStep`**: 包含 `step: int` 序列号、`lens_id: str` (如 `"lens_sam2_matting"`)。
- **`inputs`**: 字典类型，例如 `{"base_image": "upload_raw.png"}`，必须显式声明所有入参及其对应来源。
- **`outputs`**: 字典类型，例如 `{"mask_result": "mask_sofa_v1"}`，用于向上下声明新产生的资产。
- **`params`**: 字典类型，特定调整参数如 `{"prompt": "sofa"}`。

### 1.2 预飞校验引擎 (Validation Sandbox)
开发一个单纯的解析沙盘 `DAGValidator`：
- **前置拓扑检查**: 按照 `step` 升序遍历所有的 `LensStep`。
- **符号表机制 (Symbol Table)**: 初始化符号表，填入最初的输入资源（如 `upload_raw.png`）。
- **IO 对比校验**: 在遍历时，校验一个步骤涉及的所有 `inputs` 名称是否在符号表中已存在。如果存在引用的变量未在之前任何步骤的 `outputs` 或初始态出现过，则**拦截并报错（悬空引用异常）**。
- **状态登记**: 将当前步骤的 `outputs` 名称注册注入到接下来的符号表中。

### 1.3 改造动态编译器 (`DynamicDAGCompiler`)
将现存的 `app/services/compiler.py` (Local Mock) 升级：
- 接收一个完全经过校验的 `List[LensStep]`。
- 维护一个**真实的运行时资产目录 (Runtime Asset Table)**，其中键为定义好的全局名称（如 `"mask_sofa_v1"`），值为 ComfyUI API 刚生成出来的物理文件路径。
- 为每个节点调用 `ComfyBridge` 执行。获取真实输出文件名后，按 `outputs` 定义的名称保存到资产目录。
- 处理下个节点时，在注入阶段，通过名字到资产录中查询对应的真实文件。

---

## 📅 阶段二：LLM 接入与 AOT 变量分配机制 (AOT Linking)

**目标**：不带检索和追问，先实现最纯粹的**“自然语言明确指令” -> “符合 Schema 的 JSON Array”**的 AOT 编译。

### 2.1 LLM 基础接入 (`llm_service.py`)
- 引入 `openai` 或其他支持工具调用 (Function Calling/Structured Output) 的大模型 SDK。
- 将第一阶段写好的 Pydantic Data 结构暴露给大模型（转换为 JSON Schema）。
- 设定基础 System Prompt 提示词，让 AI 扮演"AOT Compiler"，只输出标准格式（Muse DNA）不回答任何废话。

### 2.2 上下文注入与提示工程
- 根据用户对话和 `registry.py` 中所有的可用 `LensTemplate`，动态生成一份能力列表，作为上下文提供给本次调用请求。
- 告诉 LLM：“你必须使用已有的 `lens_id`” 以及 “分配唯一的英文字符串常量用在 `outputs` 并喂给被链接透镜的 `inputs`”。

### 2.3 链路连通测试
- 通过 `/api/v1/editor/chat` (新路由) 接入完整的测试。使用预定义的几个简单需求如“给原图提取深度图，然后重绘”测试链路输出格式的准确率、IO 对称性。

---

## 📅 阶段三：RAG 召回层建设 (Retrieval-Augmented Generation)

**目标**：当系统透镜数量膨胀（从 3 个激增到 300 个）时，突破 LLM Context 窗口限制。

### 3.1 轻量级向量储存初始化
- 使用如 `ChromaDB` (极轻量化、纯Python) 构建本地向量数据库，后续方便平滑迁移迁移 `PostgreSQL + pgvector`。
- 提取所有的 `LensTemplate` 对象（在 `registry.py`，或者是你文档中所述的“标准透镜库v4.1.md”），计算每个 Lens `description` 和核心参数的文本 Embedding 数据 (使用 `text-embedding-3-small` 或类似的廉价嵌入接口)。

### 3.2 动态检索逻辑嵌入 (`router_service.py`)
- 用户发出自然语言指令（例如“提取画面边缘”）。
- 在调用全尺寸生成模型之前，先使用该指令请求数据库获取 Top-K （例如最符合的 3~5个） 透镜 Schema。
- 将这极少数的命中结果发给阶段二写好的 `LLM Context`，极大地节约 Token 消耗，并杜绝 AI “凭空捏造” Lens。

---

## 📅 阶段四：状态机与追问引擎 (Clarification Engine)

**目标**：拦截模糊意图，通过显式交互获取全要素后才生成。解决幻觉的最强一道防线。

### 4.1 核心状态机设计 (`SessionManager` 模型)
- 添加一套会话状态体系，利用内存或数据库存放正在进行处理（挂起）态的聊天记录上下文。
- 会话状态支持：`Idle`(空闲) -> `Executing`(执行中) -> `Pending_Clarification`(缺少参数挂起等待用户)。

### 4.2 拦截与逆向追问
- 覆写阶段二中的 Prompt 逻辑：允许大模型输出两类对象：
   1. 正确的 DAG JSON （参数齐全且清晰）。
   2. 追问 JSON （缺少必填参数或意图模糊，如“你想切换到什么绘画风格？”）。
- 一旦探测到第二种返回结果，系统状态变更为 `Pending_Clarification`，直接将信息发送给前端 UI，中断任何生成流水线。

### 4.3 上下文拼接闭环
- 当用户补充回答后（“赛博朋克风”），系统从状态机读出被挂起的历史请求，加上该回答再次尝试进行 AOT 分配。成功获取完整的 DAG 后即开始走回正常执行流。
