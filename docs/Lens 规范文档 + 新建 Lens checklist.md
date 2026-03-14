## 一、Lens 的正式定义（与 ComfyUI 的关系）

- **Lens 是什么**  
  - **1 个 Lens = 1 份受约束的 ComfyUI 工作流模板（JSON） + 一组声明式的元数据描述**。  
  - 元数据通过 `LensTemplate` 表达，用于约束：输入资产、输出资产、可调参数，以及它们在 ComfyUI JSON 中的精确坐标。

- **核心模型：`LensTemplate`（见 `backend/app/schemas/lens.py`）**
  - `lens_id: str`：全局唯一 ID，约定格式为：`lens_<功能>_<特征>`，例如：`lens_sam2_matting`。  
  - `layer: LensLayer`：所属功能层级，对应文档《标准透镜库 v4.1》中 A1–A5：  
    - `A1` 视觉解析层  
    - `A2` 像素修改与语义重构层  
    - `A3` 光影与物理渲染层  
    - `A4` 风格流形层  
    - `A5` 保护与修复层
  - `description: str`：给人类和 LLM 阅读的透镜功能描述，建议简要说明：  
    - 核心用途；  
    - 依赖的关键资产类型；  
    - 输出的关键资产类型。
  - `raw_workflow: dict`：**ComfyUI 导出的原始 JSON 工作流模板**。  
    - 只作为“模板”使用，运行时总是做深拷贝后再写入参数，避免状态污染。
  - `inputs: List[LensAsset]`：透镜需要的输入资产插槽（数据流）。  
  - `outputs: List[LensAsset]`：透镜产出的输出资产插槽（数据流）。  
  - `params: List[LensParam]`：可由 Router / LLM / 前端动态调节的控制参数插槽（控制流）。

- **资产与参数枚举（关键约束）**
  - `AssetType`（资产类型，决定拓扑）：  
    - `IMAGE`, `MASK`, `DEPTH_MAP`, `CONDITIONING`, `LATENT` 等。  
  - `ParamType`（参数类型，供 LLM 自由发挥）：  
    - `TEXT`, `FLOAT`, `INT`, `BOOLEAN` 等。

- **Lens 与 ComfyUI 节点之间的绑定：`NodeMapping`**
  - 每一个 `LensAsset`、`LensParam` 都拥有一个 `mapping: NodeMapping` 字段：  
    - `node_id: str`：ComfyUI JSON 中的节点 ID（字符串，例如 `"8"`）。  
    - `field_name: str`：该节点下的 `inputs` 字段名（例如 `"image"`, `"mask"`, `"text"`, `"denoise"` 等）。  
  - 运行时编译器会根据 `NodeMapping` 把资产/参数写入到：  
    - `workflow[node_id]["inputs"][field_name]`。

---

## 二、运行时参数注入链路（从 DAG 到 ComfyUI）

当前运行路径（见 `backend/app/services/compiler.py`）可以抽象为：

1. **路由 / LLM 侧：构造 `DAGBlueprint`**
   - `DAGBlueprint.initial_inputs`：初始资产上下文（例如用户上传图片的文件名）。  
   - `DAGBlueprint.steps: List[DAGStep]`：按拓扑排序的执行步骤。

2. **单个步骤：`DAGStep` 如何引用 Lens**
   - `step_id: str`：步骤 ID，例如 `"step_1"`。  
   - `lens_id: str`：要使用的透镜 ID，例如 `"lens_inpaint_bg"`。  
   - `input_links: Dict[str, str]`：  
     - key：`LensAsset.name`（如 `"base_image"`, `"core_mask"`）；  
     - value：真实文件名，或形如 `"$step_1.core_mask"` 的变量引用。  
   - `params: Dict[str, Any]`：  
     - key：`LensParam.name`（如 `"positive_prompt"`, `"denoise"`）；  
     - value：实际的参数值。

3. **编译器资产解析：`_resolve_asset`**
   - 输入：`link_value`（可能是 `"$step_1.core_mask"` 或 `"uploaded.png"`）+ 当前 `context`（上下文资产黑板）。  
   - 逻辑：  
     - 若以 `$` 开头，去掉 `$` 后当作变量名，到 `context` 中取出真实文件名；  
     - 否则认为是静态文件名，直接使用。  
   - 结果：得到一个“真实的文件名”，并在必要时从 ComfyUI output 目录搬运到 input 目录。

4. **编译器注入：`_inject_dependencies`（参数注入核心）**
   - 步骤：  
     1. `workflow = deepcopy(template.raw_workflow)`：复制一份纯净模板。  
     2. 遍历 `template.inputs`：  
        - 对每个 `LensAsset`，从 `resolved_assets` 中取出文件名，  
        - 写入到：`workflow[asset.mapping.node_id]["inputs"][asset.mapping.field_name]`。  
     3. 遍历 `template.params`：  
        - 若 `param.name` 在 `step.params` 中存在，取出值 `val`，  
        - 写入到：`workflow[param.mapping.node_id]["inputs"][param.mapping.field_name]`；  
        - 若不存在，则保留模板 JSON 中原始默认值，并打印 warning。
   - 最终返回：带有具体资产和参数的 `workflow_json`，可直接交给 `AsyncComfyRunner.queue_prompt` 执行。

