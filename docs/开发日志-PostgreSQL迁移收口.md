# MuseLens 开发日志 · PostgreSQL 迁移收口

## 一、本次工作的目标

本次工作的目标，是把后端从“正在迁移到 PostgreSQL”推进到“后端主链路已经可以稳定使用 PostgreSQL”，并补齐对应的自动化验证。

本次工作只处理后端，不涉及前端联调与 UI 改动。

---

## 二、本次完成的内容

### 1. 数据库入口统一

对后端数据库入口进行了统一整理：

- 优先读取 `MUSELENS_DB_URL`
- 同时兼容 `DATABASE_URL`
- 若未提供数据库连接串，则回退到本地 SQLite，方便单元测试与轻量调试
- 自动把 `postgresql://...` 规范化为 `postgresql+psycopg://...`

这样做的目的，是让：

- 生产/本地正式运行时，默认走 PostgreSQL
- 单元测试时，不会因为强依赖 PostgreSQL 而无法运行

对应文件：

- `backend/app/core/database.py`

### 2. ORM 模型完成 PostgreSQL 优先改造

对后端核心 ORM 模型做了统一收口，重点解决了 PostgreSQL 与测试环境兼容的问题。

本次处理了以下模型：

- `backend/app/models/lens_model.py`
- `backend/app/models/lens_example_model.py`
- `backend/app/models/router_session_model.py`
- `backend/app/models/asset_tree_models.py`

主要改动包括：

- 将结构化 JSON 数据统一改为 PostgreSQL 优先的 JSON 类型映射
- 将主键与节点/会话/任务相关 ID 统一为 UUID 字符串语义
- 将资产树路径字段统一为 PostgreSQL 优先的数组/兼容映射
- 清理旧版模型残留和重复定义
- 统一时间字段的默认值与更新时间策略

为了兼容 PostgreSQL 与 SQLite 测试环境，本次新增了一个跨数据库类型映射文件：

- `backend/app/models/sql_types.py`

这个文件的作用是：

- 在 PostgreSQL 下使用原生能力，如 `UUID`、`JSONB`、`UUID[]`
- 在 SQLite 下自动降级为可创建、可测试的兼容类型

### 3. Lens 注册表完成收口

对 Lens 注册表进行了重构和补齐，解决了以下问题：

- 补齐了内置 Lens 配置目录扫描逻辑
- 补齐了内置 Lens 直接加载到内存的逻辑
- 保留数据库驱动注册表能力
- 统一了工作流路径解析逻辑
- 统一了内置配置导入与数据库 seed 逻辑

对应文件：

- `backend/app/lenses/registry.py`

本次收口后，注册表现在支持三种典型场景：

1. 启动时从数据库重载 Lens 到内存
2. 数据库为空时，将内置 Lens 配置写入数据库
3. 测试环境不依赖数据库也可以直接加载内置 Lens 到内存

### 4. 服务层完成 PostgreSQL 兼容调整

对依赖数据库结构的服务层进行了同步调整，避免继续使用旧字段名或旧序列化方式。

处理的主要文件：

- `backend/app/services/asset_tree_service.py`
- `backend/app/services/retrieval_service.py`
- `backend/app/services/blueprint_validator.py`

本次调整的重点包括：

- 移除对旧字段 `inputs_json / outputs_json / params_json` 的依赖
- 直接使用 ORM 层已经反序列化后的结构化字段
- 资产树服务统一读取新模型字段
- 祖先路径描述从旧的 `path_json` 更新为当前的 `path`

### 5. API 层完成配套修正

对后端部分 API 端点做了同步修正，保证接口描述与实际模型一致。

处理文件：

- `backend/app/api/v1/endpoints/asset_tree.py`
- `backend/app/api/v1/endpoints/lenses.py`

主要修正点：

- Lens 详情接口改为直接返回新字段结构
- 资产树接口文案改为和当前 PostgreSQL 路径字段一致
- 清理与旧模型不一致的节点创建参数写法

### 6. 初始化脚本更新

重新整理了数据库初始化脚本：

- `backend/scripts/init_db.py`

现在它可以：

- 根据当前环境变量连接数据库
- 自动建表
- 在 PostgreSQL 下尝试检测 `pgvector`
- 即使本机尚未安装 `pgvector`，也不会阻塞普通数据库初始化

### 7. 依赖更新

