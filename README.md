<div align="center">

<img src="./assets/logo.svg" width="68" height="68" alt="Antigravity Token Monitor Logo">

# Antigravity Token Monitor

<p><strong>专为 Google DeepMind Antigravity 打造的本地实时 Token 消耗与官方配额监控工具。</strong><br>
包含原生 macOS 状态栏卡片、轻量 Web 实时大盘与终端 CLI，零外部依赖、零网络侵入。</p>

<p>
  <a href="https://github.com/QingYunA/antigravity-token-monitor/releases"><img src="https://img.shields.io/github/v/release/QingYunA/antigravity-token-monitor?style=flat&color=38bdf8" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20(Universal)%20%7C%20Web-lightgrey" alt="Platforms">
  <img src="https://img.shields.io/badge/dependencies-0%20pip%20%7C%200%20npm-emerald" alt="Zero Dependencies">
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License"></a>
</p>

<p>
  <a href="#核心特性">功能特性</a> ·
  <a href="#快速上手">快速上手</a> ·
  <a href="#数据采集原理">数据原理</a> ·
  <a href="#一键更新">升级维护</a> ·
  <a href="./README_EN.md">English Documentation</a>
</p>

</div>

---

<!-- 首屏直观展示：真实 macOS 状态栏下拉卡片 -->
<div align="center">
  <img src="./assets/menu_bar_card.png" width="380" alt="Antigravity Monitor macOS Menu Bar Card">
  <p><em>原生 macOS 状态栏下拉卡片：实时展示近 7 天与当天 Token 消耗、缓存命中率、5h/周配额精准倒计时。</em></p>
</div>

---

## 为什么做这个工具？

在使用 Google DeepMind Antigravity 进行深度编码时，Agent 会在后台频繁调用 Gemini 产生大量 Token 消耗。

但在日常开发中，官方并没有提供一个常驻的桌面微件：
1. **配额黑盒**：你只有在遇到 `ResourceExhausted` 报错时，才意识到 5 小时限额或周配额已耗尽。
2. **消耗无感**：不知道一次复杂的 Prompt 或子任务到底消耗了多少 Token，缓存节省了多少。
3. **隐私顾虑**：不想为了看用量而把本地代码或会话同步到不可控的第三方云端服务。

**Antigravity Token Monitor** 为此而生。它直接从本地读取 SQLite 记录与 Language Server 进程，无需配置任何 API Key，不产生任何公网网络请求，即开即用。

---

## 核心特性

- **原生 macOS 状态栏微应用：** 采用 Objective-C 与 AppKit 纯原生开发。二进制体积仅 200KB，内存常驻约 15MB，免安装即可双击运行。
- **Usage 优先的直观排版：** 状态栏下拉卡片优先突出“近 7 天 Token 消耗”与“今日消耗”，并清晰展示缓存命中节省量，辅助折算官方费用。
- **官方配额精准倒计时：** 本地直连 Language Server 进程，实时获取 Gemini 5 小时与每周限额的剩余百分比与精确重置时间戳。低于 10% 时自动标红并触发 macOS 系统横幅预警。
- **双语无缝切换 (i18n)：** macOS 状态栏应用与 Web 仪表盘均支持中英文一键切换，配置自动持久化至系统与浏览器本地。
- **现代响应式 Web 大盘：** 纯原生 HTML/CSS/JS 单文件实现，零 npm 依赖，零断网白屏风险。支持浅色与暗色模式无缝切换，提供今天、近 7 天、近 30 天与全周期聚合分析。
- **单步脉冲深度探查：** 完整还原每一步交互的输入、思维链（Thinking）、输出与缓存命中的详细 Token 占比。
- **零网络侵入与数据隐私：** 仅读取本机 `~/.gemini/antigravity` 目录下的 SQLite 数据库与本地 IPC，绝不向任何外部服务器发送数据，不收集任何代码或 Prompt 内容。

