# Assets 目录说明

## 目录结构

- `images/` - 存放普通图片资源（PNG, JPG 等）
- `icons/` - 存放图标资源

## 蓝湖切图指南

### 是否需要提供 2x、3x 图片？

**简短回答：建议提供，但不是必须的。**

### 详细说明

#### Flutter 的图片处理机制：
1. **Flutter 会自动根据设备像素密度选择合适分辨率的图片**
2. **如果只有单张图片，Flutter 会自动缩放，但可能在部分设备上模糊**
3. **提供多倍图可以获得更清晰的显示效果**

#### 蓝湖切图建议：

**建议提供多倍图的情况：**
- ✅ **图标类资源**（如 logo、按钮图标等）- **强烈推荐提供 2x、3x**
- ✅ **小尺寸图片**（如头像、小图标）- **强烈推荐**
- ✅ **需要清晰显示的 UI 元素**（如标签、徽章等）

**可以使用单张图片的情况：**
- ⚠️ **大尺寸背景图**（可以只提供 2x，文件体积考虑）
- ⚠️ **渐变或纯色背景**（可以只用矢量或代码实现）
- ⚠️ **临时占位图**（开发阶段可用单张）

#### 蓝湖切图步骤：

1. **在蓝湖中选择切图**
   - 点击设计稿上的切图标记
   - 选择导出格式：**PNG**（推荐，支持透明）或 JPG

2. **导出倍数设置**
   - 蓝湖可以导出：**1x、2x、3x**
   - 建议至少导出 **2x** 和 **3x**
   - 如果文件大小是问题，优先保证 **2x**

3. **文件命名规范**
   ```
   assets/images/
   ├── logo.png        # 1x（基准图，可选）
   ├── logo@2x.png    # 2x（常用）
   └── logo@3x.png    # 3x（高清设备）
   ```

4. **Flutter 自动识别**
   - 使用 `Image.asset('assets/images/logo.png')`
   - Flutter 会根据设备自动选择 `logo@2x.png` 或 `logo@3x.png`
   - 如果找不到对应倍数，会降级使用其他倍数或 1x

#### 实际建议：

**最佳实践（推荐）：**
- 图标、Logo：提供 **@2x** 和 **@3x**
- 大图背景：可以只提供 **@2x**（节省空间）
- 小图标（< 50px）：**必须提供 @2x 和 @3x**

**简化方案（快速开发）：**
- 所有图片只提供 **@2x**（大部分设备足够清晰）
- 后续有需要再补充 @3x

## 使用方法

在代码中使用图片：

```dart
// 使用 Image.asset（Flutter 会自动选择合适分辨率）
Image.asset('assets/images/logo.png')

// 设置宽高（注意：宽高是逻辑像素，Flutter 会自动适配）
Image.asset(
  'assets/images/logo.png',
  width: 100,  // 逻辑像素，不是物理像素
  height: 100,
)

// 或者使用 AssetImage
DecorationImage(
  image: AssetImage('assets/images/background.jpg'),
)

// 在 Container 中使用
Container(
  decoration: BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/bg.png'),
      fit: BoxFit.cover,
    ),
  ),
)
```

## 注意事项

1. **添加新图片后，需要运行 `flutter pub get` 刷新资源**
2. **图片路径要相对于项目根目录**
3. **推荐使用 2x、3x 多分辨率图片适配不同屏幕**
4. **Web 平台支持所有格式，移动端推荐 PNG（支持透明度）**
5. **文件名命名使用 @2x、@3x 后缀（不是 @2.0x）**
6. **Flutter 的宽高单位是逻辑像素（dp），不是物理像素**

