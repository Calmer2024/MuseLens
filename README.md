项目初始化

# 项目结构

后端目录结构

```Plain
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # 入口文件：启动 FastAPI，挂载路由
│   ├── core/                # 核心配置
│   │   ├── config.py        # 读取 .env 配置（如数据库URL，ComfyUI地址）
│   │   └── security.py      # JWT 认证逻辑（如果有登录功能）
│   ├── models/              # 数据库模型 (ORM)
│   │   ├── user.py
│   │   └── recipe.py        # 存储用户的“配方”
│   ├── schemas/             # Pydantic 数据模型 (用于请求/响应验证)
│   │   ├── chat.py          # 定义聊天消息、Widget指令的结构
│   │   └── generation.py    # 定义生图参数结构
│   ├── api/                 # API 路由层
│   │   └── v1/
│   │       ├── endpoints/
│   │       │   ├── auth.py
│   │       │   ├── editor.py    # 处理图片上传、修图指令
│   │       │   └── recipes.py   # 社区配方接口
│   │       └── websocket.py     # 专门处理 WebSocket 连接 (进度条、Chat)
│   └── services/            # 业务逻辑层 (最重要！)
│       ├── llm_service.py       # 调用 OpenAI/Claude 进行 Prompt 扩写
│       └── comfy_service.py     # 封装与 ComfyUI 的通信、队列管理、WebSocket监听
├── .env                     # 环境变量 (不要上传到 Git)
├── .gitignore
└── requirements.txt
```

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

后端负责处理业务逻辑及与 AI 服务的通信。

打开终端，进入 `backend` 目录：

```Bash
cd backend
```

#### 2.1 创建并激活虚拟环境

这是为了隔离依赖，防止污染全局 Python 环境。

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

*(注意：激活成功后，终端命令行前面会出现* *`(venv)`* *字样)*

#### 2.2 安装依赖

```Bash
pip install -r requirements.txt
```

#### 2.3 启动后端服务

```Bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- 看到 `Application startup complete` 即表示启动成功。
- 默认运行在: `http://127.0.0.1:8000`

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

