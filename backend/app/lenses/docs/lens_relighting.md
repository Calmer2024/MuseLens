---
lens_id: lens_relighting
layer: A3
description: |
  基于原图和深度图的全局光影重构。它利用 depth_map 保持空间体积关系，再按照 prompt 改写主光方向、色温、环境光和整体明暗层次，适合做“黄昏光”“逆光”“夜景补光”这类全局打光变化。
params:
  prompt:
    description: |
      描述希望施加的全局光影变化，例如主光方向、色温、时间段、氛围和亮度关系。
    required: true
    decision_rules: |
      如果用户只说“调一下光”而没有说清楚光从哪里来、偏冷偏暖或整体氛围，应判定为 missing。
    format_rules: |
      建议用一句话写清楚光线方向、色温和氛围。
  steps:
    description: |
      重构光影时的采样步数。
    required: false
    format_rules: |
      输出正整数。
  cfg:
    description: |
      文本引导强度。
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
  - nl_desc: 让整张图变成黄昏时分，暖金色主光从右上角照下
    params_example:
      prompt: warm sunset light coming from the upper right, cinematic dusk atmosphere
      steps: 24
      cfg: 5.0
      noise_seed: 7001
  - nl_desc: 改成冷色夜景，人物边缘有一点蓝色轮廓光
    params_example:
      prompt: cool night lighting, subtle blue rim light on the subject, darker ambient shadows
      steps: 24
      cfg: 5.2
      noise_seed: 7002
---

## 适用任务

- 全局打光重写、色温变化、时段切换、环境光氛围调整。
- 用户强调“整张图的光影变一下”时优先考虑。

## 不适用任务

- 不负责主体替换、局部修补和精确抠图。
- 没有 `depth_map` 时不能形成稳定的空间光影约束。
- 如果只是想做纯镜头散景而不改光照，更适合 `lens_depth_of_field`。

## 上下游衔接

- 常见上游是 `lens_depth_extract`，先产出 `depth_map`。
- 下游可接 A5 交付类透镜。

## 实现依据

- config 明确要求 `base_image` 和 `depth_map`。
- workflow 中有单独加载深度图的节点，因此该透镜依赖外部深度输入，而不是内部自动估计。
