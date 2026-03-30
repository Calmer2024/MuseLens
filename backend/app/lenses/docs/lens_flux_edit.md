---
lens_id: lens_flux_edit
layer: A2
description: |
  基于 FLUX 的全局语义重绘。输入原图后，通过提示词整体改写风格、光影、材质或氛围，同时尽量保留原始构图。它更适合全局变化，不适合精确局部替换。
params:
  prompt:
    description: |
      描述希望重绘后的整体视觉方向，例如光线、风格、材质、时间段和情绪氛围。
    required: true
    decision_rules: |
      如果用户只说“改一下”“优化一下”而没有说明要改成什么，应判定为 missing。
      如果用户明确描述了整体效果，例如“黄昏逆光”“油画风”“雨夜霓虹感”，可直接使用。
    format_rules: |
      建议用一句话描述目标画面，不要写成局部选区指令。
  steps:
    description: |
      采样步数，通常影响重绘充分程度。
    required: false
    format_rules: |
      输出正整数。
  cfg:
    description: |
      文本提示对结果的引导强度。
    required: false
    format_rules: |
      输出正数。
  noise_seed:
    description: |
      随机种子，用于复现或探索不同结果。
    required: false
    format_rules: |
      输出整数。
examples:
  - nl_desc: 让整张图变成黄昏时分，右上角暖金色阳光照下，整体更有电影感
    params_example:
      prompt: warm sunset light from the upper right, cinematic mood, soft golden glow
      steps: 24
      cfg: 5.5
      noise_seed: 1024
  - nl_desc: 保留原有构图，把画面整体改成潮湿的雨夜霓虹街头氛围
    params_example:
      prompt: rainy neon night atmosphere, wet reflections, cinematic urban lighting
      steps: 24
      cfg: 5.0
      noise_seed: 2048
---

## 适用任务

- 全局光影改写、整体气质调整、材质和氛围重塑。
- 用户强调“整张图都变成某种感觉”时优先考虑。
- 适合不需要精确局部控制，但需要参考原图构图的重绘。

## 不适用任务

- 不适合“把某个人换成另一种动物”“只改画面里一小块区域”这类局部替换任务。
- 没有遮罩输入，无法保证只修改某个对象。
- 不能直接消费 `depth_map`、`mask`、`pose_map` 等上游资产。

## 上下游衔接

- 该透镜通常作为 A2 主生成步骤单独使用。
- 如果后续需要交付增强，可继续接 `lens_upscale_4x` 或 `lens_watermark`。
- 若任务强调局部修改，应优先转向 `lens_sam2_matting` + `lens_flux_inpaint` 的组合。

## 实现依据

- config 只接收 `base_image`，不接收任何遮罩或结构图。
- workflow 包含 FLUX 文本编码和采样节点，但没有局部蒙版控制节点。
- 因此它是真正的全局 edit，而不是局部 inpaint。
