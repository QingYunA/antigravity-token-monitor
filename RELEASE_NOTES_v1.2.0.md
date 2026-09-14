## Antigravity Token Monitor v1.2.0

专为 Google DeepMind Antigravity 打造的本地实时 Token 消耗与官方配额监控工具。首个正式公开发布版本。

### 🌟 核心特性 / What's New

1. **原生 macOS 状态栏微应用 (Native Menu Bar Card)**
   - 纯 AppKit / Objective-C 原生构建，二进制体积仅 200KB，内存常驻约 15MB。
   - 打包为通用架构（Universal Binary），原生支持 Apple Silicon (M1/M2/M3/M4) 与 Intel 架构 Mac。
   - 悬浮引力核（Quantum Core & Levitation Arc）矢量图标，Retina 高清自适应反色。

2. **Usage 优先展示与缓存命中统计 (Usage-First Metrics)**
   - 优先突出展示近 7 天与当天真实 Token 消耗量。
   - 实时计算 Prompt 缓存命中率与节省费用，直观衡量上下文缓存效益。

3. **官方配额精准倒计时与预警 (Official Quotas & Reset Countdown)**
   - 本地直连 Language Server 进程，毫秒级读取 Gemini 5 小时与每周限额。
   - 实时精准显示倒计时，限额低于 10% 自动变红并触发系统级通知。

4. **中英文无缝双语支持 (Bilingual i18n)**
   - macOS 状态栏菜单支持一键切换 `[ 中文 ↔ English ]`，无需重启，即时生效。
   - Web 实时仪表盘顶栏支持双语切换，状态自动持久化。

5. **现代响应式 Web 仪表盘 (Interactive Web Dashboard)**
   - 纯原生单文件实现，零 npm、零 CDN 依赖，断网完全可用。
   - 支持浅色模式与高级暗黑科技风自由切换。
   - 支持今天、近 7 天、近 30 天与全周期聚合分析与单步脉冲详情探查。

6. **零网络侵入与本地数据隐私 (100% Local & Private)**
   - 仅读取本机 SQLite 与本地进程，绝不上传任何代码、会话或凭证。

---

### 📦 安装与下载 / Downloads

- **macOS Universal Binary**: 下载下方附件中的 `Antigravity-Monitor-macOS-Universal.zip`，解压后双击即可运行。
- **源码运行**:
  ```bash
  git clone https://github.com/QingYunA/antigravity-token-monitor.git
  cd antigravity-token-monitor
  ./macos/build.sh run
  ```
