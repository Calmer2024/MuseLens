# 图片同步到远程存储（MinIO）

## 问题分析

### 根本原因

当前前端多处使用 `LocalMediaStore` 将图片保存到**设备本地** `getApplicationSupportDirectory()/media/` 目录下，返回 `file:///...` 路径后直接写入数据库。后端原样存储这个本地路径到 PostgreSQL。

**问题链路（以社区发帖为例）**：

```
用户选图 → LocalMediaStore.persistXFile() → 返回 file:///C:/Users/.../media/community/posts/post_image_xxx.jpg
         → 作为 image_url 传给后端 POST /community/posts
         → 后端直接存入 post_images.image_url 字段
         → 其他设备请求该帖子 → 拿到 file:///... 路径 → 本地不存在该文件 → 图片加载失败
```

### 受影响的功能

| 功能 | 前端文件 | 使用方式 |
|------|----------|----------|
| **社区发帖图片** | `create_post_screen.dart:416` | `LocalMediaStore.persistXFile` → `file://` 路径存为 `image_url` |
| **用户头像** | `edit_profile_screen.dart:101` | `LocalMediaStore.persistXFile` → `file://` 路径存为 `avatar_url` |
| **编辑器结果图** | `editor_screen.dart:160,403,724,1230,1263` | 多处使用 `LocalMediaStore.persistFile/persistBytes` |
| **项目封面** | `consultant_screen.dart:556` | `LocalMediaStore.persistBytes` → 本地路径 |

### 后端现有能力

后端已有完善的 MinIO 对象存储体系：
- [object_storage_service.py](file:///e:/MuseLens/backend/app/services/object_storage_service.py) — 完整的 MinIO 上传/下载/签名 URL
- [storage_execution_service.py](file:///e:/MuseLens/backend/app/services/storage_execution_service.py) — `upload_user_image()` 工具函数
- [storage.py](file:///e:/MuseLens/backend/app/api/v1/endpoints/storage.py) — `GET /api/v1/storage/object?ref=...` 代理/重定向
- Router 模块的 `upload-base-image` 和 Lenses 模块的 `mask-assets/upload` 已经正确走 MinIO

**但社区模块和用户模块完全缺失图片上传接口**，前端也没有调用任何上传 API。

## 关于数据库帖子数据

> [!NOTE]
> 帖子数据是否还在需要连接服务器上的 PostgreSQL 才能确认。当前 `.env` 配置的 `PUBLIC_API_BASE_URL=http://47.99.211.191`，可以通过调用 `GET /api/v1/community/posts` 来检查。如果帖子还在，其 `image_url` 字段大概率是 `file:///...` 本地路径，指向的是当初发帖那台设备的本地文件系统。

## Open Questions

> [!IMPORTANT]
> **Q1: 改造范围确认** — 你希望这次一次性修复所有使用 `LocalMediaStore` 的地方（社区帖子、用户头像、编辑器、项目封面），还是先只修复社区帖子图片？

> [!IMPORTANT]
> **Q2: 后端服务是否在运行？** — 需要确认 `http://47.99.211.191` 上的后端服务和 MinIO 是否正在运行，这样我可以先查一下数据库中的帖子数据。

> [!IMPORTANT]
> **Q3: `MUSELENS_MINIO_PUBLIC_ENDPOINT` 当前为空** — 这意味着前端获取图片会走后端代理模式 (`/api/v1/storage/object?ref=...`)，而不是 MinIO 签名直链。这对手机端来说访问速度可能偏慢。你是否需要配置 MinIO 公网端点？还是先用代理模式即可？

## Proposed Changes

### 方案概述

核心思路：**图片先上传到 MinIO，拿到对象引用（`minio://bucket/key`），再将引用作为 URL 传给业务接口。前端展示时走后端代理或签名 URL。**

---

### 1. 后端 — 新增通用图片上传接口

#### [NEW] `backend/app/api/v1/endpoints/uploads.py`

新增一个通用的图片上传 endpoint，供社区帖子、用户头像等场景使用：

```python
POST /api/v1/uploads/image
Content-Type: multipart/form-data
Body: file (image binary), purpose (string: "community_post" | "avatar" | "editor_result" | "project_cover")

Response: {
    "object_ref": "minio://muselens-input/uploads/community/xxx.jpg",
    "download_url": "http://47.99.211.191/api/v1/storage/object?ref=..."
}
```

- 按 `purpose` 分 bucket 子路径（`uploads/community/`、`uploads/avatars/`等）
- 复用现有 `storage_service.put_bytes()` + `storage_service.get_download_url()`

#### [MODIFY] [main.py](file:///e:/MuseLens/backend/app/main.py)

注册新的 uploads router。

---

### 2. 前端 — 改造图片上传流程

#### [NEW] `frontend/lib/data/services/upload_service.dart`

新增上传服务：

```dart
class UploadService {
  /// 上传图片文件到后端 MinIO，返回 download_url
  Future<UploadResult> uploadImage(File file, {required String purpose});
  
  /// 上传字节数据到后端 MinIO
  Future<UploadResult> uploadImageBytes(Uint8List bytes, {required String purpose, String extension = 'png'});
}
```

#### [MODIFY] [create_post_screen.dart](file:///e:/MuseLens/frontend/lib/presentation/screens/community/create_post_screen.dart)

`_submit()` 方法改造：
- 原来: `LocalMediaStore.persistXFile()` → 本地 `file://` 路径
- 改为: `UploadService.uploadImage()` → 服务器返回的 `download_url`（HTTP URL）

#### [MODIFY] [edit_profile_screen.dart](file:///e:/MuseLens/frontend/lib/presentation/screens/profile/edit_profile_screen.dart)

头像上传改造，同理。

#### [MODIFY] [editor_screen.dart](file:///e:/MuseLens/frontend/lib/presentation/screens/editor/editor_screen.dart)

编辑器结果图保存改造。

#### [MODIFY] [consultant_screen.dart](file:///e:/MuseLens/frontend/lib/presentation/screens/create/consultant_screen.dart)

项目封面图保存改造。

---

### 3. 前端 — 图片展示兼容

#### [MODIFY] [adaptive_media.dart](file:///e:/MuseLens/frontend/lib/presentation/widgets/shared/adaptive_media.dart)

已支持 HTTP URL 和 `file://` 两种模式，无需修改。改造后新数据走 HTTP URL，旧数据（如果还有 `file://`）在本设备上仍可正常显示。

---

### 4. LocalMediaStore 保留

> [!NOTE]
> `LocalMediaStore` 本身不需要删除，它仍可用于纯本地缓存（如编辑器草稿临时缓存）。只是不再将其返回的路径作为持久化 URL 存入数据库。

## Verification Plan

### Automated Tests
- 后端: 启动 Docker Compose，调用 `POST /api/v1/uploads/image` 上传测试图片，验证返回 `object_ref` 和 `download_url`
- 后端: 调用 `GET /api/v1/storage/object?ref=<returned_ref>` 验证可下载
- 后端: 创建帖子时使用 HTTP URL 作为 image_url，验证帖子列表返回正确 URL

### Manual Verification
- 前端: 在 Flutter 上发布帖子 → 换设备（或清除 app 数据）→ 查看帖子图片是否正常加载
- 前端: 修改头像 → 换设备 → 查看头像是否正常显示
