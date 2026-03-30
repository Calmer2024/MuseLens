# Router 前端接口对接文档

本文面向前端，对接目标是：

- 用户上传图片并输入自然语言需求
- 后端判断是否需要追问补参
- 补参完成后自动完成透镜检索、编排、参数注入、生成 blueprint
- 按需执行 blueprint 到 ComfyUI
- 返回最终结果图，以及每个透镜步骤的中间结果图，供前端展示

对应后端入口代码：

- `backend/app/api/v1/endpoints/router.py`
- `backend/app/schemas/router.py`

---

## 1. 推荐对接方式

前端推荐使用下面三类接口：

1. `POST /api/v1/router/route`
   用于“编排或追问”，不执行生图。
2. `POST /api/v1/router/route_and_run`
   用于“编排并执行”，支持同步执行，也支持异步流式执行。
3. `WS /api/v1/router/ws/run/{stream_id}`
   用于接收实时执行事件，包括 blueprint 准备完成、某个透镜开始执行、某个透镜执行完成后的中间图、以及整条链执行完成。

辅助接口：

- `GET /api/v1/router/stream/new`
  由后端生成一个新的 `stream_id`，前端如果不想自己生成 UUID，可以先调这个接口。

旧接口 `/compile_or_ask`、`/answer` 仅做兼容，不建议前端新接入时再使用。

---

## 2. 状态机约定

Router 返回的 `status` 只有三种：

- `need_clarification`
  当前信息不足，前端应渲染 `questions` 让用户补充。
- `ready`
  信息已经足够，后端已经生成了可执行 `blueprint`。
- `failed`
  当前候选透镜或依赖不足，无法继续编排。

前端可以按这个状态机处理：

1. 首次调用接口，传 `user_message + base_image`
2. 如果返回 `need_clarification`，展示追问表单
3. 用户回答后，将 `session_id + answers` 再次提交
4. 直到返回 `ready`
5. 若走 `route_and_run`，则在 `ready` 后端会继续执行并返回结果图

---

## 3. 编排接口

### 3.1 接口

`POST /api/v1/router/route`

### 3.2 请求体

```json
{
  "user_id": "u1",
  "session_id": null,
  "user_message": "把图中的女人替换成一只狗",
  "base_image": "upload.png",
  "base_image_meta": {},
  "answers": {}
}
```

字段说明：

- `user_id`
  用户标识，可为空字符串，但建议前端传真实用户 ID。
- `session_id`
  新会话可不传；如果是回答追问，必须传上一次返回的 `session_id`。
- `user_message`
  用户本轮自然语言输入。新会话通常必填。
- `base_image`
  已上传到 ComfyUI input 目录中的图片文件名。
- `base_image_meta`
  可选元信息，当前可留空对象。
- `answers`
  追问回答时填写，格式为 `问题ID -> 答案`。

### 3.3 `need_clarification` 响应示例

```json
{
  "session_id": "a1b2c3",
  "status": "need_clarification",
  "thought_process": "参数信息不足，需要向用户追问补齐。",
  "questions": [
    {
      "id": "lens_flux_inpaint.prompt",
      "prompt": "请描述你希望替换成什么内容",
      "type": "text",
      "options": [],
      "required": true,
      "binds": [
        {
          "step_id": null,
          "lens_id": "lens_flux_inpaint",
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
      "lens_flux_inpaint",
      "lens_sam2_matting"
    ]
  }
}
```

前端处理规则：

- 保存 `session_id`
- 按 `questions` 渲染输入控件
- 用户提交后，把答案放入 `answers`
- 再次调用 `/api/v1/router/route` 或 `/api/v1/router/route_and_run`

### 3.4 回答追问请求示例

```json
{
  "user_id": "u1",
  "session_id": "a1b2c3",
  "user_message": null,
  "base_image": null,
  "base_image_meta": {},
  "answers": {
    "lens_flux_inpaint.prompt": "把图中的女人替换成一只写实的狗，保持背景不变"
  }
}
```

### 3.5 `ready` 响应示例

```json
{
  "session_id": "a1b2c3",
  "status": "ready",
  "thought_process": "已生成可执行 Blueprint。",
  "questions": [],
  "blueprint": {
    "initial_inputs": {
      "user_base_image": "upload.png"
    },
    "steps": [
      {
        "step_id": "step_1_sam2_matting",
        "lens_id": "lens_sam2_matting",
        "input_links": {
          "base_image": "$user_base_image"
        },
        "params": {
          "prompt": "女人"
        }
      },
      {
        "step_id": "step_2_flux_inpaint",
        "lens_id": "lens_flux_inpaint",
        "input_links": {
          "base_image": "$user_base_image",
          "mask": "$step_1_sam2_matting.mask_result"
        },
        "params": {
          "prompt": "把图中的女人替换成一只写实的狗，保持背景不变"
        }
      }
    ]
  },
  "extra": {
    "retrieved_lenses": [
      "lens_flux_inpaint",
      "lens_sam2_matting"
    ]
  }
}
```

