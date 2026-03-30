# MuseLens 前端后端数据库 API 调用说明

## 一、文档目标

这份文档面向前端开发同学，说明当前后端中与数据库直接读写相关的接口应该如何调用。

当前覆盖模块：

- 用户管理
- 社区
- 透镜市场
- 好友聊天
- 资产树
- 编辑会话 / 编辑片段树
- 运行时 Lens 注册表

本文重点回答四类问题：

1. 前端应该调用哪个接口
2. 这个接口需要传哪些字段
3. 返回值里哪些字段最重要
4. 哪些接口之间需要串起来使用

---

## 二、统一约定

### 1. 服务地址

本地开发默认后端地址：

```text
http://127.0.0.1:8000
```

Swagger UI 地址：

```text
http://127.0.0.1:8000/docs
```

所有业务接口统一前缀：

```text
http://127.0.0.1:8000/api/v1
```

### 2. 当前没有接入鉴权

当前阶段后端接口没有接入 JWT / Session。

这意味着：

- 前端需要在请求里显式传 `user_id`
- 目前不需要传 `Authorization`

后续如果接入鉴权，这部分约定会再调整。

### 3. ID 类型一定要分清

项目里同时存在整数主键和 UUID 主键。

- 用户、社区、市场、聊天：大多使用 `int`
- 资产树、编辑会话：大量使用 `string(UUID)`
- 运行时 Lens 注册表的 `lens_id`：使用 `string`

示例：

- `user_id = 1`
- `post_id = 3`
- `market lens_id = 2`
- `node_id = "550e8400-e29b-41d4-a716-446655440000"`
- `session_id = "c2c80b2e-b0bd-4d0a-b97b-4d0dd9f8eab7"`
- `runtime lens_id = "lens_inpaint_bg"`

### 4. 错误返回格式

当前错误返回遵循 FastAPI 默认结构：

```json
{
  "detail": "错误说明"
}
```

前端统一读取：

- HTTP 状态码
- `detail`

### 5. 有些 `DELETE` 请求需要带 JSON Body

例如：

- 取消关注
- 取消帖子点赞
- 取消帖子收藏
- 卸载透镜
- 取消收藏透镜

前端不要假设 `DELETE` 一定没有请求体。

---

## 三、用户管理接口

统一前缀：

```text
/api/v1/users
```

### 1. 注册用户

```text
POST /api/v1/users/register
```

请求体示例：

```json
{
  "username": "alice",
  "password": "pass123456",
  "nickname": "Alice",
  "email": "alice@example.com",
  "bio": "喜欢修图"
}
```

说明：

- `username` 和 `email` 需要唯一
- `password` 当前为明文传入，后端内部处理

### 2. 用户登录

```text
POST /api/v1/users/login
```

请求体示例：

```json
{
  "username": "alice",
  "password": "pass123456"
}
```

返回重点：

- `message`
- `user`

### 3. 获取用户详情

```text
GET /api/v1/users/{user_id}
```

### 4. 更新用户资料

```text
PATCH /api/v1/users/{user_id}
```

可选字段示例：

```json
{
  "nickname": "新的昵称",
  "bio": "新的个人简介",
  "avatar_url": "https://example.com/avatar.png",
  "banner_url": "https://example.com/banner.png",
  "member_level": "pro",
  "is_verified": true
}
```

### 5. 关注用户

```text
POST /api/v1/users/{user_id}/follow
```

说明：

- 路径里的 `user_id` 是被关注的人
- 请求体里的 `follower_id` 是发起关注的人

请求体：

```json
{
  "follower_id": 1
}
```

### 6. 取消关注

```text
DELETE /api/v1/users/{user_id}/follow
```

请求体：

```json
{
  "follower_id": 1
}
```

### 7. 获取粉丝列表

```text
GET /api/v1/users/{user_id}/followers
```

### 8. 获取关注列表

```text
GET /api/v1/users/{user_id}/following
```

