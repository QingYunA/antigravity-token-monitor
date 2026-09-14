# Antigravity Token Monitor ⚡

> 全局精准监控 Google Antigravity 的 Token 消耗、缓存利用率、实时配额（5h/周限额）与预估费用的全套监控系统。包含 **macOS 原生顶部菜单栏应用**、**Web 实时大盘**、**终端 CLI** 与 **Slash Command 技能**。

---

## 🌟 核心功能

1. **原生 macOS 顶部菜单栏应用 (`Antigravity Monitor.app`)**：
   - 极简、轻量（~80 KB 原生二进制，内存占用仅 ~12 MB）。
   - 常驻 Mac 顶部状态栏，实时显示 `⚡ 65% · 9.2M`。
   - 点击呼出原生下拉面板：一览 5 小时额度倒计时、周额度、Prompt/Output Token 分布、缓存节省金额。
   - 额度跌破 15% 时自动发送 macOS 系统级预警通知。
   - 后台守护：若服务端未启动，自动在后台静默拉起。

2. **精美暗黑 Web 实时大盘 (`http://127.0.0.1:8765`)**：
   - 实时 SSE 增量推送，无刷新更新。
   - Gemini 5h 与周限额动态环形仪表盘。
   - 历史会话逐步分析器（查看每一步的 Thinking、Prompt、Output、Cache 命中率）。

3. **终端 CLI 工具 (`cli.py`)**：
   - 极速终端数据摘要输出，适合在写代码时随手 `python3 cli.py` 查看。

4. **Slash Command 技能 (`/token-stats`)**：
   - 在 Antigravity 会话中随时键入 `/token-stats` 即可在对话中唤出当前配额与用量表格。

---

## 🚀 快速开始

### 1. 启动 macOS 顶部菜单栏应用

进入 `macos` 目录：
```bash
# 编译并立即启动
./macos/build.sh run

# 或直接安装到系统的“应用程序”目录
./macos/build.sh install
```
启动后，Mac 顶部状态栏右上角将出现 `⚡` 图标。

### 2. 启动 Web 仪表盘

```bash
# 后台启动服务（默认端口 8765）
python3 server.py

# 或双击运行 macOS 便捷启动脚本
./start_monitor.command
```
访问：`http://127.0.0.1:8765`

### 3. 使用命令行查询

```bash
python3 cli.py
```

---

## 🏗️ 架构与数据源

- **实时配额 (Quotas)**：
  - 通过进程发现找到本地 Antigravity Language Server，直接通过 Connect-RPC 查询 `RetrieveUserQuotaSummary`，获取 5 小时与周限额的精确剩余百分比与重置时间戳。
- **历史消耗 (Tokens & Costs)**：
  - 解析 SQLite 数据库 `~/.gemini/antigravity/conversations/<id>.db` 中的 `gen_metadata` Protobuf 字段，提取真实真实的 `prompt_tokens`、`cached_tokens`、`thinking_tokens`、`content_tokens`。
- **零外部第三方依赖**：
  - 后端使用纯 Python 3 标准库（`http.server`、`sqlite3`、`urllib`、`threading`）。
  - macOS 菜单栏应用使用纯原生 Objective-C + AppKit/Cocoa 编译。

---

## 🧪 运行测试套件

```bash
python3 -m unittest discover -p "test_*.py"
```