---

## 快速上手

### 选项 A：使用预编译 macOS 原生应用（推荐）

1. 在 [Releases 页面](https://github.com/QingYunA/antigravity-token-monitor/releases/latest) 下载 `Antigravity-Monitor-macOS-Universal.zip`。
2. 解压后将 `Antigravity Monitor.app` 拖入 `/Applications`（或任意目录）。
3. 双击打开，Mac 顶部状态栏右上角即可常驻引力核微标。

> **提示**：应用已打包为 Universal Binary，原生支持 Apple Silicon（M1/M2/M3/M4）与 Intel 架构 Mac。

---

### 选项 B：从源码极速编译运行

克隆代码并在本地一键构建：

```bash
git clone https://github.com/QingYunA/antigravity-token-monitor.git
cd antigravity-token-monitor

# 编译并立即在状态栏启动
./macos/build.sh run

# 或直接安装到系统的“应用程序”文件夹
./macos/build.sh install
```

---

### 选项 C：启动 Web 实时大盘

如果需要查看时序折线图、30 天趋势或历史会话明细：

```bash
python3 server.py
```

在浏览器打开：[http://127.0.0.1:8765](http://127.0.0.1:8765)

- 支持浅色模式 / 高级暗黑模式一键切换。
- 顶栏支持 `[ 中文 | EN ]` 语言切换。
- 支持今天、近 7 天、最近 30 天聚合筛选。

---

### 选项 D：终端 CLI 命令行速查

在终端敲代码时随手查看：

```bash
python3 cli.py
```

输出示例：
```text
============================================================
              ANTIGRAVITY TOKEN MONITOR REPORT              
============================================================
📅 统计时间范围: 2026-03-08 至 2026-03-14 (近 7 天)
------------------------------------------------------------
📊 核心消耗指标:
   • 累计消耗:       2.15B Tokens (折算价值: $66.40)
   • 缓存命中:       1.83B Tokens (缓存节省: $8.95)
   • 缓存利用率:     85.1%
------------------------------------------------------------
⏱️ 官方配额状态:
   • Gemini 5h 限额: 65.0% 剩余 (重置倒计时: 2h 15m)
   • 每周限额:       82.0% 剩余 (重置倒计时: 3d 18h)
============================================================
```

---

## 数据采集原理

本工具完全依赖 Antigravity 在本地产生的运行数据，无侵入性：

| 数据类型 | 采集机制 | 说明 |
| :--- | :--- | :--- |
| **实时配额与倒计时** | 本地 Connect-RPC | 自动扫描本机正在运行的 `antigravity-language-server` 进程端口与 CSRF 凭证，通过标准 RPC 接口 `RetrieveUserQuotaSummary` 获取毫秒级精准的配额百分比与重置时间戳。 |
| **真实 Token 消耗与成本** | 本地 SQLite 解析 | 读取 `~/.gemini/antigravity/conversations/*.db`，安全解码单步交互中的 `gen_metadata` Protobuf 负载，提取精准的 Prompt、Output、Thinking 与 Cache Token 数量。 |
| **零外部依赖** | 纯 Python 标准库 | 服务端无需安装任何第三方库（仅使用 `http.server`, `sqlite3`, `urllib`, `threading`）。 |

---

## 一键更新

项目内置了自动版本比对与平滑更新机制：

1. **状态栏检查**：在 Mac 状态栏菜单中点击 `检查更新...` 即可直接获取最新版本说明。
2. **Web 仪表盘通知**：检测到新版本时，Web 页面右上角会自动激活更新徽标。
3. **终端平滑升级**：在项目目录下运行一行命令即可自动拉取最新代码并热启：
   ```bash
   ./update.sh
   ```

---

## 运行自动化测试

```bash
python3 -m unittest discover -p "test_*.py"
```

---

## 开源协议

本项目采用 [MIT License](./LICENSE) 开源。
