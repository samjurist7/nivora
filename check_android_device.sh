#!/bin/bash

echo "========================================="
echo "Android 设备连接完整诊断"
echo "========================================="
echo ""

ANDROID_SDK="/Users/mac2/Library/Android/sdk"
ADB="$ANDROID_SDK/platform-tools/adb"

# 检查 ADB 是否可用
if [ ! -f "$ADB" ]; then
    echo "✗ ADB 不存在: $ADB"
    exit 1
fi

# 如果没有在 PATH 中，使用完整路径
if ! command -v adb &> /dev/null; then
    echo "⚠ ADB 不在 PATH 中，使用完整路径"
    export PATH=$PATH:$ANDROID_SDK/platform-tools
fi

echo "1. 检查 ADB 版本..."
$ADB version 2>/dev/null | head -1 || echo "   ✗ 无法获取 ADB 版本"
echo ""

echo "2. 重启 ADB 服务..."
$ADB kill-server 2>/dev/null
sleep 2
$ADB start-server 2>/dev/null
echo "   ✓ ADB 服务已重启"
echo ""

echo "3. 检查连接的设备（等待 5 秒）..."
sleep 5
DEVICES_OUTPUT=$($ADB devices -l)
echo "$DEVICES_OUTPUT"
echo ""

DEVICE_COUNT=$(echo "$DEVICES_OUTPUT" | grep -v "List of devices" | grep -v "^$" | grep "device" | wc -l | tr -d ' ')

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "✗ 未检测到任何 Android 设备"
    echo ""
    echo "========================================="
    echo "🔧 故障排除步骤"
    echo "========================================="
    echo ""
    echo "【步骤 1】检查 USB 连接"
    echo "  ✓ 确保 USB 数据线已连接"
    echo "  ✓ 尝试更换 USB 数据线"
    echo "  ✓ 尝试更换 USB 接口（优先使用 USB 3.0）"
    echo ""
    echo "【步骤 2】在手机上开启 USB 调试"
    echo "  1. 设置 -> 关于手机 -> 连续点击'版本号'7次"
    echo "  2. 返回设置 -> 系统和更新 -> 开发者选项"
    echo "  3. 开启以下开关："
    echo "     - USB调试"
    echo "     - USB安装"
    echo "     - 仅充电模式下允许ADB调试（如果有）"
    echo ""
    echo "【步骤 3】更改 USB 连接模式"
    echo "  1. 连接手机后，下拉通知栏"
    echo "  2. 点击 USB 连接通知"
    echo "  3. 选择'传输文件'或'文件传输（MTP）'"
    echo "  4. 不要选择'仅充电'"
    echo ""
    echo "【步骤 4】授权电脑"
    echo "  1. 开启 USB 调试后，手机会弹出'允许 USB 调试'"
    echo "  2. 勾选'始终允许来自这台计算机'"
    echo "  3. 点击'确定'"
    echo ""
    echo "【步骤 5】华为/荣耀手机特殊处理"
    echo "  - 可能需要安装华为手机驱动（HiSuite）"
    echo "  - 确保关闭 HiSuite 等手机管理软件"
    echo "  - 某些型号需要在开发者选项中开启额外选项"
    echo ""
    echo "【步骤 6】再次检查"
    echo "  重新运行此脚本或执行："
    echo "  $ADB devices -l"
    echo ""
else
    echo "✓ 检测到 $DEVICE_COUNT 个设备"
    echo ""
    echo "========================================="
    echo "设备信息："
    echo "$DEVICES_OUTPUT" | grep "device" | grep -v "List of"
    echo ""
    echo "现在运行以下命令检查 Flutter 设备："
    echo "  flutter devices"
    echo "========================================="
fi

echo ""
echo "4. 检查 USB 设备（macOS）..."
system_profiler SPUSBDataType 2>/dev/null | grep -A 5 -i "huawei\|honor\|android\|phone" | head -20 || echo "   ⚠ 无法检测 USB 设备（可能需要管理员权限）"
echo ""

echo "5. 检查 Flutter 设备..."
flutter devices 2>&1 | head -20
echo ""

