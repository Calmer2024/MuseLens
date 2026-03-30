# MuseLens 前端后端数据库 API 调用说明

## 一、文档目的

本文档面向前端开发人员，说明当前后端中与数据库读写直接相关的接口应该如何调用。

本文档覆盖以下模块：

- 用户管理
- 社区
- 透镜市场
- 好友聊天
- 资产树
- 运行时 Lens 注册表

本文档不覆盖：

- WebSocket 编辑器实时生成接口
- ComfyUI 执行链路细节
- `test_run` 测试接口

---

## 二、统一约定

### 1. 服务地址

本地开发默认后端地址：

```text
http://127.0.0.1:8000
```

Swagger 文档地址：

```text
http://127.0.0.1:8000/docs
```

所有数据库相关接口的统一前缀为：

```text
http://127.0.0.1:8000/api/v1
```

### 2. 当前阶段没有接入鉴权

当前后端接口**没有接入 JWT / Session 鉴权**。

这意味着：

- 前端需要在请求体中显式传 `user_id`
- 不需要额外加 `Authorization` 头

后续如果接入鉴权，这一部分会调整。

### 3. 两类 ID 的区别

前端调用时请特别注意 ID 类型：

- 用户、社区、透镜市场相关主键：`int`
- 资产树相关主键：`string(UUID)`
- 运行时 Lens 注册表中的 `lens_id`：`string`

例如：

- 用户 `user_id = 1`
- 帖子 `post_id = 3`
- 市场透镜 `lens_id = 2`
- 资产树节点 `node_id = "550e8400-e29b-41d4-a716-446655440000"`
- 运行时 Lens `lens_id = "lens_inpaint_bg"`

其中“市场透镜 ID”和“运行时 Lens ID”不是同一个概念，不要混用。

### 4. 错误返回格式

当前错误返回遵循 FastAPI 默认格式：

```json
{
  "detail": "错误说明"
}
```

前端应统一读取：

- `status code`
- `detail`

### 5. DELETE 请求里有些接口需要带 JSON Body

当前后端中，部分 `DELETE` 接口不是纯路径删除，而是需要附带请求体，例如：

- 取消关注
- 取消帖子点赞
- 取消帖子收藏
- 取消评论点赞
- 卸载透镜
- 取消收藏透镜

前端调用时不要默认认为 `DELETE` 不能带 body。

---

## 三、用户管理接口

统一前缀：

```text
/api/v1/users
```

### 1. 注册用户

接口：

```text
POST /api/v1/users/register
```

请求体：

```json
{
  "username": "alice",
  "password": "pass123456",
  "nickname": "Alice",
  "email": "alice@example.com",
  "bio": "喜欢修图"
}
```

成功返回：

```json
{
  "user_id": 1,
  "username": "alice",
  "email": "alice@example.com",
  "nickname": "Alice",
  "bio": "喜欢修图",
  "avatar_url": null,
  "banner_url": null,
  "total_likes": 0,
  "follower_count": 0,
  "following_count": 0,
  "member_level": "free",
  "is_verified": false,
  "created_at": "2026-03-28T20:00:00Z",
  "updated_at": "2026-03-28T20:00:00Z"
}
```

常见错误：

- `409`：用户名已存在
- `409`：邮箱已存在

### 2. 用户登录

接口：

```text
POST /api/v1/users/login
```

请求体：

```json
{
  "username": "alice",
  "password": "pass123456"
}
```

成功返回：

```json
{
  "message": "登录成功",
  "user": {
    "user_id": 1,
    "username": "alice",
    "email": "alice@example.com",
    "nickname": "Alice",
    "bio": "喜欢修图",
    "avatar_url": null,
    "banner_url": null,
    "total_likes": 0,
    "follower_count": 0,
    "following_count": 0,
    "member_level": "free",
    "is_verified": false,
    "created_at": "2026-03-28T20:00:00Z",
    "updated_at": "2026-03-28T20:00:00Z"
  }
}
```

常见错误：

- `401`：用户名或密码错误

### 3. 获取用户详情

接口：

```text
GET /api/v1/users/{user_id}
```

示例：

```text
GET /api/v1/users/1
```

### 4. 更新用户资料

接口：

```text
PATCH /api/v1/users/{user_id}
```

请求体字段均可选：

