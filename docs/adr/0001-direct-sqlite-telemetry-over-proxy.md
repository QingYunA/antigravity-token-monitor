# 0001: 采用本地 SQLite 遥测解析而非网络代理拦截

## 上下文
为了监控 Antigravity 的具体 Token 消耗（输入、输出、思考、缓存），最初考虑的技术路线包括：
1. 启动本地 HTTP 反向代理拦截与 Google 后端的所有 API 交互（类似 `Antigravity Tools` 的做法）。
2. 在本地通过轮询/监听直接读取 Antigravity 自身的 SQLite 数据库（`conversations/<id>.db` 的 `gen_metadata` 表）。

## 决策
我们决定**采用直接监听与解析本地 SQLite 遥测数据（Direct SQLite Telemetry Parsing）作为核心数据源**，并构建本地轻量 Web 仪表盘，放弃网络代理拦截路线。

## 理由与权衡
- **数据精度一致**：逆向分析证实 Antigravity 在 `gen_metadata` 中已经以 Protobuf 结构完整且精确记录了单步与全量 Prompt、Cached、Output、Thinking 真实数值，与代理拦截获得的数据完全一致。
- **零网络侵入与零安全风险**：直接读本地数据库不需要修改 macOS 系统代理、不需要安装自签名根证书，也不会因为代理服务崩溃而阻断 Agent 正常编码任务。
- **极简部署**：用户无需配置端口转发或担心代理劫持，开箱即用。
