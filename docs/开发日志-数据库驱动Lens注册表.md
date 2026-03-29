# MuseLens 开发日志 · 数据库驱动 Lens 注册表

---

## 一、背景与问题

### 原有设计意图

`registry.py` 的最初设计采用**文件扫描**机制：启动时自动扫描 `backend/app/lenses/config/` 目录下所有 `*.lens.json` 配置文件，逐个读取并构建内存注册表 `LENS_REGISTRY`。这一设计的优点是"数据与代码分离"——新增透镜只需添加配置文件，不需改 Python 代码。

### 发现的实际问题

经代码审查发现，**原设计存在以下关键缺陷**：

1. **配置目录根本不存在**：`backend/app/lenses/config/` 从未被创建，导致 `_build_registry()` 因目录缺失直接返回空字典，`LENS_REGISTRY` 始终为空。

2. **工作流文件已就位但无法被加载**：`backend/lens/` 目录中已存在 3 个 ComfyUI 工作流 JSON（`lens_inpaint_bg.json`、`lens_sam2_matting .json`、`lens_depth_extract.json`），但没有对应的 `.lens.json` 配置文件，无法被注册。

3. **纯文件管理缺乏可扩展性**：文件系统方案在运行时无法便捷地进行增删改查，也难以扩展为对外暴露的管理接口。

### 本次工作的目标

将 Lens 注册机制从"静态文件扫描"升级为**数据库驱动的动态注册体系**，并对外提供完整的 REST API，使 Lens 的注册、查询、注销操作无需重启服务即可生效。

---

## 二、整体架构设计

### 核心设计原则

| 原则 | 说明 |
|------|------|
| **数据与文件分离** | 数据库只存元数据和工作流文件路径，不存 JSON 内容本身，工作流 JSON 始终从磁盘读取 |
| **内存注册表为读取热路径** | `get_lens()` 始终从内存 `LENS_REGISTRY` 读取，零 I/O，无数据库查询延迟 |
| **写操作双写同步** | 注册/注销操作先写数据库（持久化），再同步更新内存注册表（立即生效） |
| **热更新，无需重启** | 注册或注销一个透镜后立即可被 Router/Compiler 调用，无需重启 uvicorn |
| **路径解析灵活** | `workflow_file_path` 支持绝对路径或相对 `backend/lens/` 的文件名，兼容 ComfyUI 任意输出目录 |

### 数据流示意

```
【注册时】
  POST /api/v1/lenses/register
        ↓ 验证工作流文件存在于磁盘
        ↓ 写入 / 更新数据库行（持久化）
        ↓ 从磁盘读取工作流 JSON + 解析插槽配置
        ↓ 构建 LensTemplate 写入内存 LENS_REGISTRY
        → 立即可被调用，无需重启

【调用时】
  registry.get_lens("lens_xxx")
        ↓ 直接从内存 LENS_REGISTRY 取（零延迟）
        → 返回 LensTemplate 供 Compiler 使用

【服务启动时】
  lifespan → init_db()（建表，幂等）
           → reload_registry(db)（从数据库全量加载到内存）
```

---

## 三、新增与修改的文件

### 目录结构变化

```
backend/
├── app/
│   ├── core/                         ← 新建目录
│   │   ├── __init__.py               ← 新建
│   │   └── database.py               ← 新建：数据库引擎与 Session
│   ├── models/                       ← 新建目录
│   │   ├── __init__.py               ← 新建
│   │   └── lens_model.py             ← 新建：Lens ORM 表定义
│   ├── lenses/
│   │   └── registry.py               ← 重构：改为数据库驱动
│   ├── api/v1/endpoints/
│   │   └── lenses.py                 ← 新建：Lens 管理 CRUD API
│   └── main.py                       ← 修改：挂载新路由 + lifespan 建表
├── requirements.txt                  ← 修改：添加 sqlalchemy>=2.0.0
└── muselens.db                       ← 运行时自动生成（SQLite 数据库文件）
```

---

## 四、各模块详细说明

### 4.1 `backend/app/core/database.py`

**职责**：管理 SQLAlchemy 引擎、Session 工厂与 ORM 基类。

