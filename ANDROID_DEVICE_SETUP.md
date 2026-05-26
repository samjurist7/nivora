# Android 设备连接指南

## 🔍 问题诊断

如果 Android Studio 或 Flutter 无法检测到你的华为/荣耀手机，请按照以下步骤排查：

## ✅ 解决方案

### 步骤 1：开启开发者选项和 USB 调试

#### 1.1 开启开发者选项
1. 打开手机的 **设置**
2. 进入 **关于手机**（可能在不同位置，如：系统 -> 关于手机）
3. 找到 **版本号** 或 **内部版本号**
4. **连续快速点击 7 次**版本号
5. 会提示"您已进入开发者模式"或"您现在已成为开发者"

#### 1.2 开启 USB 调试
1. 返回设置主界面
2. 找到 **系统和更新** -> **开发者选项**（或直接搜索"开发者选项"）
3. 开启以下开关：
   - ✅ **USB调试**
   - ✅ **USB安装**（可选但推荐）
   - ✅ **仅充电模式下允许ADB调试**（如果有这个选项，强烈推荐开启）

### 步骤 2：更改 USB 连接模式

1. 用 USB 数据线连接手机到电脑
2. 手机上会弹出 USB 连接提示，选择：
   - **传输文件** 或 **文件传输（MTP）**
   - **不要选择** "仅充电"
3. 如果下拉通知栏，点击 USB 连接通知，选择 "文件传输" 模式

### 步骤 3：授权电脑

1. 开启 USB 调试后，手机上会弹出 **"允许 USB 调试"** 提示框
2. ✅ **勾选** "始终允许来自这台计算机"
3. 点击 **"确定"** 或 **"允许"**
4. 如果需要，输入手机锁屏密码确认

### 步骤 4：验证连接

在终端运行以下命令：

```bash
cd /Users/mac2/Documents/GitHub/nivora
./fix_android_device.sh
```

或者直接运行：

```bash
/Users/mac2/Library/Android/sdk/platform-tools/adb devices
```

应该能看到类似这样的输出：
```
List of devices attached
ABCD123456789    device
```

### 步骤 5：在 Android Studio 中查看

1. 重启 Android Studio（如果已经打开）
2. 顶部工具栏应该显示设备选择下拉菜单
3. 选择你的设备，或者运行 `flutter devices` 查看

## 🔧 常见问题排查

### 问题 1：ADB 显示 "unauthorized"

**原因**：手机未授权此电脑

**解决**：
1. 拔掉数据线
2. 在手机上：设置 -> 开发者选项 -> 撤销 USB 调试授权
3. 重新连接手机
4. 重新授权电脑

### 问题 2：设备显示为 "offline"

**原因**：USB 连接模式不正确或驱动问题

**解决**：
1. 更改 USB 连接模式为 "文件传输"
2. 重启 ADB：`adb kill-server && adb start-server`
3. 重新插拔数据线

### 问题 3：完全检测不到设备

**解决步骤**：
1. ✅ 确认 USB 调试已开启
2. ✅ 确认 USB 连接模式为 "文件传输"
3. ✅ 尝试更换 USB 数据线
4. ✅ 尝试更换 USB 接口（优先使用 USB 3.0 接口）
5. ✅ 重启 ADB 服务
6. ✅ 重启手机和电脑

### 问题 4：华为/荣耀手机特殊问题

华为和荣耀手机可能需要：

1. **安装华为手机驱动**
   - 下载并安装华为手机助手（HiSuite）
   - 或者手动安装驱动：https://developer.huawei.com/consumer/cn/support

2. **开启额外选项**
   - 开发者选项 -> **仅充电模式下允许ADB调试**（如果有）
   - 开发者选项 -> **USB安装**

3. **关闭 HiSuite 等管理软件**
   - 某些手机管理软件可能与 ADB 冲突
   - 如果安装了 HiSuite，尝试关闭它

## 🌐 使用无线调试（备选方案）

如果 USB 连接一直有问题，可以尝试无线调试：

### 前提条件
- 手机和电脑在同一 Wi-Fi 网络
- Android 11 或更高版本（某些华为手机可能不支持）

### 步骤
1. 在手机上：开发者选项 -> 开启"无线调试"
2. 连接无线调试，记录显示的 IP 地址和端口
3. 在电脑上运行：
   ```bash
   adb connect 手机IP:端口
   ```
4. 手机上确认连接

## 📋 快速诊断命令

```bash
# 检查 ADB 设备
/Users/mac2/Library/Android/sdk/platform-tools/adb devices -l

# 重启 ADB 服务
/Users/mac2/Library/Android/sdk/platform-tools/adb kill-server
/Users/mac2/Library/Android/sdk/platform-tools/adb start-server

# 检查 Flutter 设备
flutter devices

# 运行诊断脚本
cd /Users/mac2/Documents/GitHub/nivora
./fix_android_device.sh
```

## ✅ 成功标志

连接成功后，你应该看到：

1. **终端中**：`adb devices` 显示设备列表
2. **Flutter 中**：`flutter devices` 显示 Android 设备
3. **Android Studio 中**：顶部工具栏显示设备选择器，可以选择你的手机

## 🆘 仍然无法连接？

如果按照以上步骤仍然无法连接，请：
1. 运行诊断脚本获取详细信息
2. 检查手机型号和 Android 版本
3. 查看是否有特殊的安全设置阻止连接
4. 尝试在其他电脑上测试，确认是电脑问题还是手机问题

