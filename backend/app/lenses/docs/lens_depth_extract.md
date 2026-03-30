---
lens_id: lens_depth_extract
layer: A1
description: |
  使用 Depth Anything V2 从输入图像估计深度图，输出 `depth_map` 供下游透镜做空间结构约束。它是分析透镜，不直接负责生成最终效果图。
examples:
  - nl_desc: 先提取一张深度图，后面用于控制光影或景深
    params_example: {}
  - nl_desc: 保留画面空间关系，先做 depth map
    params_example: {}
---

## 适用任务

- 为下游提供空间体积关系和前后景层次。
- 常用于全局 relighting、景深模拟或参考约束重绘。

## 不适用任务

- 不生成最终视觉成图。
- 没有 `prompt`，不能按文字决定提取哪一部分。
- 不负责边缘线稿、姿态骨架或遮罩分割。

## 上下游衔接

- 常见下游是 `lens_relighting`、`lens_depth_of_field`、`lens_flux_reference`、`lens_flux_two_reference`。

## 实现依据

- config layer 真实为 `A1`，且没有任何参数。
- workflow 使用 `DepthAnythingV2Preprocessor`，输出类型为 `depth_map`。
