## Lens 说明文档格式（md + YAML frontmatter）

后端会在运行时读取 `MUSELENS_LENS_DOCS_DIR/<lens_id>.md`。

`<lens_id>.md` 推荐使用下面的结构：  
1. 顶部 YAML frontmatter（用 `---` 包起来）  
2. frontmatter 之后的 markdown 正文（正文会被当作兜底描述）

### 1. YAML frontmatter 字段说明

```yaml
---
lens_id: lens_inpaint_bg          # 必填：与文件名一致
layer: A2                         # 可选：A1~A5
description: |                    # 可选：lens 概览（会叠加到数据库字段）
  这一步用于把背景替换为用户指定内容，并保持主体不变。

params:                           # 可选：参数级“追问/判定/格式”规则
  positive_prompt:
    description: |               # 可选：参数语义（会叠加到 params[].description）
      指定替换成的背景内容，用自然语言描述。
    required: true               # 可选：是否必填（用于 planner 的追问判断）
    default: ""                 # 可选：默认值
    decision_rules: |           # 可选：planner 判断“不确定/需要追问”的规则
      当用户没有给出足够具体的背景描述（例如只有“换背景”，没有内容），则标记为 missing。
    format_rules: |             # 可选：参数值应该怎么写的约束
      只输出一句话；避免与其它参数重复。

examples:                         # 可选：few-shot 例子（会映射到 LensKnowledge.examples）
  - nl_desc: "把照片背景换成海边日落，主体保持不变。"
    params_example:
      positive_prompt: "a beautiful beach at sunset, cinematic lighting"
---

正文（可选）：
- 这里可以写更长的使用说明、失败原因、以及与其它 Lens 的衔接建议。
```

### 2. 命名与目录
- 文件路径：`backend/app/lenses/docs/<lens_id>.md`（默认）
- 文件名必须是 `lens_id`（不带扩展外的其它字符），例如：
  - `backend/app/lenses/docs/lens_inpaint_bg.md`

### 3. 与“数据库字段”的关系（叠加策略）
- 如果 md 中提供了 `description`：会优先用 md 的内容（并叠加/覆盖数据库字段）。
- 如果 md 中提供了 `params.*.description / required / default / decision_rules / format_rules`：
  - 会按参数名把字段叠加到 RetrievalService 生成的 `LensParamSchema` 中。
- 如果 md 文件缺失或解析失败：系统会回退到数据库字段（保持兼容）。

