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
- `POST /api/v1/lenses/run`
  透镜直连执行接口。适合前端已明确选择某个透镜，并且用户已经手动填写好该透镜所需参数与资产，不需要 LLM 参与。
- `GET /api/v1/lenses/stream/new`
  为透镜直连执行模式生成 `stream_id`。
- `GET /api/v1/lenses/{lens_id}/tweak-controls`
  获取某个透镜的微调控件定义。
- `POST /api/v1/lenses/mask-assets`
  保存前端 `mask_editor` 画出的遮罩 PNG，返回可直接写入 `user_assets` 的资产信息。
- `POST /api/v1/lenses/mask-assets/upload`
  直接上传 PNG 遮罩文件。适合前端拿到 `File` / `Blob` 后直接提交，不必先转 base64。

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
  "user_assets": {
    "mask": "user_mask.png"
  },
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
- `user_assets`
  用户额外提供的资产映射，例如：
  - `mask`
  - `style_reference_image`
  - `ref_image_1`
  这些资产会被注入 blueprint 的 `initial_inputs`，供后续透镜直接消费。
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

### 方案 D：先涂抹遮罩，再走 Router 编排

适合局部替换、局部重绘、局部光影调整。

1. 前端先让用户在原图上涂抹，得到 PNG 或 base64 遮罩
2. 调 `POST /api/v1/lenses/mask-assets`
3. 后端返回例如：

```json
{
  "asset_name": "mask",
  "filename": "mask_xxx.png",
  "preview_url": "http://127.0.0.1:8188/view?filename=mask_xxx.png&type=input",
  "prompt_hint": "woman",
  "source": "mask_editor",
  "mime_type": "image/png",
  "byte_size": 24576,
  "width": 1024,
  "height": 1024,
  "metadata": {
    "origin": "canvas"
  },
  "user_assets_patch": {
    "mask": "mask_xxx.png"
  }
}
```

4. 前端拿返回的 `user_assets_patch`
5. 调 `/api/v1/router/route` 或 `/api/v1/router/route_and_run`
4. 在请求体里附带：

```json
{
  "user_assets": {
    "mask": "user_mask.png"
  }
}
```

6. 后端会把该遮罩资产注入 blueprint 的 `initial_inputs`
7. 如果后续透镜需要 `mask` 输入，例如 `lens_flux_inpaint`，就可以直接消费这个用户资产

补充：

- `POST /api/v1/lenses/mask-assets`
  - 使用 JSON 请求体上传 base64 / data URL
- `POST /api/v1/lenses/mask-assets/upload`
  - 使用 `multipart/form-data` 直接上传 PNG 文件
  - 字段：`file`、`asset_name`、`prompt_hint`、`filename`、`source`、`metadata_json`

---

## 10. 透镜直连执行接口

适用于：

- 前端已经让用户手动选择了某个透镜
- 前端表单已经根据透镜 schema 收集好了该透镜所需 `params`
- 用户也已经选好了该透镜需要的输入图片或其他资产
- 不需要 Router 检索、追问或 LLM 编排

### 10.1 接口

`POST /api/v1/lenses/run`

### 10.2 请求体

```json
{
  "lens_id": "lens_flux_edit",
  "assets": {
    "base_image": "upload.png"
  },
  "params": {
    "prompt": "golden sunset lighting from the upper right"
  },
  "async_execution": false,
  "stream_id": null
}
```

字段说明：

- `lens_id`
  要执行的透镜 ID
- `assets`
  前端直接填写的输入资产映射，键必须对应透镜 input 名称
- `params`
  前端直接填写的参数映射，键必须对应透镜 param 名称
- `async_execution`
  是否异步流式执行
- `stream_id`
  若使用异步流式执行，则传入流式通道 ID

### 10.3 同步响应示例

