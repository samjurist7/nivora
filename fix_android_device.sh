#!/bin/bash

echo "========================================="
echo "Android 设备连接诊断和修复脚本"
echo "========================================="
echo ""

ADB_PATH="/Users/mac2/Library/Android/sdk/platform-tools/adb"

echo "1. 重启 ADB 服务..."
$ADB_PATH kill-server 2>/dev/null
sleep 1
$ADB_PATH start-server
echo "   ✓ ADB 服务已重启"
echo ""

echo "2. 检查连接的设备..."
DEVICES=$($ADB_PATH devices -l | grep -v "List of devices" | grep -v "^$")
if [ -z "$DEVICES" ]; then
    echo "   ✗ 未检测到任何 Android 设备"
    echo ""
    echo "   可能的原因："
    echo "   a) 手机未开启 USB 调试"
    echo "   b) 手机未授权此电脑"
    echo "   c) USB 连接模式不正确"
    echo "   d) 需要安装手机驱动"
    echo ""
    echo "   请按照以下步骤操作："
    echo ""
    echo "   【步骤 1】在手机上开启开发者选项和 USB 调试"
    echo "   1. 打开 设置 -> 关于手机"
    echo "   2. 连续点击 '版本号' 7次，直到提示 '您已进入开发者模式'"
    echo "   3. 返回设置，找到 '系统和更新' -> '开发者选项'（或直接搜索'开发者选项'）"
    echo "   4. 开启 'USB调试' 开关"
    echo "   5. 开启 'USB安装' 开关（可选，但推荐）"
    echo ""
    echo "   【步骤 2】更改 USB 连接模式"
    echo "   1. 连接手机到电脑后，手机上会弹出 USB 连接提示"
    echo "   2. 选择 '传输文件' 或 '文件传输' 模式（不要选择'仅充电'）"
    echo "   3. 如果提示选择 USB 配置，选择 'MTP' 或 '文件传输'"
    echo ""
    echo "   【步骤 3】授权电脑"
    echo "   1. 开启 USB 调试后，手机上会弹出 '允许 USB 调试' 提示"
    echo "   2. 勾选 '始终允许来自这台计算机'"
    echo "   3. 点击 '确定' 或 '允许'"
    echo ""
    echo "   【步骤 4】验证连接"
    echo "   重新运行此脚本或执行: $ADB_PATH devices"
    echo ""
else
    echo "   ✓ 检测到以下设备："
    echo "$DEVICES" | while read line; do
        echo "      $line"
    done
    echo ""
    echo "3. 检查 Flutter 设备..."
    flutter devices
fi

echo ""
echo "========================================="
echo "如果仍然无法检测到设备，尝试以下方法："
echo ""
echo "方法 1: 更换 USB 数据线或 USB 接口"
echo "方法 2: 在手机上关闭并重新开启 USB 调试"
echo "方法 3: 拔掉数据线，重启 ADB，再重新连接"
echo "方法 4: 检查是否有手机管理软件冲突（如 HiSuite）"
echo "方法 5: 尝试使用无线调试（需要手机和电脑在同一网络）"
echo ""
echo "华为/荣耀手机特殊说明："
echo "- 可能需要安装华为手机驱动"
echo "- 某些型号需要开启 '仅充电模式下允许ADB调试'"
echo "- 如果使用 HiSuite，可能需要先安装 HiSuite"
echo "========================================="

