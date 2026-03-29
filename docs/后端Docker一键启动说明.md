# MuseLens 后端 Docker 一键启动说明

## 一、文档目的

本文档说明如何使用 Docker 一键启动 MuseLens 的后端服务。

当前这套 Docker 方案包含两个容器：

- PostgreSQL 数据库容器
- FastAPI 后端容器

适用场景：

- 本地快速启动后端
- 前后端联调
- 不想在本机手动启动 Python 与 PostgreSQL 服务

---

## 二、当前 Docker 文件位置

本次新增的 Docker 相关文件如下：

- `backend/Dockerfile`
- `backend/.dockerignore`
- `docker-compose.backend.yml`

其中：

- `Dockerfile` 用来构建后端镜像
- `docker-compose.backend.yml` 用来一键拉起数据库和后端

---

## 三、启动前提

在启动前，请确保：

1. Docker Desktop 已经能够正常启动
2. 当前命令行里可以执行：

```powershell
docker version
```

并且能正常返回客户端和服务端信息。

---

## 四、一键启动命令

在项目根目录下执行：

```powershell
cd d:\Match\MuseLens
docker compose -f docker-compose.backend.yml up -d --build
```

说明：

- `-f docker-compose.backend.yml`：指定本项目的后端编排文件
- `up -d`：后台启动容器
- `--build`：如有改动，重新构建后端镜像

---

## 五、启动后的访问地址

### 1. 后端服务地址

启动成功后，后端地址为：

```text
http://127.0.0.1:8000
```

### 2. Swagger UI 地址

可以直接打开：

```text
http://127.0.0.1:8000/docs
```

用于测试后端接口。

### 3. Docker 内 PostgreSQL 对外端口

为了避免与你本机已经安装的 PostgreSQL 冲突，Docker 里的 PostgreSQL 映射到宿主机：

```text
127.0.0.1:5433
```

连接信息如下：

- 用户名：`postgres`
- 密码：`123cfx`
- 数据库：`muselens`
- 端口：`5433`

如果你要从宿主机连这个 Docker 数据库，连接串可以写成：

```text
postgresql://postgres:123cfx@localhost:5433/muselens
```

注意：

- 容器内部后端连接数据库时，并不走 `5433`
- 容器内部使用的是服务名：

```text
postgresql+psycopg://postgres:123cfx@postgres:5432/muselens
```

---

## 六、如何确认是否启动成功

### 方法 1：查看容器状态

在项目根目录执行：

```powershell
docker compose -f docker-compose.backend.yml ps
```

正常情况下你会看到类似：

- `muselens-postgres` 为 `healthy`
- `muselens-backend` 为 `healthy`

### 方法 2：访问根路由

在浏览器中打开：

```text
http://127.0.0.1:8000/
```

如果启动成功，会返回类似：

```json
{
  "status": "online",
  "message": "MuseLens Backend is running!",
  "docs_url": "http://127.0.0.1:8000/docs",
  "registered_lenses": [
    "lens_depth_extract",
    "lens_inpaint_bg",
    "lens_sam2_matting"
  ]
}
```

### 方法 3：访问 Swagger UI

在浏览器中打开：

```text
http://127.0.0.1:8000/docs
```

如果页面能正常打开，就说明后端服务已经起来了。

---

## 七、我已完成的实际验证

本次 Docker 方案已经做过实际验证，确认以下内容可用：

### 1. 容器成功启动

已成功启动：

- `muselens-postgres`
- `muselens-backend`

### 2. 健康检查通过

已验证：

- PostgreSQL 容器健康检查通过
- 后端容器健康检查通过

### 3. 后端接口可访问

已验证：

- `GET /` 正常返回 `200`
- `GET /docs` 正常返回 `200`

### 4. 数据库相关 API 实际可用

已在容器环境下实际调用：

- 用户注册
- 用户登录

说明：

- 后端并不是“只启动成功”
- 而是已经能在容器里正常连数据库并执行数据库写入与读取

---

## 八、常用操作命令

### 1. 查看容器状态

```powershell
docker compose -f docker-compose.backend.yml ps
```

### 2. 查看后端日志

```powershell
docker compose -f docker-compose.backend.yml logs backend
```

如果只看最后 100 行：

```powershell
docker compose -f docker-compose.backend.yml logs backend --tail=100
```

### 3. 查看数据库日志

```powershell
docker compose -f docker-compose.backend.yml logs postgres
```

### 4. 停止容器

```powershell
docker compose -f docker-compose.backend.yml down
```

说明：

- 这会停止并删除容器
- 但不会删除数据库卷

### 5. 停止并删除数据库数据

```powershell
docker compose -f docker-compose.backend.yml down -v
```

说明：

- 这会同时删除数据库卷
- 下次启动会重新初始化数据库

### 6. 重新构建并启动

```powershell
docker compose -f docker-compose.backend.yml up -d --build
```

---

## 九、当前容器化方案的设计说明

### 1. 为什么数据库端口映射为 5433

因为你本机已经安装并使用了本地 PostgreSQL。

如果 Docker 里的 PostgreSQL 也映射到宿主机 `5432`，会直接端口冲突。

所以本次 Docker 方案将：

- 容器内 PostgreSQL：`5432`
- 宿主机映射端口：`5433`

### 2. 为什么 Compose 里只包含后端和数据库

因为你当前要求的是：

- 让整个后端能 Docker 化启动

所以当前不包含：

- 前端容器
- ComfyUI 容器
- pgvector 扩展容器

后续如果需要，可以继续扩展。

### 3. 当前是否包含 pgvector

当前这套 Docker 方案**不包含 pgvector**。

所以：

- 普通数据库读写没有问题
- 用户、社区、透镜市场、资产树都能正常使用
- 运行时 Lens 注册表也正常
- 但 RAG 的 pgvector 能力当前仍不在这套一键启动里

---

## 十、当前已知限制

### 1. 后端容器当前不连接 ComfyUI

目前后端虽然包含编辑器相关接口和执行逻辑，但这套 Docker 一键启动没有包含 ComfyUI。

因此：

- 数据库类接口能正常用
- Swagger 能正常测
- 但真正涉及 ComfyUI 图像生成链路的接口，不属于当前这套容器化验证范围

### 2. 启动速度第一次会比较慢

第一次执行：

```powershell
docker compose -f docker-compose.backend.yml up -d --build
```

会比较慢，原因是：

- 要构建后端镜像
- 要安装 Python 依赖

后续再次启动会快很多。

### 3. 如果网络环境较差，首次构建可能较慢

因为构建阶段需要：

- 安装系统包
- 安装 Python 依赖

这一步依赖外网速度。

---

## 十一、推荐的使用方式

如果你的目标是联调数据库相关 API，推荐顺序如下：

1. 启动 Docker：

```powershell
docker compose -f docker-compose.backend.yml up -d --build
```

2. 打开 Swagger：

```text
http://127.0.0.1:8000/docs
```

3. 先测试：

- 用户注册
- 用户登录
- 社区发帖
- 透镜市场创建
- 资产树创建项目

4. 联调完成后停止：

```powershell
docker compose -f docker-compose.backend.yml down
```

---

## 十二、结论

当前 MuseLens 后端已经支持通过 Docker 一键启动，且已经完成实际验证：

- 数据库容器可用
- 后端容器可用
- Swagger UI 可用
- 数据库相关 API 可正常读写

当前最推荐的启动命令就是：

```powershell
docker compose -f docker-compose.backend.yml up -d --build
```

如果你后续希望，我可以继续把：

- 前端
- pgvector
- ComfyUI

也逐步纳入 Docker 编排中，最终整理成完整的开发环境一键启动方案。
