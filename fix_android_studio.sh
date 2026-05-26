#!/bin/bash

echo "========================================="
echo "Android Studio Flutter 项目修复脚本"
echo "========================================="
echo ""

# 1. 检查 Flutter 环境
echo "1. 检查 Flutter 环境..."
flutter doctor
echo ""

# 2. 检查设备连接
echo "2. 检查设备连接..."
echo "Flutter 设备:"
flutter devices
echo ""
echo "ADB 设备:"
/Users/mac2/Library/Android/sdk/platform-tools/adb devices
echo ""

# 3. 清理并重新获取依赖
echo "3. 清理并重新获取依赖..."
flutter clean
flutter pub get
echo ""

# 4. Gradle 同步
echo "4. 执行 Gradle 同步..."
cd android
./gradlew --refresh-dependencies --console=plain 2>&1 | tail -5
cd ..
echo ""

echo "========================================="
echo "修复完成！"
echo ""
echo "接下来的步骤："
echo "1. 关闭 Android Studio（如果已打开）"
echo "2. 删除 .idea 文件夹（可选，如果需要完全重置）"
echo "3. 重新打开 Android Studio"
echo "4. 选择 File -> Open，选择项目根目录"
echo "5. 等待项目索引完成"
echo "6. 检查顶部工具栏是否出现设备选择器"
echo ""
echo "如果还是没有设备选择器："
echo "- 确认已安装 Flutter 和 Dart 插件"
echo "- 尝试 View -> Tool Windows -> Flutter"
echo "- 检查 Run -> Edit Configurations 中是否有 main.dart 配置"
echo "========================================="