更新了后端依赖文件：

- `backend/requirements.txt`

核心变化：

- 移除旧的 `psycopg2-binary`
- 改为使用 `psycopg[binary]`

这样和当前 SQLAlchemy 的 PostgreSQL 连接方式保持一致。

---

## 三、测试工作

### 1. 修复并更新现有测试

本次对现有后端测试做了同步更新，使其适配新的 PostgreSQL 优先模型结构。

处理的测试文件包括：

- `backend/tests/test_db_lens_registry.py`
- `backend/tests/test_lens_api.py`
- `backend/tests/test_lens_docs_service.py`
- `backend/tests/test_retrieval_service.py`

调整重点：

- 移除旧字段 `inputs_json / outputs_json / params_json`
- 改为使用当前模型的 `inputs / outputs / params`
- 让测试继续覆盖注册表、Lens API、文档叠加、检索等能力

### 2. 新增 PostgreSQL 集成测试

本次新增了一份专门面向 PostgreSQL 的集成测试：

- `backend/tests/test_postgres_backend_integration.py`

这份测试会在运行时：

- 连接本机 PostgreSQL 管理库
- 临时创建一个测试数据库
- 在测试数据库内建表
- 验证 ORM 能正常读写
- 验证 Lens API 能正常写库、读库
- 验证资产树 API 能正常写库、查询
- 测试结束后自动删除临时数据库

这份测试的意义是：

- 不只验证“代码看起来支持 PostgreSQL”
- 而是验证“后端确实能在真实 PostgreSQL 上跑起来”

---

## 四、本地验证结果

本次在本机环境中完成了以下验证：

### 1. PostgreSQL 连接验证

使用如下账号成功连通本机 PostgreSQL：

- 用户：`postgres`
- 密码：`123cfx`
- 主库：`postgres`

### 2. 正式数据库创建

已在本机 PostgreSQL 中创建数据库：

- `muselens`

### 3. 正式数据库建表验证

已使用如下连接串成功执行初始化脚本并完成建表：

```text
postgresql+psycopg://postgres:123cfx@localhost:5432/muselens
```

### 4. 自动化测试结果

执行结果如下：

- 全量后端测试：`58 passed, 2 skipped`
- PostgreSQL 集成测试：`3 passed`

说明：

- 后端主链路当前已经可以正常使用 PostgreSQL
- 当前未处理的部分不会影响普通数据库使用

---

## 五、当前未处理项

本次明确没有继续处理 `pgvector` 的实际安装与接通。

这意味着：

- PostgreSQL 作为业务数据库已经可正常使用
- Lens 注册、资产树、Router 会话、普通 API 都可正常工作
- 但 `pgvector` 相关能力目前仍属于后续工作

当前 `pgvector` 未接通不会影响：

- 后端服务启动
- 普通数据库建表
- 普通业务数据读写
- 当前已完成的自动化测试

---

## 六、当前推荐的启动方式

在 `backend` 目录下，推荐使用以下方式启动：

```powershell
$env:MUSELENS_DB_URL="postgresql+psycopg://postgres:123cfx@localhost:5432/muselens"
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

初始化数据库可使用：

```powershell
$env:MUSELENS_DB_URL="postgresql+psycopg://postgres:123cfx@localhost:5432/muselens"
python scripts/init_db.py
```

运行全部后端测试可使用：

```powershell
$env:PYTHONPATH="."
python -m pytest tests -q
```

运行 PostgreSQL 集成测试可使用：

```powershell
$env:PYTHONPATH="."
$env:MUSELENS_TEST_POSTGRES_DSN="postgresql://postgres:123cfx@localhost:5432/postgres"
python -m pytest tests/test_postgres_backend_integration.py -q
```

---

## 七、结论

本次 PostgreSQL 迁移工作已经完成到“后端可稳定使用”的阶段，具体表现为：

- 数据库入口已统一
- ORM 模型已收口
- 注册表与服务层已同步迁移
- 现有测试已适配
- 新增了真实 PostgreSQL 集成测试
- 本机 PostgreSQL 已完成建库与建表验证

当前后端已经具备作为 PostgreSQL 版本继续开发的基础。

后续如果继续推进，最自然的下一步会是：

1. 接通 `pgvector`
2. 让 RAG 检索真正使用 PostgreSQL 向量能力
3. 再推进 Router/Planner 的进一步联调
