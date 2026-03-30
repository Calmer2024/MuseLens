---
lens_id: lens_lora_filter
layer: A4
description: |
  基于 LoRA 的滤镜化重绘透镜。它使用深度 ControlNet 锁定原图结构，再通过指定的 LoRA 模型对画面材质、笔触、色彩和整体艺术氛围进行风格覆盖。

params:
  lora_name:
    description: |
      选择要使用的 LoRA 滤镜模型。当前只允许以下 4 个固定值：
      1. CLAYMATE_V2.03_.safetensors：粘土风格
      2. cyberpunk style v3.safetensors：赛博朋克风格
      3. ghibli_style_offset.safetensors：日本动漫 / 宫崎骏风格
      4. Vintage_styleV2.safetensors：复古风格
    required: true
    default: "Vintage_styleV2.safetensors"
    decision_rules: |
      如果用户没有明确选择风格，应追问他想要哪一种滤镜风格。
      不允许输出上述 4 个值以外的其他 LoRA 名称。
      当用户说“粘土风”“赛博朋克”“宫崎骏动漫风”“复古风”时，应映射到对应的固定文件名。
    format_rules: |
      只能输出以下 4 个文件名之一：
      CLAYMATE_V2.03_.safetensors
      cyberpunk style v3.safetensors
      ghibli_style_offset.safetensors
      Vintage_styleV2.safetensors
  prompt:
    description: |
      滤镜风格的补充提示词，用于强调材质、笔触、画面氛围和需要避免的偏差。
    required: false
    default: "watercolor painting, traditional art, expressive brushstrokes, color wash, visible paper texture, pastel colors, artistic, masterpiece, elegant, highly detailed"
    decision_rules: |
      如果用户只想套用某个固定滤镜，不额外补充视觉要求时，可以沿用默认 prompt。
      如果用户对风格细节有补充要求，例如“更厚涂”“更霓虹”“更温暖”，可以写入该参数。
    format_rules: |
      建议输出一句简洁风格描述，围绕材质、笔触、色彩和氛围展开。
  strength_model:
    description: |
      控制 LoRA 对模型侧的影响强度。
    required: false
    default: 1
    format_rules: |
      输出为非负浮点数，常见范围可在 0.0 到 1.0 或略高。
  strength_clip:
    description: |
      控制 LoRA 对文本编码侧的影响强度。
    required: false
    default: 1
    format_rules: |
      输出为非负浮点数，常见范围可在 0.0 到 1.0 或略高。
  denoise:
    description: |
      控制滤镜化重绘幅度，值越高，对原图风格改动越明显。
    required: false
    default: 1
    format_rules: |
      输出为 0.0 到 1.0 的浮点数。
  steps:
    description: |
      控制采样步数。
    required: false
    default: 20
    format_rules: |
      输出为正整数。
  cfg:
    description: |
      控制文本与条件对生成结果的引导强度。
    required: false
    default: 7
    format_rules: |
      输出为正数。
  seed:
    description: |
      控制随机种子。
    required: false
    default: 541551419347641
    format_rules: |
      输出为整数。

examples:
  - nl_desc: "把这张照片改成粘土手办风格。"
    params_example:
      lora_name: "CLAYMATE_V2.03_.safetensors"
      prompt: "clay art, handcrafted miniature look, soft matte material, cute stylized details"
      strength_model: 1
      strength_clip: 1
      denoise: 0.9
      steps: 20
      cfg: 7
      seed: 541551419347641
  - nl_desc: "给原图套一个赛博朋克滤镜，霓虹感更强一点。"
    params_example:
      lora_name: "cyberpunk style v3.safetensors"
      prompt: "cyberpunk neon lights, futuristic city glow, saturated colors, high contrast atmosphere"
      strength_model: 1
      strength_clip: 1
      denoise: 0.95
      steps: 22
      cfg: 7.5
      seed: 541551419347642
  - nl_desc: "把照片处理成宫崎骏动画那种日系动漫氛围。"
    params_example:
      lora_name: "ghibli_style_offset.safetensors"
      prompt: "ghibli inspired anime atmosphere, soft colors, warm storytelling mood, painterly background"
      strength_model: 1
      strength_clip: 1
      denoise: 0.9
      steps: 20
      cfg: 7
      seed: 541551419347643
  - nl_desc: "改成有点复古胶片海报感的风格。"
    params_example:
      lora_name: "Vintage_styleV2.safetensors"
      prompt: "vintage retro poster feel, aged colors, nostalgic texture, elegant composition"
      strength_model: 1
      strength_clip: 1
      denoise: 0.9
      steps: 20
      cfg: 7
      seed: 541551419347644
---

使用建议（可选正文）：
- 适合“给原图叠一个固定风格滤镜”的场景，比开放式风格迁移更可控。
- 如果用户是在四种预设风格里挑一种，planner 应优先映射 `lora_name`，不要生成其他未支持的模型名。
- 当用户没有明确风格时，应优先追问，而不是随意猜测 LoRA 名称。
