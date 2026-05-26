#!/bin/bash

echo "========================================="
echo "Dart SDK 配置脚本"
echo "========================================="
echo ""

FLUTTER_SDK="/opt/homebrew/share/flutter"
DART_SDK="$FLUTTER_SDK/bin/cache/dart-sdk"

echo "1. 检查 Flutter SDK..."
if [ -d "$FLUTTER_SDK" ]; then
    echo "   ✓ Flutter SDK: $FLUTTER_SDK"
else
    echo "   ✗ Flutter SDK 不存在: $FLUTTER_SDK"
    exit 1
fi

echo ""
echo "2. 检查 Dart SDK..."
if [ -d "$DART_SDK" ]; then
    echo "   ✓ Dart SDK: $DART_SDK"
    DART_VERSION=$("$DART_SDK/bin/dart" --version 2>/dev/null | head -1)
    echo "   ✓ Dart 版本: $DART_VERSION"
else
    echo "   ✗ Dart SDK 不存在，尝试下载..."
    flutter precache --force
fi

echo ""
echo "3. 验证配置文件..."
if [ -f ".idea/libraries/Dart_SDK.xml" ]; then
    echo "   ✓ Dart SDK 配置文件存在"
    if grep -q "$DART_SDK" .idea/libraries/Dart_SDK.xml; then
        echo "   ✓ 配置文件路径正确"
    else
        echo "   ⚠ 配置文件路径可能需要更新"
    fi
else
    echo "   ✗ Dart SDK 配置文件不存在"
fi

echo ""
echo "========================================="
echo "配置完成！"
echo ""
echo "接下来请在 Android Studio 中："
echo "1. File -> Settings (macOS: Android Studio -> Settings)"
echo "2. Languages & Frameworks -> Flutter"
echo "3. Flutter SDK path: $FLUTTER_SDK"
echo "4. 点击 'Apply' 和 'OK'"
echo "5. 重启 Android Studio"
echo "========================================="

