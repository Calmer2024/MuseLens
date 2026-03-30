---
lens_id: lens_lora_filter
layer: A4
description: |
  基于 LoRA 的整图风格滤镜透镜。输入原图后，workflow 会在内部生成深度约束并结合 ControlNet 与 LoRA，对整张图进行统一风格化重绘，同时尽量保留原图主体、构图和大体空间关系。
params:
  lora_name:
    description: |
      要加载的 LoRA 模型文件名。当前仅支持系统内已存在的 LoRA 文件名。
    required: true
    decision_rules: |
      如果用户请求的风格能明确映射到现有 LoRA，应直接填入对应文件名。
      如果用户只说“换一种风格”但没有命中任何已知 LoRA 风格，也没有额外参考图，则不应硬填未知模型名。
    format_rules: |
      输出可直接加载的 LoRA 文件名，例如 `Studio Ghibli Style.safetensors`。
  prompt:
    description: |
      补充描述希望叠加的风格气质、材质、笔触、色彩和氛围。
    required: false
    decision_rules: |
      应写成整图风格化提示词，而不是局部替换指令。
      适合补充“手绘感、暖色调、梦幻氛围、霓虹夜景、黏土质感”等整体视觉方向。
    format_rules: |
      建议输出英文提示词，因为该透镜实际使用 SDXL + 对应 CLIP 编码，英文风格描述通常更稳定。
      输出一句简洁的英文整图风格化描述。
  strength_model:
    description: |
      LoRA 对模型侧的影响强度。
    required: false
  strength_clip:
    description: |
      LoRA 对文本编码侧的影响强度。
    required: false
  denoise:
    description: |
      整图风格化重绘幅度。
    required: false
  steps:
    description: |
      采样步数。
    required: false
  cfg:
    description: |
      文本引导强度。
    required: false
  seed:
    description: |
      随机种子。
    required: false
examples:
  - nl_desc: 把这张图片改成宫崎骏风格，保留人物和原始构图
    params_example:
      lora_name: Studio Ghibli Style.safetensors
      prompt: Studio Ghibli inspired hand-drawn animation aesthetic, soft warm natural lighting, lush dreamy atmosphere, preserve the subject and composition
      strength_model: 0.8
      strength_clip: 0.8
      denoise: 0.35
      steps: 24
      cfg: 5.0
      seed: 6201
  - nl_desc: 把照片转成吉卜力动画风格，整体更温柔治愈
    params_example:
      lora_name: Studio Ghibli Style.safetensors
      prompt: gentle Ghibli animation look, clean colors, soft painterly texture, whimsical and healing mood
      strength_model: 0.8
      strength_clip: 0.8
      denoise: 0.35
      steps: 24
      cfg: 5.0
      seed: 6202
  - nl_desc: 把这张图改成日本动漫风格，保留原图主体
    params_example:
      lora_name: Studio Ghibli Style.safetensors
      prompt: Japanese anime illustration style, clean cel-shaded feeling, vivid but soft palette, preserve subject and framing
      strength_model: 0.78
      strength_clip: 0.78
      denoise: 0.32
      steps: 24
      cfg: 5.0
      seed: 6203
  - nl_desc: 改成赛博朋克风格，霓虹灯、夜景、未来都市感
    params_example:
      lora_name: cyberpunk style v3.safetensors
      prompt: cyberpunk neon city atmosphere, night scene, glossy reflections, futuristic lighting, preserve the main subject
      strength_model: 0.82
      strength_clip: 0.82
      denoise: 0.36
      steps: 24
      cfg: 5.2
      seed: 6204
  - nl_desc: 变成粘土风格，像黏土手办动画一样
    params_example:
      lora_name: CLAYMATE_V2.03_.safetensors
      prompt: claymation texture, handcrafted clay figure feel, soft studio lighting, preserve composition
      strength_model: 0.8
      strength_clip: 0.8
      denoise: 0.34
      steps: 24
      cfg: 5.0
      seed: 6205
  - nl_desc: 改成手绘风格，像复古插画一样
    params_example:
      lora_name: Vintage_styleV2.safetensors
      prompt: vintage hand-drawn illustration look, textured strokes, nostalgic warm tones, preserve the original scene
      strength_model: 0.78
      strength_clip: 0.78
      denoise: 0.32
      steps: 24
      cfg: 5.0
      seed: 6206
---

## 当前已知可用风格

- `Studio Ghibli Style.safetensors`
  适合宫崎骏风格、吉卜力风格、日本动漫风格、温柔治愈的动画感重绘。
- `cyberpunk style v3.safetensors`
  适合赛博朋克风格、霓虹夜景、未来都市感。
- `CLAYMATE_V2.03_.safetensors`
  适合粘土风格、黏土手办感、claymation 风格。
- `Vintage_styleV2.safetensors`
  适合手绘风格、复古手绘、复古插画感。

## 适用任务

- 用户已经上传原图，希望在原图基础上做整图风格化。
- 需求是“改成某种统一画风/滤镜/材质”，同时尽量保留主体和构图。
- 已知目标风格可以映射到当前可用的 LoRA 模型。

## 不适用任务

- 不适合精确局部替换、局部修补、遮罩重绘。
- 不适合没有任何已知 LoRA 风格映射、又缺少风格参考图的开放式风格任务。
- 不适合“从零生图”，因为该透镜必须消费 `base_image`。

## 与其他透镜的关系

- 如果用户有明确原图，且风格能命中当前已知 LoRA，优先考虑本透镜。
- 如果用户想做整图风格化，但风格没有命中已知 LoRA，通常更适合退回 A2 的 `lens_flux_edit`。
- 如果用户额外提供了专门的风格参考图，则也可以考虑 `lens_style` 这类参考风格透镜。

## 实现依据

- config 真实输入只有 `base_image`，没有外部 `depth_map` 输入。
- workflow 内部包含深度预处理、ControlNet 与 `LoraLoader`，说明结构保护和 LoRA 加载都在透镜内部完成。
- workflow 的提示词节点是 SDXL 的 `CLIPTextEncode`，因此 `prompt` 更适合直接提供英文风格描述。
- 因此该透镜不需要额外串联 A1 的 `depth_extract` 才能使用。