---

## 四、社区接口

统一前缀：

```text
/api/v1/community
```

### 1. 创建帖子

```text
POST /api/v1/community/posts
```

请求体示例：

```json
{
  "user_id": 1,
  "title": "第一条帖子",
  "content": "这是一条社区帖子",
  "is_public": true,
  "images": [
    {
      "image_url": "https://example.com/post.png",
      "thumbnail_url": "https://example.com/post_thumb.png",
      "width": 800,
      "height": 600,
      "order_index": 0,
      "asset_node_id": null
    }
  ],
  "tag_names": ["人像", "#夜景"]
}
```

说明：

- `tag_names` 可以带 `#`，后端会自动清洗
- 如果帖子图片来自资产树，可以在图片对象里带 `asset_node_id`

### 2. 列出帖子

```text
GET /api/v1/community/posts
```

支持查询参数：

- `user_id`
- `tag_name`
- `only_public`

示例：

```text
GET /api/v1/community/posts?user_id=1
GET /api/v1/community/posts?tag_name=夜景
GET /api/v1/community/posts?only_public=true
```

### 3. 获取帖子详情

```text
GET /api/v1/community/posts/{post_id}
```

说明：

- 每次读取详情时，后端会自动增加 `view_count`

### 4. 发表评论

```text
POST /api/v1/community/posts/{post_id}/comments
```

一级评论：

```json
{
  "user_id": 2,
  "content": "一级评论"
}
```

二级评论：

```json
{
  "user_id": 1,
  "content": "回复这条评论",
  "parent_id": 10
}
```

说明：

- 当前只支持两层评论

### 5. 获取评论列表

```text
GET /api/v1/community/posts/{post_id}/comments
```

### 6. 点赞帖子

```text
POST /api/v1/community/posts/{post_id}/like
```

请求体：

```json
{
  "user_id": 2
}
```

### 7. 取消帖子点赞

```text
DELETE /api/v1/community/posts/{post_id}/like
```

### 8. 收藏帖子

```text
POST /api/v1/community/posts/{post_id}/favorite
```

### 9. 取消收藏帖子

```text
DELETE /api/v1/community/posts/{post_id}/favorite
```

### 10. 点赞评论

```text
POST /api/v1/community/comments/{comment_id}/like
```

### 11. 取消评论点赞

```text
DELETE /api/v1/community/comments/{comment_id}/like
```

### 12. 获取标签列表

```text
GET /api/v1/community/tags
```

---

## 五、透镜市场接口

统一前缀：

```text
/api/v1/market
```

### 1. 创建市场透镜

```text
POST /api/v1/market/lenses
```

请求体示例：

```json
{
  "lens_key": "lens_market_portrait_v1",
  "name": "人像柔光",
  "description": "适合人像氛围增强",
  "author_id": 1,
  "category": "portrait",
  "price": "9.90",
  "is_official": false,
  "status": "active"
}
```

说明：

- `lens_key` 是市场透镜的业务唯一键
- 这里的 `lens_id` 是市场表里的整数主键，不是运行时 Lens 的 `lens_id`

### 2. 更新市场透镜

```text
PATCH /api/v1/market/lenses/{lens_id}
```

### 3. 列出市场透镜

```text
GET /api/v1/market/lenses
```

支持查询参数：

- `category`
- `status`
- `is_official`

### 4. 获取透镜详情

```text
GET /api/v1/market/lenses/{lens_id}
```

返回通常包含：

- 透镜基本信息
- `versions`
- `reviews`

### 5. 创建透镜版本

```text
POST /api/v1/market/lenses/{lens_id}/versions
```

请求体示例：

```json
{
  "version": "1.0.0",
  "base_workflow": {
    "nodes": []
  },
  "parameters": {
    "strength": {
      "type": "float"
    }
  },
  "ui_schema": {
    "layout": "slider"
  },
  "changelog": "首次发布",
  "is_latest": true
}
```

