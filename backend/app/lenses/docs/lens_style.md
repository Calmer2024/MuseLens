---
lens_id: lens_style
layer: A4
description: |
  基于原图与风格参考图执行风格迁移。该透镜结合 IPAdapter 提取参考图风格特征，并使用深度约束保护原图结构，在保留主体空间关系的前提下完成整体艺术风格改写。

params:
  prompt:
    description: |
      对最终风格化结果的补充描述，用于强调画面气质、质感、光照或想保留的主体特征。
    required: false
    default: "(masterpiece, best quality:1.2), highly detailed, ultra-resolution, 8k uhd, aesthetic, flawless, volumetric lighting, rich details, intricate, professional lighting, sharp focus"
    decision_rules: |
      如果用户已经上传了明确的风格参考图，但没有额外补充要求，可以直接沿用默认 prompt。
      如果用户明确提出“更油画感”“更梦幻”“更柔和”等风格方向，可以在该参数中补充。
    format_rules: |
      建议输出一句简洁的视觉描述，避免与参考图语义完全冲突。
  ipadapter_weight:
    description: |
      控制参考风格图对最终结果的影响强度，值越高，越贴近参考图风格。
    required: false
    default: 0.5
    format_rules: |
      输出为 0.0 到 1.0 的浮点数。
  controlnet_strength:
    description: |
      控制深度结构约束强度，值越高，越倾向保留原图空间结构。
    required: false
    default: 1
    format_rules: |
      输出为 0.0 到 1.0 或更高的非负浮点数，常用范围建议 0.5 到 1.2。
  denoise:
    description: |
      控制风格化重绘幅度，值越高，对原图改动越大。
    required: false
    default: 0.85
    format_rules: |
      输出为 0.0 到 1.0 的浮点数。
  steps:
    description: |
      控制采样步数，步数越高，风格迁移通常越充分。
    required: false
    default: 20
    format_rules: |
      输出为正整数。
  cfg:
    description: |
      控制文本和条件对结果的引导强度。
    required: false
    default: 8
    format_rules: |
      输出为正数。
  seed:
    description: |
      控制随机种子，用于复现结果或探索不同风格细节。
    required: false
    default: 839656277907568
    format_rules: |
      输出为整数。

examples:
  - nl_desc: "用这张参考图的艺术风格去重绘原图，但人物结构和构图尽量保持不变。"
    params_example:
      prompt: "preserve original composition and subject structure, adopt the reference image's artistic style"
      ipadapter_weight: 0.6
      controlnet_strength: 1
      denoise: 0.8
      steps: 20
      cfg: 8
      seed: 839656277907568
  - nl_desc: "把照片改成参考图那种梦幻插画风，但不要把人物五官改坏。"
    params_example:
      prompt: "dreamy illustration style, soft atmosphere, preserve facial structure and subject identity as much as possible"
      ipadapter_weight: 0.55
      controlnet_strength: 1
      denoise: 0.82
      steps: 22
      cfg: 8
      seed: 839656277907569
---

使用建议（可选正文）：
- 适合“参考这张图的风格去改原图”这类任务。
- 如果用户提供了明确的风格参考图，这个 lens 往往比纯 prompt 重绘更稳定。
- 当用户强调“保留原图结构，只迁移风格”，可优先考虑这个 lens。