- 数据库默认使用 **SQLite**，文件存放在 `backend/muselens.db`。
- 暴露 `get_db()` 生成器供 FastAPI `Depends()` 注入使用。
- 暴露 `init_db()` 函数，在应用启动时幂等建表（已存在的表不会重建）。
- 若需迁移至 PostgreSQL，只需修改 `SQLALCHEMY_DATABASE_URL`，其余代码无感知。

```python
# 切换数据库只需改这一行：
SQLALCHEMY_DATABASE_URL = "sqlite:///./muselens.db"
# → "postgresql://user:password@localhost/muselens"
```

---

### 4.2 `backend/app/models/lens_model.py`

**职责**：定义 `lenses` 数据库表的 ORM 结构。

**表字段**：

| 字段 | 类型 | 说明 |
|------|------|------|
| `lens_id` | TEXT (PK) | 全局唯一 ID，如 `lens_inpaint_bg` |
| `layer` | TEXT | 功能层级，A1 ~ A5 |
| `description` | TEXT | 人类/LLM 可读的功能描述 |
| `workflow_file_path` | TEXT | 工作流 JSON 的本地路径（不存内容） |
| `inputs_json` | TEXT | 输入资产插槽定义（序列化 JSON 字符串） |
| `outputs_json` | TEXT | 输出资产插槽定义（序列化 JSON 字符串） |
| `params_json` | TEXT | 可调参数插槽定义（序列化 JSON 字符串） |
| `created_at` | DATETIME | 首次注册时间（自动填充） |
| `updated_at` | DATETIME | 最近更新时间（自动更新） |

> **设计决策**：`inputs_json`、`outputs_json`、`params_json` 以 JSON 字符串形式存入 TEXT 列，而不是拆成关系表。原因是插槽定义是原子性数据，单独建表会增加关联查询复杂度，而 TEXT 列方案在读写时只需一次 `json.loads/dumps`，足够简洁。

---

### 4.3 `backend/app/lenses/registry.py`（重构）

**职责**：维护全局内存注册表 `LENS_REGISTRY`，提供透镜的注册、注销、查询与热重载接口。

**对外接口**：

```python
LENS_REGISTRY: Dict[str, LensTemplate]   # 全局内存注册表

get_lens(lens_id: str) -> LensTemplate   # 按 ID 检索（不存在则 KeyError）

reload_registry(db: Session)             # 从数据库全量重载内存注册表
register_lens(db: Session, data: dict)   # 注册新透镜（写 DB + 更新内存）
unregister_lens(db: Session, lens_id)    # 注销透镜（删 DB + 移除内存）
```

**工作流路径解析规则**（`_resolve_workflow_path`）：
1. 若为绝对路径且文件存在 → 直接使用。
2. 若为相对路径/文件名 → 在 `backend/lens/` 目录下查找。
3. 均不存在 → 抛出 `FileNotFoundError`，快速失败，阻止非法注册。

**启动时行为**：
- `LENS_REGISTRY` 初始化为空字典 `{}`，不再在模块导入时触发文件扫描或数据库查询。
- 真正的加载在 `main.py` 的 `lifespan` 中完成，确保数据库表已建好后再查询。

---

### 4.4 `backend/app/api/v1/endpoints/lenses.py`（新建）

**职责**：对外提供 Lens 注册表的 REST 管理接口。

