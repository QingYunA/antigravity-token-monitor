# Domain Context: Antigravity Token Monitor

本文档记录 Antigravity Token 监控系统的领域概念与核心术语定义。

## 术语表 (Glossary)

### 1. 监控形态与核心组件
- **Language Server RPC (LS RPC)**：Antigravity 核心语言服务进程（`language_server`）在本地开放的高性能 Connect-RPC 接口（运行于 `127.0.0.1:<port>`，经 `--csrf_token` 鉴权）。其暴露的 `GetUserStatus` 和 `RetrieveUserQuotaSummary` 等方法能够直接、无额外网络开销地返回各模型的 5 小时/周配额、重置时间戳及上下文窗口状态。
- **Exact Token Telemetry (`gen_metadata`)**: Antigravity 在本地 `conversations/<id>.db` 的 `gen_metadata` 表中，以 Protobuf 结构严格记录了每一个生成步骤的个位级精确数值：
  - `field_4.2`: **Prompt Tokens (本次输入)**
  - `field_4.5`: **Cached Tokens (上下文缓存命中)**
  - `field_4.3`: **Total Output Tokens (总输出)**
  - `field_4.9`: **Thinking Tokens (深度思考消耗)**
  - `field_4.10`: **Content Tokens (正文回复消耗)**
  - `field_19`: **Model ID (当前调用的模型标识)**
- **Token Usage Metric**: 对大语言模型单次或多次交互消耗的量化指标，包含 Prompt Tokens（输入）、Candidate/Completion Tokens（输出）、Thinking Tokens（思考链消耗）与 Cached Tokens（上下文缓存命中）。
- **Proxy Interceptor**: 通过本地 HTTP/HTTPS 代理服务（如 Antigravity Tools 内部 Proxy 或自建代理层）透明截获 Antigravity 与后端模型接口（`generativelanguage.googleapis.com`）的 API 流量，直接从响应 Payload 或 SSE 块中提取官方返回的精确 Usage Metadata。
- **CLI StatusLine Stream**: Antigravity CLI 官方内置的实时状态流机制，通过在 `settings.json` 中配置 `statusLine` 命令，自动向外部脚本的 `stdin` 推送包含 `total_input_tokens`、`total_output_tokens`、`context_window_size` 的结构化 JSON。
- **Lifecycle Hook**: Antigravity 原生支持的声明式生命周期钩子（配置于 `hooks.json`），在 `PreInvocation`、`PostInvocation`、`PreToolUse`、`PostToolUse` 或 `Stop` 事件点执行，并可通过 `injectSteps` 向 Agent 注入瞬时提示（`ephemeralMessage`）。

### 2. 现有宿主环境实测资产 (Verified Assets)
- **本地 Language Server 进程**：当前正运行在您本地（端口 `54056`，CSRF Token 已捕获），实测通过 RPC 可以毫秒级获取 Gemini、Claude 等模型的实时剩余配额比例与重置倒计时。
- **Antigravity Tools (`com.lbjlaq.antigravity-tools`)**: 本机已安装并运行的本地管理套件（PID 71003, 监听端口 8045），底层基于 Tauri/Rust，内建了 SQLite 数据库（`token_stats.db`）与统计接口（如 `/stats/token/summary`），具备反向代理与 Token 计数底座。

## 架构决策与共识 (Settled Decisions)
- **产品形态**：本地轻量 Web 可视化仪表盘（Local Web Dashboard），提供跨会话、按时间、按模型的动态图表与明细数据。
- **数据源设计**：直读 Antigravity 本地 SQLite 遥测记录（参见 [ADR 0001](./docs/adr/0001-direct-sqlite-telemetry-over-proxy.md)），配合本地 Language Server Connect-RPC 补充宏观配额信息。
- **技术运行时**：零外部依赖 Python 3 原生服务 + macOS 双击即开脚本（参见 [ADR 0002](./docs/adr/0002-zero-dependency-python-sse-dashboard.md)）。
- **指标粒度**：完整拆解透视（Prompt Tokens、Cached Tokens、Thinking Tokens、Content Tokens、Total Tokens，以及 Gemini/Claude 阶梯单价对应的 USD/CNY 金额换算）。
- **实时同步机制**：后端文件感知 + SSE (Server-Sent Events) 浏览器毫秒级免刷新热推送。