### 6. 安装透镜

```text
POST /api/v1/market/lenses/{lens_id}/install
```

请求体：

```json
{
  "user_id": 2,
  "version_id": 1
}
```

说明：

- `version_id` 可选
- 不传时后端会优先安装 `is_latest=true` 的版本

### 7. 卸载透镜

```text
DELETE /api/v1/market/lenses/{lens_id}/install
```

### 8. 收藏透镜

```text
POST /api/v1/market/lenses/{lens_id}/favorite
```

### 9. 取消收藏透镜

```text
DELETE /api/v1/market/lenses/{lens_id}/favorite
```

### 10. 创建或更新评价

```text
POST /api/v1/market/lenses/{lens_id}/reviews
```

请求体：

```json
{
  "user_id": 2,
  "rating": 5,
  "content": "很好用"
}
```

说明：

- 同一用户对同一透镜只保留一条评价

### 11. 获取用户已安装透镜

```text
GET /api/v1/market/users/{user_id}/installed
```

### 12. 获取用户收藏透镜

```text
GET /api/v1/market/users/{user_id}/favorites
```

---

## 六、好友聊天接口

统一前缀：

```text
/api/v1/chat
```

### 1. 业务前置条件

- 当前只支持一对一私聊
- 只有互相关注的双方才能新建私聊
- 如果历史会话已经存在，即使后来不再互关，也可以读取历史，但不能继续发送新消息

### 2. 获取可私聊好友列表

```text
GET /api/v1/chat/friends/{user_id}
```

说明：

- 返回当前用户所有“互相关注”的好友
- 如果和某个好友已经有会话，会额外返回 `conversation_id`

### 3. 创建或打开好友私聊

```text
POST /api/v1/chat/conversations/direct
```

请求体：

```json
{
  "user_id": 1,
  "friend_user_id": 2
}
```

返回重点：

- `created`
- `conversation`

### 4. 获取当前用户会话列表

```text
GET /api/v1/chat/conversations?user_id=1
```

返回重点：

- `peer_user`
- `last_message`
- `unread_count`

### 5. 获取会话详情

```text
GET /api/v1/chat/conversations/{conversation_id}?user_id=1
```

### 6. 获取会话消息列表

```text
GET /api/v1/chat/conversations/{conversation_id}/messages
```

查询参数：

- `user_id`：必传
- `limit`：默认 `50`
- `before_message_id`：做向上翻页时使用

### 7. 发送文本消息

```text
POST /api/v1/chat/conversations/{conversation_id}/messages
```

```json
{
  "sender_id": 1,
  "content": "你好，这里先发一条文本消息"
}
```

### 8. 分享帖子

```json
{
  "sender_id": 1,
  "content": "给你看看这条帖子",
  "share": {
    "share_type": "post",
    "post_id": 3
  }
}
```

### 9. 分享预设

分享市场预设：

```json
{
  "sender_id": 1,
  "content": "这个预设你可以试试",
  "share": {
    "share_type": "preset",
    "market_lens_id": 2
  }
}
```

分享资产树节点预设：