前端此时可以：

- 只展示编排结果，不执行
- 或者直接调用 `/api/v1/router/route_and_run`

---

## 4. 编排并执行接口

### 4.1 接口

`POST /api/v1/router/route_and_run`

### 4.1.1 配套 WebSocket

`WS /api/v1/router/ws/run/{stream_id}`

推荐前端先建立 WebSocket，再调用 `route_and_run(async_execution=true)`。

### 4.2 请求体

```json
{
  "user_id": "u1",
  "session_id": null,
  "user_message": "帮我把这张图片改成宫崎骏风格",
  "base_image": "upload.png",
  "base_image_meta": {},
  "answers": {},
  "execute_when_ready": true,
  "async_execution": false,
  "stream_id": null
}
```

字段说明：

- 前 6 个字段与 `/route` 相同
- `execute_when_ready`
  默认为 `true`
  - `true`：如果编排成功，立即执行
  - `false`：只编排，不执行，但返回结构仍是 `route_and_run` 的响应格式
- `async_execution`
  默认为 `false`
  - `false`：同步执行，HTTP 一直等待到执行完成后返回
  - `true`：异步流式执行，HTTP 会先返回 `blueprint`，实时执行状态和中间图通过 WebSocket 推送
- `stream_id`
  流式执行通道 ID。当前端使用 `async_execution=true` 时必填。
  建议前端自己生成 UUID，并先连接 `WS /api/v1/router/ws/run/{stream_id}`。

### 4.3 响应字段

除了 `RouterResponse` 的通用字段外，还额外返回：

- `executed`
  是否真的执行了 blueprint
- `execution_context`
  扁平上下文，键通常为 `step_id.output_name`
- `result_filename`
  最终结果文件名
- `result_url`
  最终结果图预览地址
- `execution_error`
  执行错误信息
- `execution_started`
  是否已成功启动执行任务
- `stream_id`
  本次执行关联的实时通道 ID
- `step_results`
  已整理好的步骤结果列表。同步执行时会在 HTTP 响应里返回；异步流式执行时会在最终 `execution_completed` 事件中返回

### 4.4 成功响应示例

```json
{
  "session_id": "a1b2c3",
  "status": "ready",
  "thought_process": "已生成可执行 Blueprint。",
  "questions": [],
  "blueprint": {
    "initial_inputs": {
      "user_base_image": "upload.png"
    },
    "steps": [
      {
        "step_id": "step_1_lora_filter",
        "lens_id": "lens_lora_filter",
        "input_links": {
          "base_image": "$user_base_image"
        },
        "params": {
          "lora_name": "Studio Ghibli Style.safetensors",
          "prompt": "Studio Ghibli inspired hand-drawn animation aesthetic, soft warm natural lighting, clean colors, dreamy whimsical atmosphere, preserve the subject and composition"
        }
      }
    ]
  },
  "extra": {
    "retrieved_lenses": [
      "lens_lora_filter",
      "lens_flux_edit"
    ]
  },
  "executed": true,
  "execution_context": {
    "user_base_image": "upload.png",
    "step_1_lora_filter.result_image": "MuseLens_Lora_00001_.png"
  },
  "result_filename": "MuseLens_Lora_00001_.png",
  "result_url": "http://127.0.0.1:8188/view?filename=MuseLens_Lora_00001_.png&type=output",
  "execution_error": null,
  "step_results": [
    {
      "step_id": "step_1_lora_filter",
      "lens_id": "lens_lora_filter",
      "outputs": [
        {
          "output_name": "result_image",
          "filename": "MuseLens_Lora_00001_.png",
          "url": "http://127.0.0.1:8188/view?filename=MuseLens_Lora_00001_.png&type=output"
        }
      ]
    }
  ]
}
```

---

## 5. `questions` 字段如何渲染

`questions` 中每一项的结构如下：

- `id`
  问题唯一 ID。前端回传时直接作为 `answers` 的 key。
- `prompt`
  展示给用户的问题文案。
- `type`
  当前常见值是 `text`，后续也可能出现：
  - `single_choice`
  - `multi_choice`
  - `slider`
- `options`
  选项数组。文本问题通常为空。
- `required`
  是否必填。
- `binds`
  描述答案最终绑定到哪个 lens 的哪个参数。
