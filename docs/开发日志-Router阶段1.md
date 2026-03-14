## MuseLens 开发日志 · Router 阶段 1

### 一、本阶段目标与完成情况

- **目标**：为 v3/v4 架构引入一个最小可用的「意图路由器」（Router），能够：
  - 将用户自然语言解析为 **透镜序列 + 参数**，生成可执行的 `DAGBlueprint`；
  - 在信息不足时返回**结构化追问**，由前端补齐，再继续编译；
  - 与现有 `MuseDNACompiler` / ComfyUI 执行链路无缝衔接。
- **当前完成度**：
  - 定义了 Router 相关的 **Pydantic 模型**（追问、会话请求/响应等）；
  - 实现了一个基于规则的 **RouterService**（简化版 RAG + 编排）；
  - 新增了 FastAPI **REST 接口**：`/api/v1/router/compile_or_ask` 与 `/api/v1/router/answer`；
  - 编写了针对 Router 的 **单元测试**（3 个用例），并在 `Muselens` conda 环境下通过 `pytest` 全部跑通。

> 注意：当前 RouterService 仍是「无 LLM / 无 pgvector 的规则版骨架」，后续可以在保持接口不变的前提下，平滑升级为真正的 RAG + LLM 版本。

---

### 二、与 Router 相关的项目结构

#### 1. 后端整体入口

- `backend/app/main.py`
  - 创建 FastAPI 应用；
  - 挂载路由：
    - `editor`：`/api/v1/editor/...`
    - `router`：`/api/v1/router/...`（本阶段新增）
    - `test_run`：`/api/v1/test/...`

#### 2. Router 数据模型（Schemas）

- `backend/app/schemas/router.py`
  - **追问类型**：
    - `QuestionType`：`single_choice | multi_choice | slider | text`
    - `QuestionBindTarget`：当前支持 `PARAM`（绑定到 `DAGStep.params`）和 `META`
  - **追问绑定**：
    - `QuestionBind`：描述答案应回填到哪个步骤/透镜/参数名。
  - **追问本体**：
    - `ClarifyQuestionSchema`：数值边界、默认值、是否允许自定义文本等；
    - `ClarifyQuestion`：`id / prompt / type / options / required / binds / schema`。
  - **Router 状态与请求/响应**：
    - `RouterStatus`：`NEED_CLARIFICATION | READY | FAILED`
    - `RouterCompileRequest`：`user_id / user_prompt / base_image / session_id`
    - `RouterAnswerRequest`：`session_id / answers`
    - `RouterResponse`：`session_id / status / thought_process / questions / blueprint / extra`

> 与执行侧的 `DAGBlueprint` / `DAGStep` 结构定义在 `backend/app/schemas/lens.py` 中，Router 生成的蓝图可以直接交给 `MuseDNACompiler` 执行。

#### 3. Router 核心服务

- `backend/app/services/router_service.py`
  - `_RouterSession`（内部 dataclass）：
    - 字段：`session_id / user_id / original_prompt / base_image / answers`
    - 暂存在内存中，后续可替换为 Redis / DB。
  - `RouterService`：
    - `compile_or_ask(req: RouterCompileRequest) -> RouterResponse`
      - 创建或复用会话；
      - 基于规则从 `user_prompt` 提取：
        - 目标物体（如“水杯”）；
        - 替换内容（如“一盆多肉植物”）；
      - 对信息不足的情况生成 `ClarifyQuestion`（例如 `q_target_object`、`q_replace_with`）；
      - 若仍有缺失 → 返回 `NEED_CLARIFICATION`；
      - 若信息足够 → 构造 `DAGBlueprint`，调用 `_validate_links` 做静态连线校验，返回 `READY`。
      - 当前固定产出一个典型的 A1→A2 管线：
        - Step1：`lens_sam2_matting`（抠图）
        - Step2：`lens_inpaint_bg`（局部重绘）
    - `answer(req: RouterAnswerRequest) -> RouterResponse`
      - 将 `answers` 合并进会话的 `sess.answers`；
      - 重新构造 `RouterCompileRequest`，调用 `compile_or_ask` 再编译一次；
      - 在重新编译前，利用 `sess.answers` 覆盖缺失参数（`q_target_object` → `prompt`，`q_replace_with` → `positive_prompt`），避免陷入重复追问；
      - 最终返回 `READY + blueprint`，并再次进行 `_validate_links` 静态校验。
    - `_extract_target_object(text)` / `_extract_replace_object(text)`：
      - 当前使用极简中文关键词和正则规则（例如匹配“水杯”“多肉”“换成X”）；
      - 未来可以替换为真正的 LLM 解析或更完整的规则系统。
    - `_validate_links(blueprint)`：
      - 校验所有 `$变量引用` 是否已在 `initial_inputs` 或前序步骤输出中定义；
      - 按 `step_id.mask_result` / `step_id.result_image` 这种约定加入可用资产集；
      - 后续可以接入 `LensTemplate.outputs` 做更精确的变量生成。
  - `router_service = RouterService()`：提供全局单例给 FastAPI 路由使用。