```json
{
  "lens_id": "lens_flux_edit",
  "blueprint": {
    "initial_inputs": {
      "base_image": "upload.png"
    },
    "steps": [
      {
        "step_id": "step_1_direct_lens",
        "lens_id": "lens_flux_edit",
        "input_links": {
          "base_image": "$base_image"
        },
        "params": {
          "prompt": "golden sunset lighting from the upper right"
        }
      }
    ]
  },
  "executed": true,
  "execution_started": true,
  "stream_id": null,
  "execution_context": {
    "base_image": "upload.png",
    "step_1_direct_lens.result_image": "Flux2-Klein-4b-base_00031_.png"
  },
  "result_filename": "Flux2-Klein-4b-base_00031_.png",
  "result_url": "http://127.0.0.1:8188/view?filename=Flux2-Klein-4b-base_00031_.png&type=output",
  "execution_error": null,
  "step_results": [
    {
      "step_id": "step_1_direct_lens",
      "lens_id": "lens_flux_edit",
      "outputs": [
        {
          "output_name": "result_image",
          "filename": "Flux2-Klein-4b-base_00031_.png",
          "url": "http://127.0.0.1:8188/view?filename=Flux2-Klein-4b-base_00031_.png&type=output"
        }
      ]
    }
  ]
}
```

### 10.4 异步流式执行

透镜直连执行也复用同一套 WebSocket：

- `WS /api/v1/router/ws/run/{stream_id}`

推荐流程：

1. 先调用 `GET /api/v1/lenses/stream/new` 获取 `stream_id`
2. 连接 `WS /api/v1/router/ws/run/{stream_id}`
3. 调 `POST /api/v1/lenses/run`
4. 传：
   - `async_execution=true`
   - `stream_id`
5. 后续同样接收：
   - `blueprint_ready`
   - `execution_started`
   - `step_started`
   - `step_completed`
   - `execution_completed` 或 `execution_failed`

### 10.5 适合的前端场景

- 透镜市场详情页中，用户点“直接试用当前透镜”
- 高级模式下，用户手动搭配参数而不走自然语言
- 某些固定工作流面板，前端本身就知道该用哪个 Lens

### 10.6 微调控件定义

对于以下透镜，后端会返回预定义的 `tweak_controls`，供前端渲染更适合的微调 UI：

- `lens_sam2_matting`
  - 关键控件：`mask_editor`
  - 用途：在 AI 初始分割基础上，允许用户手动补画 / 擦除遮罩
  - 产物：建议前端导出为新的 PNG/base64 遮罩，再先调 `POST /api/v1/lenses/mask-assets` 保存，然后通过 `user_assets.mask` 或 `/api/v1/lenses/run` 的 `assets.mask` 回传
- `lens_relighting`
  - 关键控件：`light_orb`
  - 用途：拖拽光源位置，控制 prompt 和步数微调
- `lens_depth_of_field`
  - 关键控件：`tap_to_focus`、`aperture_dial`
  - 用途：点击对焦点、拨动景深强度
- `lens_style`
  - 关键控件：`style_intensity`、`structure_preservation`
- `lens_lora_filter`
  - 关键控件：`filter_selector`、`filter_opacity`

前端可通过：

- `GET /api/v1/lenses/{lens_id}`
- 或 `GET /api/v1/lenses/{lens_id}/tweak-controls`

获取该透镜的 `tweak_controls` 定义。

### 10.7 微调控件应用接口

当前推荐前端在用户拖动微调控件后，调用：

- `POST /api/v1/lenses/{lens_id}/apply-controls`

该接口会把控件值翻译成底层 params 或 assets，并可选择直接执行。

请求示例：

```json
{
  "assets": {
    "base_image": "upload.png",
    "depth_map": "depth.png"
  },
  "current_params": {
    "prompt": "initial prompt"
  },
  "control_values": {
    "light_orb": {
      "x": 0.8,
      "y": 0.2,
      "z": 0.7,
      "intensity": 0.9,
      "color_temperature": 3800
    }
  },
  "execute": true,
  "async_execution": false,
  "stream_id": null
}
```

返回里会包含：

- `translated_params`
  仅由这次控件操作翻译出的参数增量
- `translated_assets`
  仅由这次控件操作翻译出的资产增量
- `merged_params`
  与当前参数合并后的完整参数
- `merged_assets`
  与当前资产合并后的完整资产
- `execution`
  若 `execute=true`，则返回实际执行结果

### 10.8 哪些控件会调用 LLM

当前只有以下场景会调用 LLM 参与翻译：

