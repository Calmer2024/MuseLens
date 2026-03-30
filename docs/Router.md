Router层设计
0. 先说结论：Router 现在是什么
- 不再是简单 _extract_xxx + 向量匹配。
- 主路径是 Retrieval + Planner(LLM) + Validator + Session 的小状态机。
- 追问机制是“参数缺失 / 不确定驱动”，不是只看有没有 prompt/image。
- 对外只做“编排决策”（返回蓝图或追问），不直接执行 ComfyUI。
对应入口：POST /api/v1/router/route（backend/app/api/v1/endpoints/router.py）。

---
1. 4层结构
下面按“理想分层”对照“当前实现”来讲：
分层
你要的职责
当前代码对应
1) Lens Catalog & DB 层
结构化 Lens 元数据、参数、示例、向量
lenses 表（含 params JSON）、lens_examples 表、lens_embeddings 表（pgvector）；模型与写入在 models/*、endpoints/lenses.py、lens_embedding_sync.py
2) Retrieval 层
只负责“找相关 Lens 知识”，不做编排
retrieval_service.py：retrieve()/retrieve_by_lens_ids()；调用 rag_client.py（内存/pgvector），再查 DB 补全 schema/examples，叠加 app/lenses/docs/*.md
3) Planning 层
LLM 选 Lens、排顺序、填参数、指出缺失参数
planner_service.py：输入 PlannerInput，输出 PlannerOutput(blueprint/missing/clarification)
4) Router 协调层
会话管理、串联调用、静态校验、输出状态
router_service.py + router_graph.py + router_session_store.py + blueprint_validator.py

关键点：Router 自己尽量不做“业务猜测”，而是把上下文喂给 Planner，让 Planner 做选择。

---
2. Router 的输入 / 输出抽象（当前实际）
2.1 输入：RouterRouteRequest
字段在 backend/app/schemas/router.py：
- session_id（可选）
- user_message（新会话通常必填）
- base_image / base_image_meta
- answers（如果是回答上一轮追问）
现在没有单独 client_context 字段，但可通过 user_id、base_image_meta 扩展。
2.2 输出：RouterResponse
- status: need_clarification / ready / failed
- session_id
- questions（结构化追问）
- blueprint（可执行 DAG）
- thought_process
- extra（调试和附加信息）

---
3. 一轮请求到底怎么跑（主链路）
主入口是 RouterService.route_with_db()，可分成 7 步：
第 1 步：加载/创建会话
- 有 session_id 就查 router_sessions；
- 没有就创建新会话（保存 original_prompt/base_image/base_image_meta）。
第 2 步：合并本轮 answers
- 若请求里有 answers，写入 collected_params。
- 约定 key 为 lens_id.param_name，例如 lens_inpaint_bg.positive_prompt。
第 3 步：构造 task_desc
- build_task_desc(user_message, history_summary) 生成本轮检索/规划的任务描述。
第 4 步：进入 LangGraph（v2 主状态机）
状态机在 router_graph.py，固定流程：
retrieve -> plan -> validate -> (可选 enrich -> plan) -> finalize
第 5 步：retrieve（只找知识）
RetrievalService.retrieve() 做两段事：
1. rag_client.search_lenses(task_desc, k) 召回候选 lens_id  
2. 用 lens_id 去 DB 查 lenses/lens_examples，再叠加 load_lens_doc(lens_id)（app/lenses/docs/*.md）形成 LensKnowledge。
输出给 Planner 的 candidates 是结构化列表，不是原始文本。
第 6 步：plan（LLM 编排）
PlannerService.plan(PlannerInput) 输入：
- task_desc
- base_image_meta
- candidates（schema + examples）
- session_context（collected_params/pending_questions/lens_history/previous_blueprint）
输出 PlannerOutput：
- blueprint（可能为空）
- missing_params
- clarification_questions
- thought
第 7 步：validate + finalize
- 若有 blueprint，BlueprintValidator.validate() 校验：
  - lens_id 是否存在
  - DAG 引用是否有效
  - 参数名/类型是否匹配
  - 必填参数是否在 step.params 或 collected_params 中满足
- finalize 根据结果决定返回：
  - NEED_CLARIFICATION
  - READY
  - FAILED
并把 pending_questions/pending_blueprint/collected_params/lens_history 写回会话。

---
4. 追问机制：当前到底怎么设计
4.1 追问由谁产生
追问来源于 Planner 结构化输出：
- clarification_questions
- missing_params
Router 会把它们转成对外 ClarifyQuestion。  
其中 router_graph._planner_to_clarify_questions() 还做了兜底：如果只有 missing_params 没有 clarification_questions，会自动合成问句。
4.2 如何知道“用户在回答哪个参数”
- 问题 ID 统一使用 lens_id.param_name
- 下一轮客户端提交 answers 时，用同一个键回传
- Router 直接按这个键更新 collected_params
所以当前实现 不依赖额外小模型 去“猜用户回答对应哪个参数”。  

---
5. 参数注入（Lens 参数怎么真正落进工作流）
要分两段看：
5.1 编排阶段（Router/Planner）
- Planner 产出 DAGBlueprint.steps[].params
- 这些 params 的 key 必须与 Lens schema 对齐（如 positive_prompt）
5.2 执行阶段（Compiler）
在 compiler.py 的 _inject_dependencies()：
- 遍历 template.params
- 找到 param.mapping.node_id + field_name
- 把 step.params[param.name] 注入到 workflow[node_id]["inputs"][field_name]
即：语义参数名 -> Lens mapping -> ComfyUI 节点字段。
注意：collected_params 本身是给 Planner/Validator 看的上下文。  
真正执行时，最终还是依赖 blueprint 里各 step 的 params。

---
6. Lens 注册：要写哪些东西才够
你现在最关心的是“加新透镜要准备什么”，按优先级：
必需 A：工作流 JSON
- 放在 backend/lens/*.json（或给绝对路径）
- workflow_file_path 必须能被后端读取到
必需 B：Lens 结构化定义
通过 POST /api/v1/lenses/register（或内置 config + seed）提供：
- lens_id/layer/description
- workflow_file_path
- inputs（资产槽位 + mapping）
- outputs（输出槽位 + mapping）
- params（参数 schema + mapping）
建议 C：few-shot examples
- examples: [{ nl_desc, params_example }]
- 提高 Retrieval 与 Planner 命中和填参质量
可选 D：文档增强
- backend/app/lenses/docs/<lens_id>.md
- 放参数规则、format_rules、decision_rules、补充 examples
- Retrieval 会与 DB 字段叠加后喂给 Planner

---
7. 当前实现了什么，没实现什么（非常重要）
已实现
- 统一 /route 入口，支持多轮
- DB 会话持久化（router_sessions）
- RAG（内存/pgvector）+ Catalog 补全 + docs 叠加
- Planner 结构化输出（tool）
- 蓝图静态校验
- 条件 enrich（再检索一次再 plan）
- need_clarification / ready / failed 分流
  
还没完全实现或可加强
- 独立 lens_param 关系表（目前主要在 lenses.params JSON）
- “用户回答文本 -> 参数赋值”的小模型映射器（当前依赖前端按 question id 回答）
- 更强的约束校验（范围/枚举/正则等）
- 更丰富的检索过滤（enabled/version/category 多条件）
- 全链路可观测性（更细日志与可视化）

---
8. 一句话理解运作机制
Router 现在做的是：
拿会话上下文 -> 检索候选 Lens 知识 -> 让 Planner 选 Lens + 排 DAG + 填参数 -> 校验 -> 返回可执行蓝图或结构化追问，并把状态写回会话。
这就是“有思考能力的编排器”在当前代码中的落地形式。

---
9. 代码入口索引（便于对照阅读）

- 路由入口：backend/app/api/v1/endpoints/router.py
- 协调器：backend/app/services/router_service.py
- 状态机：backend/app/services/router_graph.py
- 检索层：backend/app/services/retrieval_service.py
- RAG 客户端：backend/app/services/rag_client.py
- Planner：backend/app/services/planner_service.py
- 校验器：backend/app/services/blueprint_validator.py
- 会话持久化：backend/app/services/router_session_store.py
- Lens 文档加载：backend/app/services/lens_docs_service.py
- Lens 注册 API：backend/app/api/v1/endpoints/lenses.py

---
10. 接口调用示例

下面这几组示例对应当前推荐的联调方式：
- `/api/v1/router/route`：只做编排，返回追问或 blueprint
- `/api/v1/router/route_and_run`：测试闭环，ready 后可直接执行
- `answers` 的 key 统一使用 `lens_id.param_name`

10.1 首轮请求：让 Router 判断是否需要追问

```bash
curl -X POST "http://127.0.0.1:8000/api/v1/router/route" ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\":\"u1\",\"user_message\":\"把图里的杯子换成一盆多肉植物\",\"base_image\":\"upload.png\",\"base_image_meta\":{\"width\":1024,\"height\":1024}}"
```

可能返回：

```json
{
  "session_id": "9f5c5d8d-54c0-4b84-9b9d-5c8e7e8c1a11",
  "status": "need_clarification",
  "thought_process": "Planner 认为关键信息仍不完整，需要补充参数。",
  "questions": [
    {
      "id": "lens_replace_subject.prompt",
      "prompt": "请描述你想替换成什么内容",
      "type": "text",
      "options": [],
      "required": true,
      "binds": [
        {
          "step_id": null,
          "lens_id": "lens_replace_subject",
          "target": "param",
          "name": "prompt"
        }
      ],
      "ui_schema": {
        "min": null,
        "max": null,
        "step": null,
        "default": null,
        "allow_custom_text": false
      }
    }
  ],
  "blueprint": null,
  "extra": {
    "retrieved_lenses": [
      "lens_replace_subject"
    ]
  }
}
```

关键点：
- 把返回的 `session_id` 保存下来，用于下一轮继续同一个会话
- 前端或测试脚本不要自己猜参数名，直接用 `questions[].id`

10.2 第二轮请求：带同一个 session_id 回填 answers

```bash
curl -X POST "http://127.0.0.1:8000/api/v1/router/route" ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\":\"u1\",\"session_id\":\"9f5c5d8d-54c0-4b84-9b9d-5c8e7e8c1a11\",\"answers\":{\"lens_replace_subject.prompt\":\"一盆放在木桌上的多肉植物\"}}"
```

可能返回：

```json
{
  "session_id": "9f5c5d8d-54c0-4b84-9b9d-5c8e7e8c1a11",
  "status": "ready",
  "thought_process": "Planner 已补齐参数并输出可执行 DAGBlueprint。",
  "questions": [],
  "blueprint": {
    "initial_inputs": {
      "user_base_image": "upload.png"
    },
    "steps": [
      {
        "step_id": "s1",
        "lens_id": "lens_replace_subject",
        "input_links": {
          "base_image": "$user_base_image"
        },
        "params": {
          "prompt": "一盆放在木桌上的多肉植物"
        }
      }
    ]
  },
  "extra": {
    "retrieved_lenses": [
      "lens_replace_subject"
    ]
  }
}
```

关键点：
- `status=ready` 时，说明 Router 只完成了编排，还没有执行 ComfyUI
- 这时可以由上层业务自己拿 `blueprint` 去执行，或者改用 `/route_and_run`

10.3 一步测试闭环：使用 `/route_and_run`

如果你想在调试阶段验证“追问完成后能否直接执行”，可以使用：

```bash
curl -X POST "http://127.0.0.1:8000/api/v1/router/route_and_run" ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\":\"u1\",\"user_message\":\"把图里的杯子换成一盆多肉植物\",\"base_image\":\"upload.png\",\"execute_when_ready\":true}"
```

当本轮仍需追问时，返回结构和 `/route` 基本一致，但会额外包含：

```json
{
  "status": "need_clarification",
  "executed": false,
  "execution_context": {},
  "result_filename": null,
  "result_url": null,
  "execution_error": null
}
```

当本轮已经 `ready` 且执行成功时，返回会额外带执行结果：

```json
{
  "session_id": "9f5c5d8d-54c0-4b84-9b9d-5c8e7e8c1a11",
  "status": "ready",
  "executed": true,
  "result_filename": "ComfyUI_01234_.png",
  "result_url": "http://127.0.0.1:8188/view?filename=ComfyUI_01234_.png&type=output",
  "execution_error": null,
  "execution_context": {
    "user_base_image": "upload.png",
    "s1.result_image": "ComfyUI_01234_.png"
  },
  "blueprint": {
    "initial_inputs": {
      "user_base_image": "upload.png"
    },
    "steps": [
      {
        "step_id": "s1",
        "lens_id": "lens_replace_subject",
        "input_links": {
          "base_image": "$user_base_image"
        },
        "params": {
          "prompt": "一盆放在木桌上的多肉植物"
        }
      }
    ]
  }
}
```

10.4 两轮闭环测试建议

推荐按下面顺序测试：
1. 第 1 轮调用 `/route_and_run`，确认能收到 `need_clarification`
2. 取出返回的 `session_id` 和 `questions[].id`
3. 第 2 轮再次调用 `/route_and_run`，带上 `session_id + answers`
4. 观察是否返回 `status=ready`、`executed=true`、`result_filename`

第二轮示例：

```bash
curl -X POST "http://127.0.0.1:8000/api/v1/router/route_and_run" ^
  -H "Content-Type: application/json" ^
  -d "{\"user_id\":\"u1\",\"session_id\":\"9f5c5d8d-54c0-4b84-9b9d-5c8e7e8c1a11\",\"answers\":{\"lens_replace_subject.prompt\":\"一盆放在木桌上的多肉植物\"},\"execute_when_ready\":true}"
```

10.5 `/route`、`/answer`、`/compile_or_ask`、`/route_and_run` 的区别

- `/route`：当前推荐主入口。统一支持“首轮编排”和“追问回填”
- `/route_and_run`：调试闭环入口。内部先走 `/route` 的编排，再在 ready 时执行
- `/compile_or_ask`：旧兼容入口。更偏单轮编排语义
- `/answer`：旧兼容入口。只用于回答上一轮追问

推荐实践：
- 正式业务接入优先用 `/route`
- 联调 Router + Compiler 闭环时使用 `/route_and_run`
