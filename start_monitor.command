#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "=================================================="
echo "⚡ 正在启动 Antigravity Token 监控服务..."
echo "=================================================="

# Check if port 8765 is already running
PORT=8765
PID=$(lsof -ti tcp:$PORT)

if [ -n "$PID" ]; then
    echo "⚠️ 端口 $PORT 已有进程 (PID: $PID) 在运行，直接在浏览器中打开..."
else
    echo "🚀 启动本地监控服务 (http://127.0.0.1:$PORT)..."
    python3 server.py &
    SERVER_PID=$!
    sleep 0.8
fi

echo "🌐 打开浏览器..."
open "http://127.0.0.1:$PORT"

echo "=================================================="
echo "监控服务已启动！保持此终端窗口打开即可后台维持监控。"
echo "若要停止服务，按下 Ctrl+C 即可。"
echo "=================================================="

wait $SERVER_PID 2>/dev/null