- `ui_schema`
  可用于渲染控件约束，例如默认值、滑条范围等。

前端回传时，不需要自己理解 `binds` 的内部逻辑，只需要按 `id -> 用户答案` 提交即可。

---

## 6. WebSocket 实时事件协议

当使用流式执行时，前端应：

1. 先生成一个 `stream_id`
2. 连接 `WS /api/v1/router/ws/run/{stream_id}`
3. 再调用 `POST /api/v1/router/route_and_run`，并传：
   - `async_execution=true`
   - `stream_id`

### 6.1 连接成功事件

```json
{
  "event": "connected",
  "stream_id": "stream-123"
}
```

### 6.2 HTTP 启动响应示例

当传入 `async_execution=true` 时，HTTP 会先返回 blueprint 和启动状态，不等待最终出图：

```json
{
  "session_id": "a1b2c3",
  "status": "ready",
  "questions": [],
  "blueprint": {
    "initial_inputs": {
      "user_base_image": "upload.png"
    },
    "steps": [
      {
        "step_id": "step_1_sam2_matting",
        "lens_id": "lens_sam2_matting",
        "input_links": {
          "base_image": "$user_base_image"
        },
        "params": {
          "prompt": "女人"
        }
      },
      {
        "step_id": "step_2_flux_inpaint",
        "lens_id": "lens_flux_inpaint",
        "input_links": {
          "base_image": "$user_base_image",
          "mask": "$step_1_sam2_matting.mask_result"
        },
        "params": {
          "prompt": "把图中的女人替换成一只狗"
        }
      }
    ]
  },
  "executed": false,
  "execution_started": true,
  "stream_id": "stream-123",
  "execution_context": {},
  "result_filename": null,
  "result_url": null,
  "execution_error": null,
  "step_results": []
}
```

前端此时应：

- 立刻根据 `blueprint.steps` 渲染透镜执行流
- 同时继续监听 `WS /api/v1/router/ws/run/{stream_id}` 的实时事件

### 6.3 Blueprint 准备完成

当 Router 已完成透镜编排并生成 blueprint，但执行尚未开始时：

```json
{
  "event": "blueprint_ready",
  "session_id": "a1b2c3",
  "stream_id": "stream-123",
  "status": "ready",
  "blueprint": {
    "initial_inputs": {
      "user_base_image": "upload.png"
    },
    "steps": [
      {
        "step_id": "step_1_sam2_matting",
        "lens_id": "lens_sam2_matting",
        "input_links": {
          "base_image": "$user_base_image"
        },
        "params": {
          "prompt": "女人"
        }
      }
    ]
  }
}
```

前端可以用这个事件立即渲染透镜执行流。

### 6.4 整体执行开始

```json
{
  "event": "execution_started",
  "session_id": "a1b2c3",
  "stream_id": "stream-123",
  "blueprint": {
    "...": "..."
  }
}
```

### 6.5 单个透镜开始执行

```json
{
  "event": "step_started",
  "session_id": "a1b2c3",
  "stream_id": "stream-123",
  "step_id": "step_1_sam2_matting",
  "lens_id": "lens_sam2_matting",
  "step_index": 1,
  "total_steps": 2
}
```

前端可以用这个事件高亮“当前正在执行的透镜”。

### 6.6 单个透镜执行完成

```json
{
  "event": "step_completed",
  "session_id": "a1b2c3",
  "stream_id": "stream-123",
  "step_id": "step_1_sam2_matting",
  "lens_id": "lens_sam2_matting",
  "outputs": [
    {
      "output_name": "mask_result",
      "filename": "ComfyUI_00147_.png",
      "url": "http://127.0.0.1:8188/view?filename=ComfyUI_00147_.png&type=output"
    }
  ]
}
```

前端可以用这个事件实时展示该透镜的中间结果图。

### 6.7 整体执行完成

```json
{
  "event": "execution_completed",
  "session_id": "a1b2c3",
  "stream_id": "stream-123",
  "execution_context": {
    "user_base_image": "upload.png",
    "step_1_sam2_matting.mask_result": "ComfyUI_00147_.png",
    "step_2_flux_inpaint.result_image": "Flux2-Klein-4b-base_00025_.png"
  },
  "result_filename": "Flux2-Klein-4b-base_00025_.png",
  "result_url": "http://127.0.0.1:8188/view?filename=Flux2-Klein-4b-base_00025_.png&type=output",
  "step_results": [
    {
      "step_id": "step_1_sam2_matting",
      "lens_id": "lens_sam2_matting",
      "outputs": [
        {
          "output_name": "mask_result",
          "filename": "ComfyUI_00147_.png",
          "url": "http://127.0.0.1:8188/view?filename=ComfyUI_00147_.png&type=output"
        }
      ]
    }
  ]
}
```

