项目初始化

# 项目结构

后端目录结构

```Plain
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # 入口文件：启动 FastAPI，挂载路由
│   ├── core/                # 核心配置
│   ├── models/              # 数据库模型 (ORM)
│   ├── schemas/             # Pydantic 数据模型
│   │   ├── lens.py          # [v3.0/Phase 2] A1-A5 LensAsset/LensParam 资产分离与拓扑定义
│   ├── api/                 # API 路由层
│   │   └── v1/
│   │       ├── endpoints/
│   │       │   ├── editor.py    # [Phase 2] 基于 WebSocket 的实时非阻塞推理流
│   │       │   └── test_run.py  # [Phase 2] 测试本地 A1->A2 异步 DAG 盲执行管线
│   ├── lenses/              # [v3.0 核心] 透镜注册表与实例化
│   │   └── registry.py      # 将 JSON 工作流注册为 Python 对象
│   └── services/            # 业务逻辑层
│       ├── compiler.py      # [v3.0 核心] 盲执行器、沙盒参数注入中心
│       └── comfy_service.py # 封装与 ComfyUI 的通信
├── .env                     # 环境变量
├── .gitignore
└── requirements.txt
```

### 核心架构理念 (v3.0)
系统后端架构遵循 **AOT链接 (Ahead-Of-Time Linking)** 与 **盲执行管线 (Blind Execution Pipeline)**，核心分为以下层：
1. **意图路由与沙盒注入:** 意图解析后分配唯一的变脸名 `asset_name` 和隔离前缀 `Session_ID`，交由 FastAPI 注入到独立的子任务 json 中。
2. **盲执行器 (Pipeline Executor):** 不再将不同功能的图拼接，而是作为一个个独立的微服务节点，独立发给 ComfyUI 计算。
3. **搬运中枢 (IO Mover):** 强制监听 ComfyUI `output` 的产出图，并按约定重命名搬回 `input` 目录完成无缝接力。

前端目录结构

```Plain
frontend/
├── assets/                  # 静态资源
│   ├── images/              # 图标、占位图
│   └── fonts/
├── lib/
│   ├── core/                # 核心通用代码
│   │   ├── constants/       # API 地址、全局常量
│   │   ├── theme/           # 颜色定义 (AppColors.burgundy...), 字体样式
│   │   └── utils/           # 工具函数 (日期格式化等)
│   ├── data/                # 数据层 (负责联网)
│   │   ├── models/          # Dart 实体类 (User, Recipe, ChatMessage)
│   │   ├── providers/       # Riverpod 状态管理 (全局状态)
│   │   └── services/        # API 服务
│   │       ├── api_client.dart   # Dio 封装 (HTTP)
│   │       └── socket_service.dart # WebSocket 封装 (监听生图进度)
│   ├── presentation/        # 表现层 (UI)
│   │   ├── widgets/         # 通用组件
│   │   │   ├── common/      # 按钮、输入框
│   │   │   └── chat/        # 聊天气泡、动态 Widget (滑块、色盘)
│   │   ├── screens/         # 页面
│   │   │   ├── home/        # 首页 (Hero Section)
│   │   │   ├── editor/      # 修图核心页 (你的重点！)
│   │   │   │   ├── editor_screen.dart
│   │   │   │   ├── layers/  # 涂抹层、图片层
│   │   │   │   └── logic/   # 修图页面的特定逻辑
│   │   │   ├── community/   # 社区瀑布流
│   │   │   └── profile/
│   │   └── navigation/      # 底部导航栏逻辑
│   └── main.dart            # App 入口
├── pubspec.yaml
└── analysis_options.yaml
```

# 启动项目

请按照以下顺序配置环境。

> 我们前后端目前还没进行连接，因为后端现在还啥都没写呢

1. ### 前置要求 (Prerequisites)

确保你的开发环境已安装：

- **Git**: 用于代码版本控制。
- **Python 3.10+**: 后端运行环境。
- **Flutter SDK**: (版本 3.x+) 且已配置环境变量。
- **VS Code**: 推荐 IDE，配合 Flutter 和 Python 插件。
- **(Windows 用户)**: 请确保已开启“开发者模式”以支持 Flutter 插件编译。

1. ### 初始化后端 (Backend)

后端负责处理业务逻辑及与 AI 服务的通信。必须**确保你的 ComfyUI 已经先在本地启动（默认 8188 端口）**。

打开终端，进入 `backend` 目录：

```Bash
cd backend
```

#### 2.1 创建并激活虚拟环境

- **Windows:**

```Bash
python -m venv venv
.\venv\Scripts\activate
```

- **Mac / Linux:**

```Bash
python3 -m venv venv
source venv/bin/activate
```

#### 2.2 安装依赖及配置

```Bash
pip install -r requirements.txt
```
> **注意**：你需要去配置好 `COMFYUI_OUTPUT_DIR` 和 `COMFYUI_INPUT_DIR` 二个环境变量让 FastAPI 控制文件搬运。默认代码 (compiler) 中是写死了 `D:\AI\ComfyUI_windows_portable\ComfyUI\`，请自行在代码或系统中修改为你机器上的路径。

#### 2.3 启动后端服务

```Bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
- 服务启动后，请打开浏览器访问：`http://127.0.0.1:8000/docs` 查看 Swagger 接口。

#### 2.4 Phase 2 本地管线连通测试 (纯异步 DAG) 
1. 确保你的 ComfyUI `input` 目录中有一张图片，比如叫 `woman-8463055_1280.jpg`。
2. 在 Swagger 页面 `http://127.0.0.1:8000/docs` 中，找到 `GET /run_pipeline` 接口。
3. 输入图片名称和要处理的 Prompt，点击 Execute 即可验证 A1->A2 本地异步 DAG 编排引擎与拓扑变量绑定 ($step_1.mask_result) 的闭环能力。
4. (可选) 对于前端调试，也可以使用 WebSocket 客户端连接 `ws://127.0.0.1:8000/ws/editor/test` 并发送 `{"action": "generate"}`，测试纯无阻塞的流式进度推流。

1. ### 初始化前端 (Frontend)

保持后端终端运行，**新开一个终端窗口**，进入 `frontend` 目录：

```Bash
cd frontend
```

#### 3.1 安装 Flutter 依赖

拉取 `pubspec.yaml` 中定义的所有包：

```Bash
flutter pub get
```

#### 3.2 配置 API 地址 (关键！)

由于开发环境不同（真机 vs 模拟器），你需要检查 API 地址配置。 打开 `lib/core/constants/api_constants.dart`，根据你的运行方式修改 `baseUrl`：

```Dart
class ApiConstants {
  // 选项 A: Chrome 浏览器 / iOS 模拟器static const String baseUrl = 'http://127.0.0.1:8000';

  // 选项 B: Android 模拟器 (10.0.2.2 映射宿主电脑)// static const String baseUrl = 'http://10.0.2.2:8000';// 选项 C: 真机调试 (请确保手机和电脑在同一 WiFi)// static const String baseUrl = 'http://192.168.x.x:8000';
}
```

#### 3.3 运行 App

```Bash
flutter run
```

推荐优先选择 **Chrome** 或 **Windows** 进行快速 UI 调试。