- `lens_relighting.light_orb`
  - 原因：光球坐标、强度、色温并不是简单数组直接映射，更适合翻译为摄影语义 prompt

以下控件目前只做规则映射，不调用 LLM：

- `lens_depth_of_field.tap_to_focus`
- `lens_depth_of_field.aperture_dial`
- `lens_style.style_intensity`
- `lens_style.structure_preservation`
- `lens_lora_filter.filter_selector`
- `lens_lora_filter.filter_opacity`
- `lens_sam2_matting.mask_editor`

---

## 11. 前端实现建议

- 将 `session_id` 保存在当前编辑会话中，直到本轮任务结束
- 每轮追问都复用同一个 `session_id`
- 不要手动拼 blueprint 参数，统一交给后端
- 如果要实时展示透镜执行流，优先使用 `async_execution=true + WebSocket`
- 展示流程图时优先使用 `blueprint.steps`
- 展示步骤产物时优先使用 WebSocket 的 `step_completed` 和最终 `execution_completed.step_results`
- 如果只想拿最终图，使用 `result_url`
- 如果想做“高级模式”，可同时把 `blueprint` 展示给用户查看
- 如果前端已经明确选定某个透镜并采集好表单参数，优先使用 `/api/v1/lenses/run`

---

## 12. 当前已知边界

- 当前接口已支持“追问 -> 回答 -> 重新编排 -> 执行”
- 当前接口已支持实时返回每个透镜步骤的开始状态和中间结果图
- 当前仍未单独暴露数值型 `confidence_score`，前端应以 `status` 作为是否继续追问的判断依据
- 同步执行和异步流式执行都已支持；如果前端要做实时流程图，推荐使用异步流式执行


## 13. 清晰版能力清单与前端接入方案

这一节覆盖前端最关心的几个问题：哪些能力已经实现，哪些是部分实现，以及每一类功能应该怎么调用接口。

### 13.1 能力清单

已实现：

- 用户通过“上传图片 + 自然语言对话”发起生图
- 后端自动完成追问、透镜选择、参数注入、生成 blueprint、执行生图
- 前端可以拿到 blueprint，并渲染透镜执行流
- 生图过程中，前端可以实时收到每个透镜的开始执行状态
- 生图过程中，前端可以实时收到每个透镜执行完成后的中间结果图
- 前端可以直接调用单个透镜执行，不经过 Router 对话
- 部分透镜支持前端微调控件，控件值可翻译为底层 params/assets 并重新执行
- 用户手工涂抹的遮罩可以保存为资产，并参与 Router 编排或单透镜执行
- 工作流执行完成后，前端可以拿到每个 step 对应的 `tweak_controls`

部分实现：

- 工作流执行完成后，前端可以对某一个 step 单独做微调并重新执行该 step

未完全闭环：

- 修改工作流中间某一步后，自动接着重跑该步后面的所有 downstream steps

对前端的准确承诺应该是：

- 可以做“对话式编排 + 实时执行展示 + 中间图展示”
- 可以做“用户先涂抹 mask，再参与 Router 编排并直接执行”
- 可以做“单透镜直接运行”
- 可以做“单透镜级微调”
- 可以做“工作流中某一步的步骤级微调”
- 暂时不要承诺“改一个中间步骤后，后端自动续跑整条后半段 DAG”

### 13.2 场景 A：用户上传图片，通过对话生图

适用：

- “把图中的女人替换成一只狗”
- “把背景换成埃菲尔铁塔”
- “改成宫崎骏风格”

前端接法：

1. 先上传原图，得到 `base_image` 文件名
2. 调 `POST /api/v1/router/route_and_run`
3. 推荐同时开启实时执行：
   - 先调 `GET /api/v1/router/stream/new`
   - 再连 `WS /api/v1/router/ws/run/{stream_id}`
   - 然后调 `route_and_run`

推荐请求体：

```json
{
  "user_id": "u1",
  "session_id": null,
  "user_message": "把图中的女人替换成一只狗",
  "base_image": "upload.png",
  "base_image_meta": {},
  "user_assets": {},
  "answers": {},
  "execute_when_ready": true,
  "async_execution": true,
  "stream_id": "stream_id"
}
```