### 6.8 执行失败

```json
{
  "event": "execution_failed",
  "session_id": "a1b2c3",
  "stream_id": "stream-123",
  "error": "ComfyUI /prompt returned 400: ..."
}
```

---

## 7. `step_results` 字段如何展示

这是前端展示“每个透镜产生了什么图”的推荐字段。

结构如下：

```json
[
  {
    "step_id": "step_1_sam2_matting",
    "lens_id": "lens_sam2_matting",
    "outputs": [
      {
        "output_name": "mask_result",
        "filename": "ComfyUI_00147_.png",
        "url": "http://127.0.0.1:8188/view?filename=ComfyUI_00147_.png&type=output"
      }
    ]
  },
  {
    "step_id": "step_2_flux_inpaint",
    "lens_id": "lens_flux_inpaint",
    "outputs": [
      {
        "output_name": "result_image",
        "filename": "Flux2-Klein-4b-base_00025_.png",
        "url": "http://127.0.0.1:8188/view?filename=Flux2-Klein-4b-base_00025_.png&type=output"
      }
    ]
  }
]
```

推荐前端展示方式：

- 左侧显示步骤列表：`step_id + lens_id`
- 右侧显示该 step 的所有输出图
- 如果有 `mask_result`、`depth_map`、`canny_map`、`pose_map` 这类中间资产，也可以展示成“过程图”
- 最终结果图优先使用顶层 `result_url`

---

## 8. 失败场景处理

### 7.1 编排失败

响应特征：

- `status = failed`
- `blueprint = null`
- `execution_error = null`

此时说明问题发生在“检索 / 编排 / 静态校验”阶段。

前端建议：

- 展示 `thought_process`
- 如果 `extra.validation_errors` 存在，也一并展示

### 7.2 执行失败

响应特征：

- `status = ready`
- `executed = false` 或 `executed = true`
- `execution_error != null`

此时说明 blueprint 已生成，但在执行阶段失败。

前端建议：

- 保留并展示 `blueprint`
- 展示 `execution_error`
- 允许用户重试

---

## 9. 前端最小接入流程

### 方案 A：逐步编排

适合做“先确认计划，再执行”的交互。

1. 调 `/api/v1/router/route`
2. 如果 `need_clarification`，渲染追问
3. 用户答完后继续调 `/api/v1/router/route`
4. 当返回 `ready` 后，再决定是否执行

### 方案 B：直接出图

适合做“立即生成”按钮。

1. 调 `/api/v1/router/route_and_run`
2. 如果 `need_clarification`，渲染追问
3. 用户答完后继续调 `/api/v1/router/route_and_run`
4. 当返回 `ready + executed=true` 后，展示：
   - `result_url`
   - `step_results`

### 方案 C：实时执行流

适合做“透镜流程图 + 实时中间图”的正式交互。

1. 前端生成 `stream_id`
   或先调 `GET /api/v1/router/stream/new`
2. 连接 `WS /api/v1/router/ws/run/{stream_id}`
3. 调 `/api/v1/router/route_and_run`，并传：
   - `execute_when_ready=true`
   - `async_execution=true`
   - `stream_id`
4. HTTP 响应会先返回 `blueprint`
5. WebSocket 依次收到：
   - `blueprint_ready`
   - `execution_started`
   - 多次 `step_started`
   - 多次 `step_completed`
   - `execution_completed` 或 `execution_failed`

---

## 10. 前端实现建议

- 将 `session_id` 保存在当前编辑会话中，直到本轮任务结束
- 每轮追问都复用同一个 `session_id`
- 不要手动拼 blueprint 参数，统一交给后端
- 如果要实时展示透镜执行流，优先使用 `async_execution=true + WebSocket`
- 展示流程图时优先使用 `blueprint.steps`
- 展示步骤产物时优先使用 WebSocket 的 `step_completed` 和最终 `execution_completed.step_results`
- 如果只想拿最终图，使用 `result_url`
- 如果想做“高级模式”，可同时把 `blueprint` 展示给用户查看

---

## 11. 当前已知边界

- 当前接口已支持“追问 -> 回答 -> 重新编排 -> 执行”
- 当前接口已支持实时返回每个透镜步骤的开始状态和中间结果图
- 当前仍未单独暴露数值型 `confidence_score`，前端应以 `status` 作为是否继续追问的判断依据
- 同步执行和异步流式执行都已支持；如果前端要做实时流程图，推荐使用异步流式执行