5. **输出回填：根据 `LensTemplate.outputs` 写回上下文**
   - 对于每个 `output_asset`：  
     - 根据 `output_asset.mapping.node_id`，在 ComfyUI history 中找到对应节点产出的文件名；  
     - 在上下文中保存为：`context[f"{step_id}.{output_asset.name}"] = file_name`。  
   - 下一步的 `DAGStep.input_links` 可以通过 `"$step_id.asset_name"` 的方式引用这些资产。

---

## 三、Lens 命名和分层规范

- **Lens ID 命名**
  - 必须以 `lens_` 开头，全小写、下划线风格，例如：  
    - `lens_sam2_matting`  
    - `lens_depth_extract`  
    - `lens_inpaint_bg`
  - 推荐：`lens_<功能层>_<语义功能>`，但不强制。

- **JSON 工作流文件命名**
  - 约定：**ComfyUI JSON 文件名与 `lens_id` 一致**：  
    - `lens_id = "lens_sam2_matting"` → `lens_sam2_matting.json`  
  - 所有 ComfyUI 工作流 JSON 统一放置在：  
    - `backend/lens/` 目录下。

- **层级（`LensLayer`）职责约束**
  - A1：只做视觉解析，不产生最终交付图片（深度图、mask、pose、identity embedding 等）。  
  - A2：执行主重绘 / 局部修改 / 全局语义重构。  
  - A3：负责光影和物理渲染（阴影、环境光、定向光）。  
  - A4：负责风格基调和色彩空间（风格迁移、LUT 等）。  
  - A5：负责保护与修复（保护原始 LOGO 区域、面部修复、超分辨、加水印等）。

- **`NodeMapping` 使用约束**
  - `node_id` 必须与 ComfyUI 导出的 JSON 中节点 ID 完全一致。  
  - `LensAsset` 的 `type` 必须与该节点的输入/输出类型逻辑一致（例如不能把 mask 当成 image）。  
  - 不建议将“硬编码常量”暴露为 `LensParam`，只暴露需要被 LLM/用户调节的参数。

---

## 四、通过配置文件自动注册 Lens（数据与代码分离）

为避免在 `registry.py` 中手写大量 Python 代码、并实现 **“数据与代码分离”**，我们采用：

- **配置目录**：`backend/app/lenses/config/`  
  - 每个 Lens 使用一个独立的配置文件，格式为 **JSON**。  
  - 文件名约定：`<lens_id>.lens.json`，例如：`lens_sam2_matting.lens.json`。
- **工作流目录**：`backend/lens/`  
  - 存放纯 ComfyUI 导出的 JSON 工作流模板，文件名与 `lens_id` 一致：`lens_sam2_matting.json`。

### 1. 配置文件字段约定

以 `lens_inpaint_bg` 为例，一个完整的 Lens 配置文件大致如下（示意）：

```json
{
  "lens_id": "lens_inpaint_bg",
  "layer": "A2",
  "description": "SDXL 局部重绘：基于遮罩对指定区域进行语义重构（如换背景）",
  "workflow_file": "lens_inpaint_bg.json",
  "inputs": [
    {
      "name": "base_image",
      "type": "IMAGE",
      "mapping": { "node_id": "1", "field_name": "image" }
    },
    {
      "name": "mask_target",
      "type": "MASK",
      "mapping": { "node_id": "2", "field_name": "image" }
    }
  ],
  "outputs": [
    {
      "name": "result_image",
      "type": "IMAGE",
      "mapping": { "node_id": "11", "field_name": "images" }
    }
  ],
  "params": [
    {
      "name": "positive_prompt",
      "type": "TEXT",
      "description": "描述要重绘出来的内容，例如 'a beautiful beach, sunset'",
      "mapping": { "node_id": "8", "field_name": "text" }
    }
  ]
}
```

约定说明：

- `layer`：与 `LensLayer` 中的字符串值完全一致（例如 `"A1"`, `"A2"`）。  
- `type`：与 `AssetType` / `ParamType` 中的字符串值完全一致（例如 `"IMAGE"`, `"MASK"`, `"TEXT"` 等）。  
- `workflow_file`：位于 `backend/lens/` 目录下的文件名。

### 2. 自动扫描与注册流程（在 `registry.py` 中完成）

`backend/app/lenses/registry.py` 中会做以下事情：

1. **确定目录路径**
   - `_LENS_DIR`：指向 `backend/lens/`，用于加载 ComfyUI JSON 工作流。  
   - `_LENS_CONFIG_DIR`：指向 `backend/app/lenses/config/`，用于扫描 Lens 配置。

