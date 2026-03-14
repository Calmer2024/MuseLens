# Phase 2 实施总结：控制流与数据流解耦 (DAG 管线异步化)

在 Phase 2 的重构中，我们彻底舍弃了最初快速跑通但难以扩展的硬连接方案，系统性地升华了后端的调度引擎，使框架真正具备了对接复杂 LLM 智能体的“中间件”质感。

## 1. 核心工作总结

本次重构主要在 4 个维度进行了核心改造：

1. **底层数据结构纯粹化 (`schemas/lens.py`)**
   将原有的图节点依赖划分为 **“数据流” (Asset: Image, Mask, Depth 等决定拓扑流向的重资产)** 与 **“控制流” (Param: Prompt, Denoise 等只起修饰作用的标量)**。定义了声明式的图编排基石 `DAGBlueprint` 和 `DAGStep`。
2. **注册表剥离执行态 (`lenses/registry.py`)**
   更新现存的透镜模板（如 SAM2 抠图、SDXL Inpaint 等），它们现在只做参数规范声明，不再执行数据的深拷贝和组装，做到了配置态与运行态解耦。
3. **引入真实的拓扑解析与 IO 搬运机制 (`services/compiler.py`)**
   现在的编排器 `MuseDNACompiler` 能够识别类似 `$step_1_matting.mask_result` 的**上下文引用变量**。当运行到某个节点时，会从黑板字典中动态提取真实文件名，并利用内置机制安全地从 ComfyUI `output` 逆向搬运回 `input` 供给下游使用。
4. **底层轮子完全协程化 (`services/comfy_service.py`)**
   废弃由 `urllib` / 阻塞式 `websocket-client` 组成的旧调度，通过 `httpx.AsyncClient` 实现了 `AsyncComfyRunner`。从而支撑起了非阻塞大并发请求以及 WebSocekt 的图进度双向长连接。

## 2. Phase 1 vs Phase 2 异同与优点对标

| 维度 | Phase 1 (旧) | Phase 2 (新) | Phase 2 核心优势 |
| --- | --- | --- | --- |
| **管道连线** | 代码硬编码前后节点、固定读写写死的文件名 | 采用声明式的变量寻址 (如 `$step_1.result`)，由编译器动态提取 | **高维扩展性**：LLM Agent 只需像写程序一样指定变量名即可编排出极度复杂的 N 步接力流，而不再需要关心底层物理文件。 |
| **控制与数据** | `LensInput` 大乱炖，图结构参数与控制参数无区别对待 | 分离为 `LensAsset` (资产/拓扑连线) 和 `LensParam` (控制/LLM可控) | **职责分明**：为未来防呆机制打下基础，前端面板能够明确知道哪些参数生成滑块（Param），哪些生成连线槽（Asset）。 |
| **执行模型** | 堵塞主线程 (Synchronous Blocking) | 通过 `httpx.AsyncClient` 全量纯异步协程化 | **超强吞吐**：FastAPI 服务再也不会因为一个任务跑图慢而卡死其他用户请求。 |
| **反馈通信** | 等最后跑完一波出图 (One-shot) | WebSocket 监听，每个中间步产物实时 `progress_callback` 下推 | **用户体验**：修图者能看着自己的工作流“一步步变魔术”产生中间态，极大提升反馈感。 |

## 3. 测试方式

由于暂时未连接前端真实 UI 和大模型大脑，我们在后端 API 层留设了沙盒测试点：

### 方式 1：HTTP 体验跑通 (适用于 Swagger 等 REST 工具)
利用改写后的 `GET /run_pipeline` 接口，验证核心流水的物理连通性：
1. 本地确保已启动 FastAPI 和 ComfyUI。
2. 将一张样图（如 `photo.png`）扔进 ComfyUI 的 `input/` 目录。
3. 打开 `http://127.0.0.1:8000/docs`。
4. 找到 `GET /run_pipeline` 进行调试，输入 `photo.png` 名字、想要抠出的 Prompt（如 "cat"），以及想让它去的背景 Prompt。
5. 点击发起，它将在后台进行 1）黑板初始化 -> 2）SAM2 抠遮罩 -> 3）获取遮罩搬迁 IO -> 4）寻址结合原图一起丢给 Inpaint 节点 -> 5）回传最终产出名。

### 方式 2：WebSocket 异步进度流测试 (适用于高级调试客户端)
你可以使用如 Postman / Hoppscotch 的 WebSocket 测试机：
1. 连接 `ws://127.0.0.1:8000/ws/editor/dev_client_1`。
2. 发送如下 JSON 进行唤起：
```json
{
  "action": "generate",
  "base_image": "photo.png",
  "segment_prompt": "cat",
  "inpaint_prompt": "a cyberpunk background"
}
```
3. 你将立即收到一个 `{ "event": "pipeline_started" }`。随后当到达 SAM2 结果时，会下发一次含 Mask 文件名的 JSON，最后 Inpaint 成功后再次下发含结果图文件名的 JSON。这就构成了极低延迟的推流系统模型。
