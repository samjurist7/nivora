# 图片资源清单

## 必需的图片资源

请将以下图片放入 `assets/images/` 目录：

### 1. 背景图片
- **bg_main.png** (或 bg_main@2x.png, bg_main@3x.png)
  - 全屏背景图片（深色六边形网格图案）
  - 用于启动页、登录页、未连接设备页

### 2. Logo 图片
- **logo.png** (推荐：logo@2x.png, logo@3x.png)
  - 启动页和未连接设备页使用的 Nivora Logo
  - 建议尺寸：根据设计稿

- **ilogo.png** (推荐：ilogo@2x.png, ilogo@3x.png)
  - 登录页使用的 Logo
  - 建议尺寸：根据设计稿

### 3. 装饰图片
- **bluelight.png** (推荐：bluelight@2x.png, bluelight@3x.png)
  - 蓝色发光弧线图片
  - 用于启动页、登录页、未连接设备页

### 4. 按钮图片
- **tap_to_connect.png** (推荐：tap_to_connect@2x.png, tap_to_connect@3x.png)
  - "Tap TO Connect" 按钮图片
  - 用于未连接设备页

- **skip_registration.png** (推荐：skip_registration@2x.png, skip_registration@3x.png)
  - "Skip Registration" 按钮图片
  - 用于登录页底部

## 文件结构

```
assets/images/
├── bg_main.png (或 @2x, @3x)
├── logo.png (或 @2x, @3x)
├── ilogo.png (或 @2x, @3x)
├── bluelight.png (或 @2x, @3x)
├── tap_to_connect.png (或 @2x, @3x)
└── skip_registration.png (或 @2x, @3x)
```

## 注意事项

1. 所有图片应该从蓝湖导出，推荐导出 @2x 和 @3x 版本
2. Flutter 会自动根据设备像素密度选择合适的图片
3. 图片格式：PNG（支持透明背景）
4. 添加图片后需要运行 `flutter pub get`