前端逻辑：

- 如果返回 `status = need_clarification`
  - 渲染 `questions`
  - 保存 `session_id`
  - 用户作答后，把答案写入 `answers`
  - 带同一个 `session_id` 再次调用
- 如果返回 `status = ready`
  - 读取 `blueprint`
  - 渲染执行流
  - 如果已经 `execute_when_ready=true`，继续监听 WebSocket

### 13.3 场景 B：用户先涂抹遮罩，再让后端直接执行

这是你提到的这类需求：

- 用户上传图片
- 用户输入 prompt，比如“把这些人消除掉”
- 用户在前端手工涂抹生成遮罩
- 后端直接执行

这条链路当前已经具备。

正确实现方式：

1. 用户上传原图，得到 `base_image`
2. 前端让用户在图片上涂抹，生成 mask
3. 前端把 mask 保存成后端资产
4. 前端把返回的 `user_assets_patch` 合并进 Router 请求体的 `user_assets`
5. 调 `POST /api/v1/router/route_and_run`
6. 后端在编排时把这个遮罩放进 `blueprint.initial_inputs`
7. 如果选中的透镜需要 `mask`，例如 `lens_flux_inpaint`，会优先消费这个用户遮罩

保存遮罩有两种方式：

- `POST /api/v1/lenses/mask-assets`
  - JSON 方式
  - 适合前端直接拿到 base64 / data URL
- `POST /api/v1/lenses/mask-assets/upload`
  - `multipart/form-data`
  - 适合前端直接拿到 `File` / `Blob`

遮罩保存后会返回：

- `filename`
- `preview_url`
- `user_assets_patch`
- `width`
- `height`
- `byte_size`
- `source`
- `metadata`

前端要做的事是把这个结果里的 `user_assets_patch` 合并到 Router 请求：

```json
{
  "user_assets": {
    "mask": "mask_xxx.png"
  }
}
```

然后调用：

```json
{
  "user_id": "u1",
  "user_message": "把这些人消除掉",
  "base_image": "upload.png",
  "user_assets": {
    "mask": "mask_xxx.png"
  },
  "answers": {},
  "execute_when_ready": true,
  "async_execution": true,
  "stream_id": "stream_id"
}
```

### 13.4 场景 C：前端展示 blueprint、实时状态和中间结果图

这部分已经实现。

前端应使用：

- `GET /api/v1/router/stream/new`
- `WS /api/v1/router/ws/run/{stream_id}`
- `POST /api/v1/router/route_and_run`

推荐流程：

1. 获取 `stream_id`
2. 建立 WebSocket
3. 调 `route_and_run`，传：
   - `async_execution = true`
   - `execute_when_ready = true`
   - `stream_id`
4. HTTP 首次返回后：
   - 读取 `blueprint`
   - 立即渲染流程图
5. 继续监听 WebSocket 事件

前端需要处理的 WebSocket 事件：

- `connected`
  - 连接成功
- `blueprint_ready`
  - blueprint 已生成，可渲染透镜执行流
- `execution_started`
  - 整体工作流开始执行
- `step_started`
  - 某个透镜开始执行，可高亮当前步骤
- `step_completed`
  - 某个透镜执行完成，可展示该步中间图
- `execution_completed`
  - 整条链完成，可展示最终结果图和完整 step_results
- `execution_failed`
  - 展示错误

前端显示来源建议：

- 流程图：`blueprint.steps`
- 当前执行中的 step：`step_started`
- 中间图：`step_completed.outputs`
- 最终结果图：`result_url`
- 整体结果回顾：`execution_completed.step_results`

### 13.5 场景 D：前端直接调用单个透镜执行

这部分已经实现。

适用：

- 透镜市场
- 透镜详情页
- 高级模式
- 前端已经知道要用哪个透镜，不需要 Router 编排

使用接口：

- `POST /api/v1/lenses/run`

示例：

```json
{
  "lens_id": "lens_flux_edit",
  "assets": {
    "base_image": "upload.png"
  },
  "params": {
    "prompt": "golden sunset lighting from the upper right"
  },
  "async_execution": false,
  "stream_id": null
}
```

如果单透镜也要实时执行：

