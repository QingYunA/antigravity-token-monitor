# 【开源】写了个 Antigravity 的Token统计与 5h 额度监控小工具

佬友们好！

最近这段时间一直猛用 Antigravity 里写代码，我有5个 Gemini Pro的号轮流蹬的爽的时候，还是想知道一下到底花了多少Token，搞了个小工具来监控。

最后用这个工具统计出来4天应该是2.4B，也就是24亿Token🤣

**Antigravity Token Monitor**。

- **GitHub 仓库**：[https://github.com/QingYunA/antigravity-token-monitor](https://github.com/QingYunA/antigravity-token-monitor)
- **下载地址 (Releases)**：[https://github.com/QingYunA/antigravity-token-monitor/releases/latest](https://github.com/QingYunA/antigravity-token-monitor/releases/latest)

开源协议采用 MIT，完全免费，数据 100% 留在你自己的电脑里。

---

## 界面

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

终端输出示例：

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

## 💬 闲聊

这个小工具完全是出于自己平时敲代码的痛点随手折腾出来的。

目前在自己机子上跑了一阵子，体感上确实踏实不少，写代码时瞄一眼菜单栏就知道大概还能高强度狂飙多久。

如果佬友们在用 Antigravity 时也有类似需求，或者在使用中遇到了 Bug、有什么新功能想法（比如：支持自定义额度报警阈值、支持跨设备局域网查看等），欢迎随时在评论区留言或者去 GitHub 提 Issue！

觉得好用的话，顺手在 GitHub 点个 ⭐️ Star 支持一下，感谢各位佬友！

👉 **项目地址**：[https://github.com/QingYunA/antigravity-token-monitor](https://github.com/QingYunA/antigravity-token-monitor)