2. **加载单个 Lens 配置**
   - 读取 `<lens_id>.lens.json`；  
   - 将 JSON 字段映射为 `LensTemplate`：  
     - 用 `workflow_file` + `_LENS_DIR` 读取 `raw_workflow`；  
     - 把 `layer` / `AssetType` / `ParamType` 等字符串转成对应的 Enum；  
     - 用 `mapping` 字段填充 `NodeMapping`。

3. **自动构建全局注册表 `LENS_REGISTRY`**
   - 启动时遍历 `_LENS_CONFIG_DIR` 下所有 `*.lens.json` 文件；  
   - 对每个文件调用“加载单个 Lens 配置”的逻辑，得到 `LensTemplate`；  
   - 按 `lens_template.lens_id` 建立字典：
     - `LENS_REGISTRY: dict[str, LensTemplate] = { lens_id: lens_template, ... }`。

4. **对外暴露统一接口**
   - `get_lens(lens_id: str) -> LensTemplate`：  
     - 从 `LENS_REGISTRY` 中按 ID 检索；  
     - 若找不到则抛出 `KeyError`，并在错误信息中列出可用透镜。

> 这样一来，**Python 代码不再硬编码任何具体 LensTemplate 实例**，新增或修改透镜只需要改配置文件 / 工作流文件，不需要动后端代码。

---

## 五、新建 Lens Checklist（实操清单）

下面是从 0 到 1 新建一个 Lens 的完整流程，可以逐条勾选。

### Step 1：在 ComfyUI 中搭建并验证工作流

- [ ] 在 ComfyUI 界面中完成节点搭建，跑通完整流程。  
- [ ] 明确好**输入节点**（需要哪些图像、遮罩、深度图等）和**输出节点**（最终保存图片 / 中间资产）。  
- [ ] 对需要由上层调整的参数（例如 prompt、denoise、CFG、步数）进行整理。  
- [ ] 尽量避免在工作流里写死本地绝对路径等硬编码常量。

### Step 2：导出工作流 JSON

- [ ] 在 ComfyUI 中导出 JSON，并将文件命名为：`lens_<xxx>.json`。  
- [ ] 将导出的 JSON 文件放入：`backend/lens/` 目录。

### Step 3：设计 Lens ID 与层级

- [ ] 确定 `lens_id`，遵循：`lens_` 前缀 + 全小写、下划线风格，例如 `lens_inpaint_bg`。  
- [ ] 根据《标准透镜库 v4.1》确定所属 `LensLayer`（A1–A5）。  
- [ ] 编写一段清晰的 `description`，简要说明用途及输入/输出资产。

### Step 4：编写 Lens 配置文件（JSON）

- [ ] 在 `backend/app/lenses/config/` 目录下新建：`<lens_id>.lens.json`。  
- [ ] 填写以下字段：  
  - [ ] `lens_id`, `layer`, `description`。  
  - [ ] `workflow_file`：与工作流文件名一致，例如 `lens_inpaint_bg.json`。  
  - [ ] `inputs`：  
    - 为每个输入资产定义：`name`, `type`, `mapping(node_id, field_name)`；  
    - `name` 建议与文档中资产名保持一致（例如 `base_image`, `core_mask`, `depth_map` 等）。  
  - [ ] `outputs`：  
    - 为每个输出资产定义：`name`, `type`, `mapping(node_id, field_name)`。  
  - [ ] `params`：  
    - 为每个可调参数定义：`name`, `type`, `description`, `mapping(node_id, field_name)`。

### Step 5：在 Router / 测试代码中尝试调用

- [ ] 在测试用例或临时脚本中构造一个简单的 `DAGBlueprint`：  
  - 单步 `DAGStep`，`lens_id` 等于新建的 Lens；  
  - `input_links` 指向一张测试图片；  
  - `params` 中设置至少一个非空参数（例如 prompt）。  
- [ ] 使用 `MuseDNACompiler.execute_blueprint` 执行该蓝图：  
  - 确认运行无异常，能够从 ComfyUI 得到预期输出。  
  - 检查上下文中 `step_id.asset_name` 是否正确写入。

### Step 6：文档与标准库更新（可选但推荐）

- [ ] 在《标准透镜库 v4.1》中为新 Lens 补充一行，包括：`Lens ID`、名称、核心功能、输入/输出资产。  
- [ ] 在团队内部说明：该 Lens 适合的典型场景、注意事项（例如对输入图像的尺寸/质量要求）。

---

## 六、总结

- **数据与代码分离**：  
  - Lens 的具体定义（输入/输出/参数/节点映射）完全由配置文件与 ComfyUI JSON 承担；  
  - Python 代码只负责：加载配置、注入依赖、调用 ComfyUI、管理上下文。

- **新建一个 Lens 的本质操作**：
  1. 在 ComfyUI 中搭建并导出 JSON。  
  2. 写一小段声明式 Lens 配置（`<lens_id>.lens.json`）。  
  3. 无需改动后端代码，即可自动被注册到 `LENS_REGISTRY` 中，加入 Router/DAG 的可用透镜池。

