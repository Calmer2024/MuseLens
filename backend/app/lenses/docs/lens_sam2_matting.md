---
lens_id: lens_sam2_matting
layer: A1
description: |
  使用 Grounding DINO + SAM2 按文本目标自动分割图像中的对象，并输出遮罩 `mask_result`。它适合作为局部编辑链路的上游遮罩生成步骤。
params:
  prompt:
    description: |
      要分割的目标对象描述，例如 woman、person、cup、sky、car。
    required: true
    decision_rules: |
      如果用户想做局部替换或局部编辑，但没有说清楚要选中哪个对象，应判定为 missing。
    format_rules: |
      输出简短目标词或短语，尽量直接对应需要分割的对象。
examples:
  - nl_desc: 选中图片中的女人，供后续替换主体使用
    params_example:
      prompt: woman
  - nl_desc: 选中天空区域，后面用来改成晚霞
    params_example:
      prompt: sky
---

## 适用任务

- 需要自动找出某个对象或区域，再交给局部重绘透镜处理。
- 适合“把图中的人换掉”“只改天空”“擦掉杯子后重画”等任务。

## 不适用任务

- 不直接生成最终编辑结果，只输出遮罩。
- 如果用户任务是全局风格化或整体光影重构，不应单独把这个透镜当最终方案。

## 上下游衔接

- 最常见下游是 `lens_flux_inpaint`。
- 也可作为任何需要 `mask` 输入的局部编辑透镜上游。

## 实现依据

- config 真实输入只有 `base_image`，参数只有 `prompt`。
- workflow 使用 `SAM2ModelLoader` 和 `GroundingDinoSAM2Segment`，说明它是文本引导分割透镜。
