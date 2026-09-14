#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Antigravity Monitor"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
TARGET_BIN="${MACOS_DIR}/AntigravityMonitor"

echo "🔨 正在编译 Antigravity 原生 macOS 顶部菜单栏应用..."

# Ensure directories exist
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compile Objective-C source using clang
clang -O2 \
  -fobjc-arc \
  -target arm64-apple-macos11.0 \
  -framework Cocoa \
  main.m \
  -o "$TARGET_BIN"

# Copy Info.plist
cp Info.plist "${CONTENTS_DIR}/"

# Set executable permissions
chmod +x "$TARGET_BIN"

echo "✅ 编译成功！"
echo "📦 应用产物: ${SCRIPT_DIR}/${APP_BUNDLE}"
echo "📊 二进制体积: $(du -h "$TARGET_BIN" | cut -f1)"

# Handle command line arguments
if [ "$1" == "run" ]; then
    echo "🚀 正在启动 ${APP_NAME}..."
    killall "AntigravityMonitor" 2>/dev/null || true
    open "${APP_BUNDLE}"
elif [ "$1" == "install" ]; then
    echo "📂 正在安装到 /Applications..."
    killall "AntigravityMonitor" 2>/dev/null || true
    rm -rf "/Applications/${APP_BUNDLE}"
    cp -R "${APP_BUNDLE}" "/Applications/"
    echo "🎉 安装完成！你可以随时在 Launchpad 或 Spotlight (聚焦搜索) 中打开 '${APP_NAME}'。"
else
    echo ""
    echo "💡 提示:"
    echo "  - 直接启动: ./build.sh run  (或双击打开 '${APP_BUNDLE}')"
    echo "  - 安装到系统: ./build.sh install"
fi
