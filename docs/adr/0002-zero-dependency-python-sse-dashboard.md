# 0002: 采用零依赖 Python 与 SSE 实时热推送构建仪表盘

## 上下文
在确定了本地 Web 仪表盘产品形态后，需要选定技术运行时与实时同步机制：
1. 前后端技术栈选择：Node.js/React 生态 vs Python 原生生态。
2. 数据同步机制：前端定时轮询 (Polling) vs 后端文件监听配合 Server-Sent Events (SSE)。

## 决策
我们决定**采用零第三方依赖的 Python 3 标准库（`http.server` + 原生 Protobuf Varint 解析）构建本地 Web/API 服务，并通过原生 SSE 单向长连接向浏览器实时推送 Antigravity 状态变更**。前端采用单文件组件化 HTML/CSS/SVG 与原生现代 Canvas/Chart 渲染。

## 理由与权衡
- **极致便携与零环境摩擦**：macOS 自带 Python 3，用户无需执行 `npm install` 下载数百兆依赖包，也没有 node 兼容性或端口冲突顾虑，开箱即用。
- **低功耗与毫秒级延迟**：通过后台线程监控 `~/.gemini/antigravity/conversations/*.db` 的修改时间戳，仅在 Antigravity 写入新对话步骤时触发轻量解析并推流，CPU 占用趋近于 0%，同时保证在浏览器中实时可见 Token 脉冲跳动。
