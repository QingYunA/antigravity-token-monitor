#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔄 正在检查 Antigravity Monitor 更新与环境..."

# 1. Pull Git changes if upstream remote is set
if git remote get-url origin >/dev/null 2>&1; then
    echo "📥 正在拉取远程最新代码..."
    git pull --rebase
else
    echo "ℹ️ 本地独立环境运行，准备增量构建与热重启..."
fi

# 2. Recompile macOS native app if clang exists
if [ -d "macos" ] && command -v clang >/dev/null 2>&1; then
    echo "🔨 重新编译 macOS 原生状态栏应用..."
    ./macos/build.sh
fi

# 3. Restart server and macOS application
echo "🚀 正在平滑重启服务..."
killall "AntigravityMonitor" 2>/dev/null || true
pkill -f "python3 server.py" 2>/dev/null || true
sleep 1

nohup python3 server.py > /dev/null 2>&1 &
echo "✅ 本地 Web 服务已在后台平滑启动 (端口: 8765)"

if [ -d "macos/Antigravity Monitor.app" ]; then
    open "macos/Antigravity Monitor.app"
    echo "✅ Antigravity Monitor 状态栏应用已唤醒运行"
fi

echo "🎉 升级完成！当前版本 v1.2.0 已就绪。"