```json
{
  "nickname": "新昵称",
  "bio": "新的个人简介",
  "avatar_url": "https://example.com/avatar.png",
  "banner_url": "https://example.com/banner.png",
  "member_level": "pro",
  "is_verified": true
}
```

### 5. 关注用户

接口：

```text
POST /api/v1/users/{user_id}/follow
```

说明：

- 路径中的 `user_id` 是“被关注的人”
- 请求体中的 `follower_id` 是“发起关注的人”

请求体：

```json
{
  "follower_id": 1
}
```

### 6. 取消关注

接口：

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

接口：

```text
GET /api/v1/users/{user_id}/followers
```

返回结构为 `UserSummary[]`。

### 8. 获取关注列表

接口：

```text
GET /api/v1/users/{user_id}/following
```

返回结构为 `UserSummary[]`。

---

## 四、社区接口

统一前缀：

```text
/api/v1/community
```

### 1. 创建帖子

接口：

```text
POST /api/v1/community/posts
```

请求体：

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

- `tag_names` 可以带 `#`，后端会自动去掉前缀并去重
- `asset_node_id` 可选；如果帖子图片来自资产树，可以把节点 ID 传上来

成功返回：

- `PostOut`
- 内含 `images[]` 与 `tags[]`

### 2. 列出帖子

接口：

```text
GET /api/v1/community/posts
```

可选查询参数：

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

接口：

```text
GET /api/v1/community/posts/{post_id}
```

说明：

- 每次获取详情时，后端会自动将 `view_count + 1`

### 4. 发表评论

接口：

```text
POST /api/v1/community/posts/{post_id}/comments
```

一级评论请求体：

```json
{
  "user_id": 2,
  "content": "一级评论"
}
```

二级评论请求体：

```json
{
  "user_id": 1,
  "content": "回复评论",
  "parent_id": 10
}
```

当前限制：

- 只支持两层评论
- 不能继续回复二级评论

### 5. 获取评论列表

接口：

```text
GET /api/v1/community/posts/{post_id}/comments
```

返回：

```json
{
  "post_id": 1,
  "comments": [
    {
      "comment_id": 1,
      "post_id": 1,
      "user_id": 2,
      "parent_id": null,
      "root_id": null,
      "content": "一级评论",
      "like_count": 0,
      "reply_count": 1,
      "level": 1,
      "created_at": "...",
      "updated_at": "..."
    }
  ]
}
```

### 6. 点赞帖子

接口：

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

接口：

```text
DELETE /api/v1/community/posts/{post_id}/like
```

请求体：

```json
{
  "user_id": 2
}
```

### 8. 收藏帖子

接口：

```text
POST /api/v1/community/posts/{post_id}/favorite
```

请求体：

```json
{
  "user_id": 2
}
```

### 9. 取消收藏帖子

接口：

```text
DELETE /api/v1/community/posts/{post_id}/favorite
```

请求体：

```json
{
  "user_id": 2
}
```

### 10. 点赞评论

接口：

```text
POST /api/v1/community/comments/{comment_id}/like
```

请求体：

```json
{
  "user_id": 1
}
```

### 11. 取消评论点赞

接口：

```text
DELETE /api/v1/community/comments/{comment_id}/like
```

请求体：

```json
{
  "user_id": 1
}
```

### 12. 获取标签列表

接口：

```text
GET /api/v1/community/tags
```

返回为 `TagOut[]`，按热度和名称排序。

---

## 五、透镜市场接口

统一前缀：

```text
/api/v1/market
```

### 1. 创建市场透镜

接口：

```text
POST /api/v1/market/lenses
```

请求体：

```json
{
  "lens_key": "lens_market_portrait_v1",
  "name": "人像柔光镜",
  "description": "适合人像氛围增强",
  "author_id": 1,
  "category": "portrait",
  "price": "9.90",
  "is_official": false,
  "status": "active"
}
```

说明：

- `lens_key` 是市场透镜唯一键
- `author_id` 为用户表中的整数 ID

### 2. 更新市场透镜

接口：

```text
PATCH /api/v1/market/lenses/{lens_id}
```

请求体字段均可选，例如：

```json
{
  "name": "人像柔光镜 Pro",
  "price": "12.50"
}
```

### 3. 列出市场透镜

