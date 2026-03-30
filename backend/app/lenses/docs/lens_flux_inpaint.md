---
lens_id: lens_flux_inpaint
layer: A2
description: |
  基于 FLUX 的局部遮罩重绘。输入原图和 mask 后，只对白色遮罩区域进行重绘，未遮罩区域尽量保持不变，适合做主体替换、局部修补、指定区域加物体或移除物体。
params:
  prompt:
    description: |
      描述遮罩区域应被重绘成什么，包括目标物体、材质、颜色、局部光照和与周围环境的融合要求。
    required: true
    decision_rules: |
      如果用户只说“改这块”但没有说明改成什么，应判定为 missing。
      如果用户明确说“把人换成猪”“把天空改成晚霞”“把手里的杯子换成花束”，可直接使用。
    format_rules: |
      建议用一句话描述遮罩内结果，不要描述整张图的全局风格。
  steps:
    description: |
      局部重绘采样步数。
    required: false
    format_rules: |
      输出正整数。
  cfg:
    description: |
      文本提示对局部重绘的引导强度。
    required: false
    format_rules: |
      输出正数。
  noise_seed:
    description: |
      随机种子。
    required: false
    format_rules: |
      输出整数。
examples:
  - nl_desc: 把图片中的女人替换成一只猪，保留原有背景和环境光
    params_example:
      prompt: replace the masked woman with a realistic pig, preserve the background and existing lighting
      steps: 24
      cfg: 5.5
      noise_seed: 3001
  - nl_desc: 把遮罩区域的天空改成有层次的黄昏晚霞，并与周围光线自然融合
    params_example:
      prompt: dramatic sunset clouds, warm dusk sky, natural blend with surrounding lighting
      steps: 20
      cfg: 5.0
      noise_seed: 3002
---

## 适用任务

- 局部替换、局部补画、物体移除后重建、只改某个主体或区域。
- 用户明确提出“只改这里”“保留背景”“替换某个对象”时优先考虑。
- 适合和自动分割透镜串联成完整链路。

## 不适用任务

- 没有 `mask` 时不能精确工作。
- 不适合纯全局风格迁移或整体光影重塑，那类任务更适合 `lens_flux_edit`。
- 不负责自动找出要修改的区域，本身只消费现成遮罩。

## 上下游衔接

- 常见上游是 `lens_sam2_matting`，先按提示词输出遮罩，再将 `mask_result` 交给当前透镜。
- 下游常接 `lens_upscale_4x` 或 `lens_watermark`。

## 实现依据

- config 真实输入是 `base_image` 和 `mask`。
- workflow 包含 `SetLatentNoiseMask`，说明它是局部噪声遮罩重绘，而不是全局 edit。
- 输出只有 `result_image`，不返回新的 mask 或结构图。
