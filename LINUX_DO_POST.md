# 【开源】写了个 Antigravity 本地 Token 与官方配额监控小工具（Mac 菜单栏 / Web 面板 / 纯本地零依赖）

各位佬友们好！

最近这段时间一直泡在 Google 的 Antigravity（就是 DeepMind 那个编程 Agent）里写代码，确实很顺手。但用得多了，有个问题特别折磨人：**官方配额完全是个黑盒**。

经常是代码写到兴头上，突然弹个 `ResourceExhausted` 或者 429 报错，直接歇菜。而且官方界面里只给一个粗糙的百分比，很多具体的事情根本查不到：
- 这 5 小时的滚动配额到底还剩几分钟重置？
- 今天到底用了多少 Token？Prompt 缓存（Prompt Cache）实际帮我省了多少？
- 刚才让 Agent 跑完一个大重构，每一步的思考过程（Thinking Token）到底耗了多少？折算成 API 账单到底值多少钱？

翻了一圈现有的工具，要么得装一套 Docker + PostgreSQL，几十上百兆的体积；要么得把本地日志上传到第三方的服务器上。在公司或者私有项目里敲代码，谁敢把会话数据随便往外传？

实在受不了，索性自己动手写了一个：**Antigravity Token Monitor**。

- **GitHub 仓库**：[https://github.com/QingYunA/antigravity-token-monitor](https://github.com/QingYunA/antigravity-token-monitor)
- **下载地址 (Releases)**：[https://github.com/QingYunA/antigravity-token-monitor/releases/latest](https://github.com/QingYunA/antigravity-token-monitor/releases/latest)

开源协议采用 MIT，完全免费，数据 100% 留在你自己的电脑里。

---

## 📸 界面长什么样？（图文展示）

### 1. Mac 菜单栏常驻小卡片

平时写代码时，最不希望为了看一眼用量还得专门开个浏览器标签页。所以我用原生的 Objective-C / AppKit 搓了个 Mac 状态栏小程序：

![Mac 菜单栏卡片预览](https://raw.githubusercontent.com/QingYunA/antigravity-token-monitor/main/assets/menu_bar_card.png)

- **体积与资源**：安装包只有几百 KB，常驻内存大概 15MB，基本感觉不到它的存在。
- **配额倒计时**：实时显示 Gemini 5 小时滚动配额和每周配额的剩余比例，精确到分钟的重置倒计时（额度低于 10% 会自动标红报警）。
- **用量速览**：随时看今天和近 7 天的 Token 消耗量、折算费用，以及缓存命中的节省比例。
- **一键操作**：点一下就能呼出完整的 Web 面板，或者检查更新。

---

### 2. 轻量 Web 监控面板

如果你想复盘最近 30 天的历史趋势，或者排查某一次复杂任务的消耗细节，点开 Web 面板就能看到：

![Web 监控面板预览](https://raw.githubusercontent.com/QingYunA/antigravity-token-monitor/main/assets/web_dashboard.png)

- **纯原生手写**：零 npm 依赖，零外部 CDN。所有图表都是原生 SVG 1:1 动态像素计算绘制的，没有用臃肿的第三方图表库，断网也能秒开。
- **走势图 / 柱状图随意切换**：带悬浮发丝十字准星，能看每天的峰值、均值以及缓存命中情况。
- **思考链（Thinking）消耗探查**：可以看到每个模型在思考阶段到底吃了多少 Token。
- **单步脉冲明细**：拆解每次跟 Agent 对话的输入、缓存命中、正文输出和预估成本。
- **细节打磨**：支持浅色和暗黑模式，支持中英文即时切换，汇率支持按实时美元或人民币折算。

---

### 3. 终端命令行（CLI）

如果你是纯终端党（比如常年开着 tmux），不想开菜单栏也不想开浏览器，直接敲一行命令：

```bash
python3 cli.py
```

终端里立刻输出一张简洁的纯文本报表：

```text
============================================================
              ANTIGRAVITY TOKEN MONITOR REPORT              
============================================================
📅 统计时间范围: 2026-03-08 至 2026-03-14 (近 7 天)
------------------------------------------------------------
📊 核心消耗指标:
   • 累计消耗:       2.28B Tokens (折算价值: $70.46)
   • 缓存命中:       2.15B Tokens (缓存节省: $160.95)
   • 缓存利用率:     94.0%
------------------------------------------------------------
⏱️ 官方配额状态:
   • Gemini 5h 限额: 63.1% 剩余 (重置倒计时: 4h 08m)
   • 每周限额:       93.9% 剩余 (重置倒计时: 6d 23h)
============================================================
```

---

## 🔒 隐私与安全性（为什么敢放心用？）

这可能是很多佬友最关心的点：

1. **零数据外传**：代码全部开源，你可以随便审查代码。后端只读本机 `~/.gemini/antigravity/` 下的文件，不会向任何外部服务器发送你的代码、Prompt、Token 密钥或聊天记录。
2. **零 pip 依赖**：后端服务纯用 Python 3 自带的标准库（`http.server`、`sqlite3`、`urllib` 等）编写。不需要 `pip install` 任何第三方包，杜绝依赖投毒风险。
3. **本地 RPC 直连**：配额数据是通过直接探测本机正在运行的 `antigravity-language-server` 进程端口与本地 CSRF Token 获取的，跟官方编辑器拿数据的方式一模一样，不用你手动去抓包配 Cookie。

---

## 🚀 怎么安装使用？

### 方式 A：macOS 用户直接下 DMG（最简单）

1. 前往 GitHub Releases：[下载 DMG 镜像文件](https://github.com/QingYunA/antigravity-token-monitor/releases/latest)
2. 双击打开 `Antigravity-Monitor-macOS-Universal.dmg`，把图标拖进 `Applications`。
3. 打开后，顶部菜单栏就会常驻图标了。
   *(支持 M1/M2/M3/M4 系列芯片以及 Intel 芯片 Mac，均为原生运行)*

### 方式 B：源码运行 / 纯 Python 跑

如果你更喜欢自己把控代码，或者在非 Mac 系统上只想跑 Web 面板：

```bash
# 1. 克隆代码
git clone https://github.com/QingYunA/antigravity-token-monitor.git
cd antigravity-token-monitor

# 2. 启动 Web 监控服务（直接用系统自带 python3 即可，不需要安装依赖）
python3 server.py

# 3. 浏览器打开
open http://127.0.0.1:8765
```

如果要自己编译 Mac 原生菜单栏 App，根目录下执行 `./macos/build.sh run` 就会自动编译并启动。

---

## 💬 闲聊与交流

这个小工具完全是出于自己平时敲代码的痛点随手折腾出来的。

目前在自己机子上跑了一阵子，体感上确实踏实不少，写代码时瞄一眼菜单栏就知道大概还能高强度狂飙多久。

如果佬友们在用 Antigravity 时也有类似需求，或者在使用中遇到了 Bug、有什么新功能想法（比如：支持自定义额度报警阈值、支持跨设备局域网查看等），欢迎随时在评论区留言或者去 GitHub 提 Issue！

觉得好用的话，顺手在 GitHub 点个 ⭐️ Star 支持一下，感谢各位佬友！

👉 **项目地址**：[https://github.com/QingYunA/antigravity-token-monitor](https://github.com/QingYunA/antigravity-token-monitor)