接口：

```text
GET /api/v1/market/lenses
```

可选查询参数：

- `category`
- `status`
- `is_official`

示例：

```text
GET /api/v1/market/lenses?category=portrait
GET /api/v1/market/lenses?is_official=true
```

### 4. 获取透镜详情

接口：

```text
GET /api/v1/market/lenses/{lens_id}
```

返回结构：

- 市场透镜基础信息
- `versions[]`
- `reviews[]`

### 5. 创建透镜版本

接口：

```text
POST /api/v1/market/lenses/{lens_id}/versions
```

请求体：

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

接口：

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
- 如果不传，后端会优先安装 `is_latest=true` 的版本

### 7. 卸载透镜

接口：

```text
DELETE /api/v1/market/lenses/{lens_id}/install
```

请求体：

```json
{
  "user_id": 2
}
```

### 8. 收藏透镜

接口：

```text
POST /api/v1/market/lenses/{lens_id}/favorite
```

请求体：

```json
{
  "user_id": 2
}
```

### 9. 取消收藏透镜

接口：

```text
DELETE /api/v1/market/lenses/{lens_id}/favorite
```

请求体：

```json
{
  "user_id": 2
}
```

### 10. 创建或更新评价

接口：

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

- 同一个用户对同一个市场透镜只有一条评价
- 再次调用会更新原评价

### 11. 获取用户已安装透镜

接口：

```text
GET /api/v1/market/users/{user_id}/installed
```

### 12. 获取用户收藏透镜

接口：

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
- 只有互相关注的双方才能创建私聊会话
- 如果历史会话已经存在，但双方后来不再互关，则仍可读取历史消息，但发送新消息会被拒绝

### 2. 获取可私聊好友列表

接口：

```text
GET /api/v1/chat/friends/{user_id}
```

说明：

- 返回当前用户“互相关注”的好友列表
- 如果和某个好友已经建立过私聊，会额外返回 `conversation_id`

返回示例：

```json
[
  {
    "user_id": 2,
    "username": "bob",
    "nickname": "Bob",
    "avatar_url": "https://example.com/bob.png",
    "is_verified": false,
    "conversation_id": 12,
    "last_message_at": "2026-03-30T12:00:00Z"
  }
]
```

### 3. 创建或打开好友私聊

接口：

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

说明：

- 如果双方第一次私聊，会创建新会话，返回 `created=true`
- 如果历史会话已存在，则直接返回原会话，`created=false`

成功返回：

```json
{
  "created": true,
  "conversation": {
    "conversation_id": 12,
    "participant_user_ids": [1, 2],
    "peer_user": {
      "user_id": 2,
      "username": "bob",
      "nickname": "Bob",
      "avatar_url": null,
      "is_verified": false
    },
    "last_message": null,
    "last_message_at": null,
    "unread_count": 0,
    "created_at": "2026-03-30T12:00:00Z",
    "updated_at": "2026-03-30T12:00:00Z"
  }
}
```

常见错误：

- `400`：双方未互相关注
- `400`：不能给自己发起私聊
- `404`：用户不存在

### 4. 获取会话列表

接口：

```text
GET /api/v1/chat/conversations?user_id=1
```

说明：

- 返回当前用户参与的所有私聊会话
- `peer_user` 是“对方用户”的摘要
- `last_message` 是最后一条消息的预览
- `unread_count` 是当前用户未读消息数

### 5. 获取会话详情

接口：

```text
GET /api/v1/chat/conversations/{conversation_id}?user_id=1
```

说明：

- 用于聊天页顶部加载会话摘要、对方用户信息、未读数
- 只有会话参与者本人可以访问

### 6. 获取会话消息列表

接口：

```text
GET /api/v1/chat/conversations/{conversation_id}/messages
```

查询参数：

- `user_id`：当前用户 ID，必传
- `limit`：单次拉取消息数，默认 `50`，最大 `100`
- `before_message_id`：向上翻页时传入，只获取比它更早的消息

示例：

```text
GET /api/v1/chat/conversations/12/messages?user_id=1&limit=20
GET /api/v1/chat/conversations/12/messages?user_id=1&limit=20&before_message_id=88
```

返回示例：