#### 4. Router HTTP 接口（FastAPI 路由）

- `backend/app/api/v1/endpoints/router.py`
  - `POST /api/v1/router/compile_or_ask`
    - 入参：`RouterCompileRequest`
    - 出参：`RouterResponse`
    - 行为：
      - 若信息足够 → `status = READY`，带 `blueprint`；
      - 若信息不足 → `status = NEED_CLARIFICATION`，带 `questions[]`。
  - `POST /api/v1/router/answer`
    - 入参：`RouterAnswerRequest`
    - 出参：`RouterResponse`
    - 行为：
      - 回填追问答案，重新编译；
      - 若补齐关键信息 → 返回 `READY + blueprint`。

---

### 三、当前 Router 行为概览

#### 1. 支持的典型场景（示例）

- 用户输入：
  - 「把桌上的水杯换成一盆多肉，保留倒影，背景调暗点」
- Router 行为（当前规则版）：
  - 识别到 **目标物体** ≈ “水杯”；
  - 识别到 **替换内容** ≈ “一盆多肉植物”；
  - 组装两步 DAG：
    - `step_1_matting`：`lens_sam2_matting`，`params["prompt"] = "水杯"`；
    - `step_2_inpaint`：`lens_inpaint_bg`，连线 `mask_target = "$step_1_matting.mask_result"`，`params["positive_prompt"] = "一盆多肉植物"`；
  - 初始输入：`{"user_base_image": "<base_image 文件名>"}`；
  - 通过 `_validate_links` 校验后，返回 `READY + DAGBlueprint`。

#### 2. 追问机制示例

- 用户输入：
  - 「请帮我把这张图改一下」
- Router 行为：
  - 无法解析目标物体和替换内容；
  - 返回：
    - `status = NEED_CLARIFICATION`
    - `questions = [q_target_object, q_replace_with]`
  - 用户回答：
    - `q_target_object = "桌上的水杯"`
    - `q_replace_with = "一盆绿色多肉植物"`
  - Router 再次编译，利用 `sess.answers` 覆盖缺失参数，最终返回 `READY + blueprint`。

---

### 四、测试方法与当前结果

#### 1. 测试文件

- `backend/tests/test_router_service.py`
  - `test_compile_or_ask_ready_when_prompt_complete`
    - 场景：提示词中已包含「水杯」+「多肉」；
    - 期望：`compile_or_ask` 直接返回 `READY`，且 Blueprint 中存在 `step_1_matting` 与 `step_2_inpaint`。
  - `test_compile_or_ask_need_clarification_when_info_missing`
    - 场景：提示词非常模糊（“帮我把这张图改一改”）；
    - 期望：返回 `NEED_CLARIFICATION`，且包含 `q_target_object` 与 `q_replace_with` 两个追问。
  - `test_answer_flow_fills_params_and_becomes_ready`
    - 场景：先触发追问，再通过 `answer()` 回填答案；
    - 期望：
      - 第二次返回 `READY`；
      - `step_1_matting.params["prompt"] == "桌上的水杯"`；
      - `step_2_inpaint.params["positive_prompt"] == "一盆绿色多肉植物"`。

#### 2. 运行方式（使用 Muselens Conda 环境）

在项目根目录（`D:\Repositories\MuseLens`）下：

```bash
cd backend
D:\Programs\Anaconda3\envs\Muselens\python.exe -m pytest -q
```

或在终端中先：

```bash
conda activate Muselens
cd backend
pytest -q
```

当前测试结果：

- 所有 3 个测试用例全部通过；
- 有一条 Pydantic 警告（`ClarifyQuestion.schema` 字段名与 BaseModel 属性同名），不影响功能，后续如有需要可改名为 `value_schema` 等。

---

### 五、后续迭代方向（规划）

1. **RAG 能力接入**
   - 使用 PostgreSQL + pgvector 存储 Lens 协议的语义向量；
   - 替换当前 Registry-based 伪 RAG，为 Router 提供真正的 Top-K 召回。
2. **LLM 编排与参数落地**
   - 将当前的规则编排升级为「RAG + LLM」：
     - LLM 负责透镜选择、顺序编排、生成 `missing_info` 与追问文案；
     - 参数落地引擎负责将模糊词（“暗一点”“更柔和”等）映射为具体数值。
3. **会话持久化与多用户场景**
   - 将 `_RouterSession` 从内存迁移到 Redis / 数据库；
   - 支持多用户并发与跨进程 Router 状态共享。
4. **更丰富的测试矩阵**
   - 覆盖更多中文表达方式、边界情况和错误输入；
   - 针对「RAG + LLM」版本增加离线评测集（prompt → blueprint 的 golden cases）。

本开发日志用于记录 Router 阶段 1 的实现情况，后续每完成一个重要里程碑（如接入 pgvector、LLM 编译、前端追问 UI 等），建议在 `docs/` 下继续补充对应阶段的日志文件，以便长期维护与协作。

