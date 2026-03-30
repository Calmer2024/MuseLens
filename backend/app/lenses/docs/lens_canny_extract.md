---
lens_id: lens_canny_extract
layer: A1
description: |
  从输入图像提取边缘线稿，输出 `canny_map` 供下游重绘透镜作为结构约束参考。它只做视觉分析，不会生成最终成图。
examples:
  - nl_desc: 提取这张图的边缘线稿，后面用于锁轮廓重绘
    params_example: {}
  - nl_desc: 先做一张 canny 结构图，作为后续参考
    params_example: {}
---

## 适用任务

- 提取物体轮廓、边缘走向和主要线稿结构。
- 适合下游需要保留轮廓、边缘、构图骨架的重绘任务。

## 不适用任务

- 不输出最终美术成图。
- 不负责风格迁移、局部替换、抠图或语义生成。
- 没有参数可调，也不能靠文字指定“提取哪个对象”。

## 上下游衔接

- 常作为 `lens_flux_reference` 或 `lens_flux_two_reference` 的上游参考资产。
- 可与 `lens_depth_extract` 搭配，形成“深度 + 边缘”的双约束链。

## 实现依据

- config 只有 `base_image` 输入，没有 params。
- workflow 使用 `CannyEdgePreprocessor`，输出为 `canny_map`。
