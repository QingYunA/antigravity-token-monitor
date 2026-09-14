# Antigravity Token Monitor - Agent Guidelines

轻量级本地大语言模型 Token 消耗与官方配额监控面板。

## 常用指令与自动化检查

- **启动服务**: `python3 server.py --port 8765` (Web 地址: `http://127.0.0.1:8765`)
- **运行全量测试**: `python3 run_tests.py` 或 `python3 -m unittest discover -s . -p "test_*.py"`
- **macOS DMG 打包**: `./macos/build.sh dmg` (在仓库根目录生成 `Antigravity-Monitor-macOS-Universal.dmg`)
- **前端语法校验**: `node -e "const html = fs.readFileSync('static/index.html', 'utf8'); [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].forEach(m => new Function(m[1]));"`

## 核心架构与文件索引

- `server.py`: Python 标准库 HTTP 服务（无额外重型框架依赖），负责 API 路由、SSE 推送、汇率换算与静态文件托管。
- `ls_client.py`: 本地 Antigravity Language Server 进程探测与实时配额 RPC 客户端。
- `telemetry_parser.py`: 检索与解析 Antigravity 状态数据库、会话历史与 Token 消耗流水。
- `static/index.html`: 单文件现代化 Web 监控页面（纯原生 HTML/CSS/SVG，零外部 CDN 依赖，支持明暗主题与中英双语）。
- `macos/build.sh`: macOS 应用打包脚本，支持独立 `.app` 与原生 `hdiutil` DMG 制作。

## 前端工程与图表设计规范 (遵循 `/agent-html`)

1. **图表四段式契约**：
   - ① 结论式标题与分段切换器 (`[ 走势图 | 柱状图 ]`)
   - ② 副标题单位契约 (`1 tick = 1 天 · 虚线导轨 = 整数刻度 · 标注峰值与日均`)
   - ③ 极简轻度家具图体与发丝交互 (`1px` 虚线准星与轻量 Tooltip)
   - ④ 底部编码语义说明行 (Footnote)

2. **SVG 1:1 动态像素规范 (禁止非等比拉伸)**：
   - 必须通过 `container.clientWidth` 动态测量父容器真实物理像素，设置 `viewBox="0 0 ${width} ${height}"`。
   - **严禁使用 `preserveAspectRatio="none"`**，避免正圆畸变为椭圆、等宽字体横向拉扯发虚。
   - 配合防抖的 `ResizeObserver` 实现窗口缩放时平滑无损重绘。

3. **主题变量完备性**：
   - 新增语义色值必须在 `:root` 与 `[data-theme="dark"]` 同时声明（如 `--badge-bg`, `--badge-fg`, `--primary`, `--chart-indigo`），杜绝回退到浏览器默认纯黑。
