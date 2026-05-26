# Dart SDK 配置指南

## ✅ 已完成的配置

我已经自动配置了 Dart SDK 的路径和库文件：

1. **Dart SDK 位置**：`/opt/homebrew/share/flutter/bin/cache/dart-sdk`
2. **Dart 版本**：3.9.2 (stable)
3. **配置文件**：
   - `.idea/libraries/Dart_SDK.xml` - Dart SDK 库配置
   - `.idea/nivora.iml` - 已包含 Dart SDK 引用

## 📋 在 Android Studio 中配置 Flutter SDK

如果 Android Studio 仍然提示 "Dart SDK is not configured"，请按照以下步骤操作：

### 方法 1：通过设置界面配置（推荐）

1. **打开设置**
   - macOS: `Android Studio -> Settings`
   - Windows/Linux: `File -> Settings`

2. **配置 Flutter SDK**
   - 左侧菜单：`Languages & Frameworks -> Flutter`
   - 在 **Flutter SDK path** 字段中填入：
     ```
     /opt/homebrew/share/flutter
     ```
   - 点击右侧的文件夹图标可以选择路径
   - 点击 `Apply` 和 `OK`

3. **验证配置**
   - 设置界面应该显示：
     - Flutter SDK path: `/opt/homebrew/share/flutter`
     - Dart SDK path: `/opt/homebrew/share/flutter/bin/cache/dart-sdk`（自动检测）

4. **重启 Android Studio**
   - 完全退出并重新打开 Android Studio
   - 等待项目重新索引

### 方法 2：如果方法1不起作用

1. **清除缓存并重新导入**
   - `File -> Invalidate Caches / Restart`
   - 选择 `Invalidate and Restart`
   - 等待项目重新索引

2. **手动指定 Dart SDK**
   - `Languages & Frameworks -> Dart`
   - 在 **Dart SDK path** 中填入：
     ```
     /opt/homebrew/share/flutter/bin/cache/dart-sdk
     ```
   - 点击 `Apply` 和 `OK`

### 方法 3：验证配置是否生效

打开任意 `.dart` 文件（如 `lib/main.dart`），检查：
- ✅ 代码有语法高亮
- ✅ 没有红色错误提示
- ✅ 代码补全功能正常
- ✅ 可以跳转到定义

## 🔧 故障排除

如果配置后仍有问题：

1. **检查 Flutter 和 Dart 插件**
   - `File -> Settings -> Plugins`
   - 确保 **Flutter** 和 **Dart** 插件都已安装并启用

2. **运行诊断脚本**
   ```bash
   cd /Users/mac2/Documents/GitHub/nivora
   ./configure_dart_sdk.sh
   ```

3. **检查文件权限**
   ```bash
   ls -la /opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart
   ```
   应该显示可执行权限

4. **重新获取 Flutter 工具**
   ```bash
   flutter doctor -v
   flutter pub get
   ```

## 📝 配置文件说明

已创建的配置文件：
- `.idea/libraries/Dart_SDK.xml` - Dart SDK 库定义
- `.idea/nivora.iml` - 项目模块配置（包含 Dart SDK 引用）
- `.idea/misc.xml` - 项目类型标记（Flutter）

这些配置文件会在 Android Studio 打开项目时自动读取。