```json
{
  "sender_id": 1,
  "content": "",
  "share": {
    "share_type": "preset",
    "asset_node_id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

说明：

- `share_type=preset` 时，`market_lens_id` 和 `asset_node_id` 二选一
- 后端会把分享内容转成统一卡片结构，前端优先直接渲染 `share`

### 10. 标记会话已读

```text
POST /api/v1/chat/conversations/{conversation_id}/read
```

```json
{
  "user_id": 1,
  "last_read_message_id": 101
}
```

### 11. 聊天消息的关键字段

- `message_type`
  - `text`
  - `share`
  - `text_share`
- `share.share_type`
  - `post`
  - `preset`
- `share.share_source_type`
  - `community_post`
  - `market_lens`
  - `asset_node`

---

## 七、资产树接口

统一前缀：

```text
/api/v1/asset-tree
```

### 1. 创建项目

```text
POST /api/v1/asset-tree/projects
```

```json
{
  "name": "项目一",
  "description": "测试项目"
}
```

### 2. 获取项目列表

```text
GET /api/v1/asset-tree/projects
```

### 3. 获取项目详情

```text
GET /api/v1/asset-tree/projects/{project_id}
```

### 4. 更新项目信息

```text
PATCH /api/v1/asset-tree/projects/{project_id}
```

### 5. 切换当前节点

```text
POST /api/v1/asset-tree/projects/{project_id}/current-node
```

```json
{
  "node_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 6. 删除项目

```text
DELETE /api/v1/asset-tree/projects/{project_id}
```

### 7. 获取完整树结构

```text
GET /api/v1/asset-tree/projects/{project_id}/tree
```

返回核心：

- `project`
- `nodes`
- `edges`

### 8. 添加根节点

```text
POST /api/v1/asset-tree/projects/{project_id}/root-node
```

```json
{
  "image_url": "s3://bucket/root.png",
  "thumbnail_url": "s3://bucket/root_thumb.png",
  "width": 1024,
  "height": 768,
  "file_size": 123456,
  "format": "png",
  "metadata": {
    "source": "upload"
  }
}
```

说明：

- 每个项目只能有一个根节点

### 9. 创建子节点

```text
POST /api/v1/asset-tree/projects/{project_id}/nodes
```

请求体示例：

```json
{
  "parent_node_id": "550e8400-e29b-41d4-a716-446655440000",
  "episode_id": 12,
  "image_url": "s3://bucket/result.png",
  "thumbnail_url": "s3://bucket/result_thumb.png",
  "width": 1024,
  "height": 768,
  "file_size": 234567,
  "format": "png",
  "lens_id": "lens_inpaint_bg",
  "lens_name": "局部重绘",
  "user_prompt": "把背景换成海边黄昏",
  "parameters": {
    "positive_prompt": "beach sunset"
  },
  "muse_dna": {
    "steps": []
  },
  "generation_params": {
    "positive_prompt": "beach sunset"
  },
  "execution_time_ms": 3200,
  "task_id": "6d09dfe1-3c48-4d4e-ae19-f57b34b0f8f0",
  "status": "completed",
  "metadata": {
    "source": "generation"
  }
}
```

说明：

- `episode_id` 为可选字段
- 不传 `episode_id`：行为与旧版一致，只创建资产树节点
- 传 `episode_id`：后端会自动把新节点绑定为对应编辑片段的 `target_node_id`

### 10. 获取节点详情

```text
GET /api/v1/asset-tree/nodes/{node_id}
```

### 11. 更新节点状态

```text
PATCH /api/v1/asset-tree/nodes/{node_id}/status
```

```json
{
  "status": "completed",
  "image_url": "s3://bucket/final.png",
  "thumbnail_url": "s3://bucket/final_thumb.png",
  "execution_time_ms": 5000
}
```

### 12. 获取祖先路径

```text
GET /api/v1/asset-tree/nodes/{node_id}/ancestors
```

### 13. 获取所有后代节点

```text
GET /api/v1/asset-tree/nodes/{node_id}/descendants
```

### 14. 删除节点

```text
DELETE /api/v1/asset-tree/nodes/{node_id}?cascade=false
```

说明：

- `cascade=false`：只能删叶子节点
- `cascade=true`：删除整棵子树

### 15. 对比两个节点

```text
GET /api/v1/asset-tree/nodes/compare?nodeA={node_id}&nodeB={node_id}
```

### 16. 添加节点标签

```text
POST /api/v1/asset-tree/nodes/{node_id}/tags
```

```json
{
  "label": "最终版",
  "color": "#4A90E2"
}
```

### 17. 获取节点标签

```text
GET /api/v1/asset-tree/nodes/{node_id}/tags
```

### 18. 删除节点标签

```text
DELETE /api/v1/asset-tree/tags/{tag_id}
```

---

## 八、编辑会话 / 编辑片段树接口

统一前缀：

```text
/api/v1/editor-sessions
```

这一组接口是本次新增能力，目标是把“修图会话历史”结构化保存下来，并和资产树结果节点建立双向关联。

### 1. 核心关系

- `editor_sessions.base_node_id`：会话起点资产节点
- `editor_episodes.source_node_id`：本轮编辑起点节点
- `editor_episodes.target_node_id`：本轮编辑结果节点

前端可以把这组接口理解成两件事：

- 片段树：用于展示每一轮意图、计划和分支
- 资产联动：用于把每轮对话和某个图片结果绑定起来

### 2. 创建编辑会话

```text
POST /api/v1/editor-sessions/projects/{project_id}/sessions
```

请求体：

```json
{
  "title": "夜景精修会话",
  "description": "记录一次从原图到最终图的推演过程",
  "base_node_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

说明：

- `base_node_id` 可选
- 不传时后端优先使用项目当前节点，否则使用根节点

### 3. 获取项目下的编辑会话列表

```text
GET /api/v1/editor-sessions/projects/{project_id}/sessions
```

### 4. 获取单个编辑会话详情

```text
GET /api/v1/editor-sessions/sessions/{session_id}
```

返回重点字段：

- `base_node_id`
- `current_episode_id`
- `episode_count`
- `branch_count`
- `base_node`

### 5. 创建编辑片段

```text
POST /api/v1/editor-sessions/sessions/{session_id}/episodes
```

请求体示例：

```json
{
  "parent_episode_id": null,
  "source_node_id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "压高光",
  "branch_name": "主线",
  "user_intent": "把天空高光压下来一点",
  "assistant_plan": "降低高光并保留云层边缘层次",
  "action_summary": "准备开始一轮高光恢复",
  "tags": ["高光", "天空"],
  "action_items": ["降低高光", "保留层次"],
  "tool_snapshot": {
    "tool": "highlight_recovery",
    "strength": 0.4
  },
  "metadata": {
    "scene": "night_city"
  },
  "status": "draft"
}
```

说明：

- `parent_episode_id` 可选，用来形成分支
- `source_node_id` 可选
- `user_intent` 和 `assistant_plan` 不能同时为空
- `status` 可选值：`draft`、`completed`、`archived`

后端自动行为：

- 自动补 `round_index`
- 自动生成两条初始消息：
  - `intent`
  - `plan`
- 自动刷新会话计数

### 6. 获取编辑片段树

```text
GET /api/v1/editor-sessions/sessions/{session_id}/tree
```

返回结构：

- `session`
- `episodes`
- `edges`

前端渲染片段树时主要使用：

- `episode_id`
- `parent_episode_id`
- `branch_name`
- `message_preview`

### 7. 获取单个编辑片段详情

```text
GET /api/v1/editor-sessions/episodes/{episode_id}
```

返回内容包含：

- `session`
- `episode`
- `parent_episode`
- `child_episodes`
- `messages`

这是前端打开“本轮修图详情侧栏”时最推荐优先调用的接口。

### 8. 给编辑片段追加消息

```text
POST /api/v1/editor-sessions/episodes/{episode_id}/messages
```

请求体：

```json
{
  "role": "assistant",
  "message_kind": "note",
  "content": "这一支建议保留更多暖色氛围。",
  "payload": null
}
```

可选值：

- `role`：`user`、`assistant`、`system`
- `message_kind`：`intent`、`plan`、`decision`、`note`、`system_event`

### 9. 手动绑定结果节点

```text
POST /api/v1/editor-sessions/episodes/{episode_id}/bind-target
```

```json
{
  "target_node_id": "2ef0f526-7b38-4bd8-9fd7-1b6f03f1d499",
  "source_node_id": "550e8400-e29b-41d4-a716-446655440000",
  "action_summary": "高光恢复完成",
  "status": "completed"
}
```

说明：

- 适合“节点已经创建好了，后面再补绑片段”的场景

### 10. 通过结果节点反查片段

```text
GET /api/v1/editor-sessions/episodes/by-node/{node_id}?session_id={session_id}
```

说明：

- 适合前端用户从资产树里点到某张结果图后，反查它是哪轮对话生成的

### 11. 最推荐的联动方式

不是先创建资产节点、再手动调两三个接口去拼状态，而是：

1. 创建编辑会话
2. 创建编辑片段
3. 结果图生成完成后，调用资产树 `create child node`
4. 在创建子节点的请求体里同时传 `episode_id`
5. 后端自动完成：
   - 资产树落节点
   - 编辑片段绑定 `target_node_id`

这样前端最省事，也最不容易写出脏状态。

---

## 九、运行时 Lens 注册表接口

统一前缀：

```text
/api/v1/lenses
```

说明：

- 这一组接口服务的是“后端运行时可编排能力”
- 它不是市场透镜

### 1. 注册运行时 Lens

```text
POST /api/v1/lenses/register
```

### 2. 获取运行时 Lens 列表

```text
GET /api/v1/lenses/
```

### 3. 获取单个运行时 Lens 详情

```text
GET /api/v1/lenses/{lens_id}
```

### 4. 删除运行时 Lens

```text
DELETE /api/v1/lenses/{lens_id}
```

### 5. 重载运行时 Lens 注册表

```text
POST /api/v1/lenses/reload
```

---

## 十、推荐联调顺序

### 1. 普通业务页面

推荐顺序：

1. 用户注册 / 登录 / 获取用户详情
2. 社区发帖 / 帖子列表 / 评论 / 点赞 / 收藏
3. 双方互关后接聊天模块
4. 市场透镜列表 / 详情 / 安装 / 收藏 / 评价

### 2. 编辑器与资产树页面

推荐顺序：

1. 创建项目
2. 上传原图后创建根节点
3. 创建编辑会话
4. 创建编辑片段
5. 结果生成完成后创建资产树子节点，并带上 `episode_id`
6. 拉取资产树
7. 拉取编辑片段树
8. 点击节点时通过 `by-node` 反查对应片段

---

## 十一、前端调用时最容易踩坑的地方

### 1. 不要混淆三种“透镜 ID”

- 市场透镜的 `lens_id`：整数
- 运行时 Lens 的 `lens_id`：字符串
- 资产树边上的 `lens_id`：记录当时调用了哪个运行时 Lens

### 2. 不要把 UUID 当整数

下面这些字段都要按字符串处理：

- `project_id`
- `node_id`
- `session_id`

### 3. 聊天私聊需要互关

前端不要只看“我关注了对方”，就默认可以发私聊。

### 4. 社区帖子详情会增加浏览数

如果只是做静默刷新，要注意这一点。

### 5. 资产树和编辑片段树不是一棵树

建议前端实现成两个数据结构：

- 图像版本树
- 编辑片段树

二者通过：

- `source_node_id`
- `target_node_id`

进行联动。

### 6. 最省事的方式是用 Swagger UI 对照联调

建议前端同学本地先打开：

```text
http://127.0.0.1:8000/docs
```

一边看这份文档，一边在 Swagger 里直接试参数和响应结构，联调效率会更高。

---

## 十二、结语

当前后端数据库相关接口已经覆盖了以下主要能力：

- 用户基础资料与社交关系
- 社区帖子、评论、点赞、收藏
- 市场透镜、版本、安装、收藏、评价
- 好友聊天与帖子 / 预设分享
- 资产树版本管理
- 编辑会话与资产树融合追踪
- 运行时 Lens 注册表

如果前端严格按照本文档和 Swagger UI 一起联调，当前阶段已经可以把主要页面和核心业务链路打通。