1. 调 `GET /api/v1/lenses/stream/new`
2. 建立 `WS /api/v1/router/ws/run/{stream_id}`
3. 调 `POST /api/v1/lenses/run`
4. 传：
   - `async_execution = true`
   - `stream_id`

### 13.6 场景 E：前端给单个透镜挂微调控件

这部分已经实现，但仅对已定义 `tweak_controls` 的透镜成立。

前端接法：

1. 调 `GET /api/v1/lenses/{lens_id}`
   或 `GET /api/v1/lenses/{lens_id}/tweak-controls`
2. 根据返回的 `tweak_controls` 渲染控件
3. 用户调整控件后，调：
   - `POST /api/v1/lenses/{lens_id}/apply-controls`
4. 后端把控件值翻译成 params/assets
5. 若 `execute = true`，则直接重新执行

当前重点支持的控件：

- `lens_sam2_matting.mask_editor`
- `lens_relighting.light_orb`
- `lens_depth_of_field.tap_to_focus`
- `lens_depth_of_field.aperture_dial`
- `lens_style.style_intensity`
- `lens_style.structure_preservation`
- `lens_lora_filter.filter_selector`
- `lens_lora_filter.filter_opacity`

注意：

- 不是所有透镜都有 tweak_controls
- 没有 tweak_controls 的透镜，前端应退回到“普通参数表单 + `/api/v1/lenses/run`”

### 13.7 场景 F：工作流执行完成后，用户继续微调其中某一步

当前是“基础能力已具备”，但不是完整的“工作流级重跑”。

已经有的：

- `route_and_run` 返回 `blueprint`
- `step_results` 返回每个步骤的 `tweak_controls`
- 前端可以知道某一步用的是哪个透镜，以及它支持哪些控件

所以当前前端可以这样做：

1. 用户查看某个 step 的结果图
2. 前端读取该 step 的 `tweak_controls`
3. 前端渲染对应控件
4. 用户调节控件
5. 前端重新组织这一单步所需的 `assets` 和 `current_params`
6. 调：
   - `POST /api/v1/lenses/{lens_id}/apply-controls`
   - 或 `POST /api/v1/lenses/run`
7. 后端重新执行这个单步透镜

当前还没有完整实现的是：

- 改完工作流中间某一步以后，后端自动把新结果继续喂给后续步骤并完整续跑

所以前端不要误判成“工作流编辑器已经完整打通”。

### 13.8 前端必须遵守的对接规则

- 对话式任务统一走 Router，不要前端自己拼 blueprint 语义
- 只有用户明确选了某个透镜时，才走 `/api/v1/lenses/run`
- 走实时执行时，必须先建 WebSocket，再发起执行
- 对话式任务要保存 `session_id`
- 追问场景下，每轮都复用同一个 `session_id`
- 有用户手工 mask 时，先保存成资产，再通过 `user_assets` 传给 Router
- 展示流程图时，以 `blueprint.steps` 为准
- 展示中间图时，优先用 WebSocket 的 `step_completed`
- 展示最终结果时，优先用 `result_url`

### 13.9 推荐的前端页面拆分

推荐分成四块：

1. 对话生图页
   - `route_and_run`
   - `questions`
   - `blueprint`
   - WebSocket 实时执行

2. 遮罩编辑器
   - 生成 mask
   - 调 `mask-assets` 或 `mask-assets/upload`
   - 返回 `user_assets_patch`

3. 单透镜试用页
   - `GET /api/v1/lenses/{lens_id}`
   - `POST /api/v1/lenses/run`

4. 微调面板
   - `GET /api/v1/lenses/{lens_id}/tweak-controls`
   - `POST /api/v1/lenses/{lens_id}/apply-controls`

### 13.10 当前最准确的交付边界

前端可以按下面这个边界对外说明：

- 已支持：对话式生图
- 已支持：实时展示透镜执行状态
- 已支持：实时展示每一步中间结果图
- 已支持：遮罩资产上传/保存，并参与 Router 编排
- 已支持：单透镜直接执行
- 已支持：单透镜微调控件
- 已支持：工作流中某一步的步骤级微调
- 暂未完整支持：工作流中间步骤修改后的整条后半链自动续跑
