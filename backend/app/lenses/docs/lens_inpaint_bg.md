---
lens_id: lens_inpaint_bg
layer: A2
description: |
  使用分割结果（mask/目标区域）把背景或指定区域替换成用户想要的新内容。该 Lens 负责“局部重绘/背景重建”。

params:
  positive_prompt:
    description: |
      你希望替换后的新背景/新内容的描述。它会直接影响 ComfyUI 工作流中的文本输入。
    required: true
    default: ""
    decision_rules: |
      当 positive_prompt 过于模糊（例如只有“好看/酷/随便换”）或包含明显无法落地的内容时，判定 missing，需要追问。
      当用户给出具体的场景/风格/光照/元素时，认为足够确定。
    format_rules: |
      建议输出为一句话描述，包含：场景 + 风格/光照 + 关键元素（如有）。
examples:
  - nl_desc: "把背景换成海边日落，并保持主体不变。"
    params_example:
      positive_prompt: "a beautiful beach at sunset, cinematic lighting, subject unchanged"
  - nl_desc: "把画面背景换成夜景霓虹，主体保持清晰。"
    params_example:
      positive_prompt: "night neon city background, vibrant lights, cinematic look, subject sharply preserved"
---

使用建议（正文可选）：
- 当用户问“换背景/换成什么”，通常会触发该 lens。
- 如果用户只说“换背景”，但没有告诉“换成什么”，Planner 应追问 positive_prompt。