```json
{
  "conversation_id": 12,
  "messages": [
    {
      "message_id": 101,
      "conversation_id": 12,
      "sender_id": 1,
      "message_type": "text",
      "content": "你好",
      "share": null,
      "created_at": "2026-03-30T12:01:00Z"
    }
  ],
  "has_more": false
}
```

### 7. 发送纯文本消息

接口：

```text
POST /api/v1/chat/conversations/{conversation_id}/messages
```

请求体：

```json
{
  "sender_id": 1,
  "content": "你好，这是一条纯文本消息"
}
```

### 8. 发送帖子分享消息

接口：

```text
POST /api/v1/chat/conversations/{conversation_id}/messages
```

请求体：

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

说明：

- `content` 可选，可以只发分享卡片不带文字
- 帖子分享会在消息里自动生成卡片快照
- 如果帖子是私密帖，当前只允许作者本人分享

### 9. 发送预设分享消息

接口：

```text
POST /api/v1/chat/conversations/{conversation_id}/messages
```

方式一：分享透镜市场预设

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

方式二：分享资产树节点预设

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

- `share_type=preset` 时，`market_lens_id` 和 `asset_node_id` 二选一，且只能传一个
- 后端会把预设信息转成统一的分享卡片结构，前端不需要再额外拼字段

### 10. 标记会话已读

接口：

```text
POST /api/v1/chat/conversations/{conversation_id}/read
```

请求体：

```json
{
  "user_id": 1,
  "last_read_message_id": 101
}
```

说明：

- `last_read_message_id` 可选
- 如果不传，默认会把该会话当前最新消息标记为已读

### 11. 聊天消息结构说明

聊天消息里的几个关键字段：

- `message_type`
  - `text`：纯文本消息
  - `share`：纯分享消息
  - `text_share`：文字 + 分享卡片
- `share.share_type`
  - `post`：帖子分享
  - `preset`：预设分享
- `share.share_source_type`
  - `community_post`：来自社区帖子
  - `market_lens`：来自透镜市场预设
  - `asset_node`：来自资产树节点预设

前端渲染时建议优先判断：

1. `share` 是否为 `null`
2. 若不为 `null`，根据 `share_type` 决定渲染“帖子卡片”还是“预设卡片”
3. 再根据 `share_source_type` 补充跳转逻辑

---

## 七、资产树接口

统一前缀：

```text
/api/v1/asset-tree
```

这部分主要服务于“编辑器项目、历史版本树、分支管理”。

### 1. 创建项目

接口：

```text
POST /api/v1/asset-tree/projects
```

请求体：

```json
{
  "name": "项目一",
  "description": "测试项目"
}
```

### 2. 获取项目列表

接口：

```text
GET /api/v1/asset-tree/projects
```

### 3. 获取项目详情

接口：

```text
GET /api/v1/asset-tree/projects/{project_id}
```

注意：

- `project_id` 是 UUID 字符串

### 4. 更新项目信息

接口：

```text
PATCH /api/v1/asset-tree/projects/{project_id}
```

请求体字段可选：

```json
{
  "name": "新项目名",
  "description": "新的描述",
  "cover_url": "https://example.com/cover.png"
}
```

### 5. 切换当前节点

接口：

```text
POST /api/v1/asset-tree/projects/{project_id}/current-node
```

请求体：