**端点一览**：

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/v1/lenses/register` | 注册（或覆盖）一个透镜 |
| `GET` | `/api/v1/lenses/` | 列出全部已注册透镜的概要信息 |
| `GET` | `/api/v1/lenses/{lens_id}` | 查看单个透镜完整信息（含插槽定义） |
| `DELETE` | `/api/v1/lenses/{lens_id}` | 注销透镜 |
| `POST` | `/api/v1/lenses/reload` | 从数据库重载内存注册表（热更新） |

**注册请求体示例**：

```json
POST /api/v1/lenses/register
{
  "lens_id": "lens_inpaint_bg",
  "layer": "A2",
  "description": "SDXL 局部重绘：基于遮罩对指定区域进行语义重构（如换背景）",
  "workflow_file_path": "lens_inpaint_bg.json",
  "inputs": [
    {
      "name": "base_image",
      "type": "IMAGE",
      "mapping": { "node_id": "1", "field_name": "image" }
    },
    {
      "name": "mask_target",
      "type": "MASK",
      "mapping": { "node_id": "2", "field_name": "image" }
    }
  ],
  "outputs": [
    {
      "name": "result_image",
      "type": "IMAGE",
      "mapping": { "node_id": "11", "field_name": "images" }
    }
  ],
  "params": [
    {
      "name": "positive_prompt",
      "type": "TEXT",
      "description": "描述要重绘出来的内容",
      "mapping": { "node_id": "8", "field_name": "text" }
    }
  ]
}
```

---

### 4.5 `backend/app/main.py`（修改）

**修改内容**：

1. 引入 `asynccontextmanager` + `lifespan` 替换废弃的 `@app.on_event("startup")`。
2. 在 `lifespan` 启动阶段依次执行：
   - `init_db()`：建表（幂等）。
   - `reload_registry(db)`：从数据库全量加载注册表。
3. 挂载新路由 `/api/v1/lenses`。
4. 根路由健康检查响应中新增 `registered_lenses` 字段，便于快速确认注册状态。

---

## 五、使用流程指引

### 首次启动

```bash
cd backend
pip install -r requirements.txt   # 确保 sqlalchemy 已安装
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

启动日志中会看到：
```
[Registry] 注册表已从数据库加载，共 0 个透镜：[]
```
这是正常的——数据库刚建好，尚未注册任何透镜。

### 注册已有工作流文件（以 lens_inpaint_bg 为例）

打开 Swagger UI（`http://127.0.0.1:8000/docs`），找到 `POST /api/v1/lenses/register`，填入 JSON 请求体后执行。

或使用 curl：

```bash
curl -X POST http://127.0.0.1:8000/api/v1/lenses/register \
  -H "Content-Type: application/json" \
  -d '{
    "lens_id": "lens_inpaint_bg",
    "layer": "A2",
    "description": "SDXL 局部重绘",
    "workflow_file_path": "lens_inpaint_bg.json",
    "inputs": [...],
    "outputs": [...],
    "params": [...]
  }'
```

注册成功后，该透镜**立即可用**，无需重启服务。

### 查看当前注册情况

```bash
GET http://127.0.0.1:8000/api/v1/lenses/
```

### 注销透镜

```bash
DELETE http://127.0.0.1:8000/api/v1/lenses/lens_inpaint_bg
```

### 手动修改工作流 JSON 后同步更新

若在服务运行期间手动修改了磁盘上的工作流 JSON 文件，调用以下接口使变更生效：

```bash
POST http://127.0.0.1:8000/api/v1/lenses/reload
```

---

## 六、与原有代码的兼容性

### 对 Router 和 Compiler 无影响

- `get_lens(lens_id)` 函数签名未变，依然从内存 `LENS_REGISTRY` 读取。
- Router（`router_service.py`）和 Compiler（`compiler.py`）调用 `get_lens()` 的方式完全不需要修改。

### RAG 客户端无影响

- `InMemoryLensRAGClient` 依赖 `LENS_REGISTRY`，在 `reload_registry()` 后自动感知新注册的透镜。
- `PgVectorLensRAGClient`（骨架）不受影响。

### 原 .lens.json 配置文件机制

原 `backend/app/lenses/config/` 目录扫描机制已被数据库方案完全替代，不再需要手动创建 `.lens.json` 配置文件。

---

## 七、后续规划

1. **批量导入工具**：编写一个 CLI 脚本，一次性扫描 `backend/lens/` 目录中所有工作流 JSON，结合 LLM 辅助生成插槽定义，批量注册到数据库。

2. **迁移至 PostgreSQL**：当用户规模增大或需要多实例部署时，修改 `SQLALCHEMY_DATABASE_URL` 即可无感迁移。

3. **Lens 版本管理**：在 `lenses` 表中增加 `version` 字段，支持同一 `lens_id` 的多版本共存与回滚。

4. **前端管理界面**：在 Flutter 应用的 Lens 市集页（`lens/` 屏）接入注册表 API，实现图形化的透镜管理界面。
