#!/bin/bash

echo "========================================="
echo "配置 ADB 命令到 PATH"
echo "========================================="
echo ""

ANDROID_SDK="/Users/mac2/Library/Android/sdk"
ZSHRC="$HOME/.zshrc"

if [ ! -d "$ANDROID_SDK" ]; then
    echo "✗ Android SDK 目录不存在: $ANDROID_SDK"
    exit 1
fi

echo "1. 检查 Android SDK..."
echo "   ✓ Android SDK: $ANDROID_SDK"

echo ""
echo "2. 检查 ADB 可执行文件..."
if [ -f "$ANDROID_SDK/platform-tools/adb" ]; then
    echo "   ✓ ADB 存在: $ANDROID_SDK/platform-tools/adb"
else
    echo "   ✗ ADB 不存在"
    exit 1
fi

echo ""
echo "3. 检查 ~/.zshrc 配置..."
if grep -q "ANDROID_HOME\|platform-tools" "$ZSHRC" 2>/dev/null; then
    echo "   ⚠ 发现已有 Android 相关配置"
    echo "   现有配置："
    grep -n "ANDROID_HOME\|platform-tools" "$ZSHRC" 2>/dev/null | sed 's/^/     /'
else
    echo "   ✓ 未找到 Android 配置，将添加"
fi

echo ""
echo "4. 添加配置到 ~/.zshrc..."
cat >> "$ZSHRC" << 'EOF'

# Android SDK Configuration
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$ANDROID_HOME/tools/bin
EOF

echo "   ✓ 配置已添加"

echo ""
echo "5. 使配置生效..."
source "$ZSHRC" 2>/dev/null || echo "   ⚠ 请手动运行: source ~/.zshrc"

echo ""
echo "========================================="
echo "配置完成！"
echo ""
echo "现在可以在终端直接使用 'adb' 命令了"
echo ""
echo "验证方法："
echo "  1. 打开新的终端窗口，或运行: source ~/.zshrc"
echo "  2. 运行: adb version"
echo "  3. 运行: adb devices"
echo "========================================="