```json
{
  "node_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### 6. 删除项目

接口：

```text
DELETE /api/v1/asset-tree/projects/{project_id}
```

### 7. 获取完整树结构

接口：

```text
GET /api/v1/asset-tree/projects/{project_id}/tree
```

这个接口是编辑器历史树渲染的核心接口。

返回：

- `project`
- `nodes[]`
- `edges[]`

前端可以直接根据：

- `nodes[].node_id`
- `edges[].source_node_id`
- `edges[].target_node_id`

构建树形图或 DAG 视图。

### 8. 添加根节点

接口：

```text
POST /api/v1/asset-tree/projects/{project_id}/root-node
```

请求体：

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
- 前端/调用方应先完成图片上传，再把 URL 传给后端

### 9. 创建子节点

接口：

```text
POST /api/v1/asset-tree/projects/{project_id}/nodes
```

请求体：

```json
{
  "parent_node_id": "550e8400-e29b-41d4-a716-446655440000",
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

### 10. 获取节点详情

接口：

```text
GET /api/v1/asset-tree/nodes/{node_id}
```

### 11. 更新节点状态

接口：

```text
PATCH /api/v1/asset-tree/nodes/{node_id}/status
```

请求体：

```json
{
  "status": "completed",
  "image_url": "s3://bucket/final.png",
  "thumbnail_url": "s3://bucket/final_thumb.png",
  "execution_time_ms": 5000
}
```

这个接口主要用于：

- 先创建一个 `generating` 节点
- 后续异步任务完成后回填结果

### 12. 获取祖先路径

接口：

```text
GET /api/v1/asset-tree/nodes/{node_id}/ancestors
```

返回：

- `ancestors[]`
- `path_edges[]`

前端可用于：

- 面包屑
- 当前版本来源链路展示

### 13. 获取后代节点

接口：

```text
GET /api/v1/asset-tree/nodes/{node_id}/descendants
```

### 14. 删除节点

接口：

```text
DELETE /api/v1/asset-tree/nodes/{node_id}?cascade=false
```

说明：

- `cascade=false`：只能删叶子节点
- `cascade=true`：删除整个子树

### 15. 比较两个节点

接口：

```text
GET /api/v1/asset-tree/nodes/compare?nodeA={node_id}&nodeB={node_id}
```

返回：

- `node_a`
- `node_b`
- `edge`（如果两者存在直接边）

### 16. 添加节点标签

接口：

```text
POST /api/v1/asset-tree/nodes/{node_id}/tags
```

请求体：

```json
{
  "label": "最终版",
  "color": "#4A90E2"
}
```

### 17. 获取节点标签

接口：

```text
GET /api/v1/asset-tree/nodes/{node_id}/tags
```

### 18. 删除节点标签

接口：

```text
DELETE /api/v1/asset-tree/tags/{tag_id}
```

---

## 八、运行时 Lens 注册表接口

统一前缀：

```text
/api/v1/lenses
```

这组接口主要服务于“后端运行时能力注册表”，而不是市场透镜。

前端如果只是做市场页，一般不直接调用这组接口；  
如果要做“开发者透镜管理台”或“内部透镜配置页”，则会用到。

### 1. 注册运行时 Lens

接口：

```text
POST /api/v1/lenses/register
```

请求体示例：

```json
{
  "lens_id": "lens_inpaint_bg",
  "layer": "A2",
  "description": "局部重绘",
  "workflow_file_path": "lens_inpaint_bg.json",
  "inputs": [
    {
      "name": "base_image",
      "type": "image",
      "mapping": {
        "node_id": "1",
        "field_name": "image"
      }
    }
  ],
  "outputs": [
    {
      "name": "result_image",
      "type": "image",
      "mapping": {
        "node_id": "11",
        "field_name": "images"
      }
    }
  ],
  "params": [
    {
      "name": "positive_prompt",
      "type": "text",
      "description": "描述重绘内容",
      "mapping": {
        "node_id": "8",
        "field_name": "text"
      }
    }
  ],
  "examples": [
    {
      "nl_desc": "把背景换成海边黄昏",
      "params_example": {
        "positive_prompt": "beach sunset"
      }
    }
  ]
}
```

### 2. 获取运行时 Lens 列表

接口：

```text
GET /api/v1/lenses/
```

### 3. 获取单个运行时 Lens 详情

接口：

```text
GET /api/v1/lenses/{lens_id}
```

注意：

- 这里的 `lens_id` 是字符串，例如 `lens_inpaint_bg`
- 不是透镜市场的整数 `lens_id`

### 4. 删除运行时 Lens

接口：

```text
DELETE /api/v1/lenses/{lens_id}
```

### 5. 重载运行时 Lens 注册表

接口：

```text
POST /api/v1/lenses/reload
```

这个接口适合管理后台在“磁盘工作流有改动”后手动刷新注册表。

---

## 九、推荐前端调用流程

### 1. 用户与社区的基础流程

推荐顺序：

1. 注册或登录用户
2. 缓存 `user_id`
3. 发帖时把 `user_id` 带到请求体中
4. 点赞、收藏、评论时同样显式传 `user_id`

### 2. 透镜市场的基础流程

推荐顺序：

1. 列表页调用 `GET /api/v1/market/lenses`
2. 详情页调用 `GET /api/v1/market/lenses/{lens_id}`
3. 安装时调用 `POST /install`
4. 收藏时调用 `POST /favorite`
5. 评价时调用 `POST /reviews`

### 3. 好友聊天与私聊分享流程

推荐顺序：

1. 先通过关注接口让双方成为互关关系
2. 调用 `GET /api/v1/chat/friends/{user_id}` 获取可私聊好友
3. 点击某个好友时，调用 `POST /api/v1/chat/conversations/direct`
4. 聊天页进入后，调用 `GET /messages` 拉取历史消息
5. 发送纯文本、帖子分享或预设分享时，统一调用 `POST /messages`
6. 页面停留或退出前调用 `POST /read` 更新已读状态

### 4. 编辑器项目与资产树流程

推荐顺序：

1. 创建项目
2. 上传原图后调用 `root-node`
3. 每次生成结果后调用 `create child node`
4. 历史树页面调用 `GET /tree`
5. 点击旧节点时调用 `current-node`
6. 需要回溯链路时调用 `ancestors`

### 5. 内部 Lens 管理台流程

推荐顺序：

1. 查看运行时 Lens 列表
2. 注册新 Lens
3. 查看单个 Lens 详情
4. 必要时删除或重载

---

## 十、前端调用时的注意事项

### 1. 市场透镜和运行时 Lens 是两套体系

请前端不要把下面两者混为一谈：

- 市场透镜：`/api/v1/market/...`
- 运行时 Lens 注册表：`/api/v1/lenses/...`

简化理解：

- 市场透镜是“商品/内容”
- 运行时 Lens 是“后端可编排能力”

### 2. 当前很多接口都显式要求传 `user_id`

这是当前阶段的设计现实，不是 Bug。

前端请不要等待后端自动识别用户身份。

### 3. 好友聊天要求双方互关

前端不要直接假设“关注了对方”就一定能发私信。

真正可私聊的条件是：

- A 关注 B
- B 也关注 A

建议聊天入口直接使用：

- `GET /api/v1/chat/friends/{user_id}`

而不是自己在前端拼互关逻辑。

### 4. 聊天分享消息有统一卡片结构

无论分享的是帖子还是预设，后端都会返回统一的 `share` 对象。

前端请不要再自行二次请求去拼“标题、封面、作者”这些基础字段，优先直接使用消息里的 `share` 快照渲染。

### 5. 资产树模块大量使用 UUID 字符串

前端在状态管理中不要把这些 ID 当整数处理。

### 6. DELETE 请求有 body

如果使用 `fetch`、`axios`、`Dio`，要确认：

- DELETE 请求是否支持传 JSON body
- 若不支持，需单独配置

### 7. 帖子详情接口会增加浏览数

前端如果只是静默刷新帖子内容，请注意它会增加 `view_count`。

---

## 十一、建议的前端封装方式

前端建议按模块封装 API：

- `userApi`
- `communityApi`
- `marketApi`
- `chatApi`
- `assetTreeApi`
- `lensRegistryApi`

建议统一封装：

- 基础 URL
- 错误处理
- JSON 序列化
- DELETE 带 body 的特殊处理

---

## 十二、建议的联调优先级

如果前端要开始联调，推荐顺序如下：

1. 用户注册 / 登录 / 获取用户详情
2. 社区发帖 / 拉帖子列表 / 评论 / 点赞
3. 好友互关 / 打开私聊 / 发文本消息 / 分享帖子或预设
4. 透镜市场列表 / 详情 / 安装 / 收藏 / 评价
5. 资产树项目创建 / 根节点 / 子节点 / 树结构展示
6. 最后再考虑运行时 Lens 管理台

这样可以先把用户可感知路径打通。

---

## 十三、结论

当前后端数据库相关 API 已经具备前端联调条件，前端开发时最重要的几件事是：

- 明确区分整数 ID 与 UUID 字符串 ID
- 明确区分市场透镜和运行时 Lens
- 明确聊天功能要求双方互关
- 当前阶段所有用户行为都要显式传 `user_id`
- DELETE 请求里有些接口必须带 body

如果前端严格按照本文档调用，当前后端接口已经足够支撑：

- 用户页
- 社区页
- 好友聊天页
- 透镜市场页
- 编辑器历史树页
- 内部透镜管理页
