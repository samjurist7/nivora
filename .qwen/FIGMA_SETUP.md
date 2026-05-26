# Figma MCP 配置指南

## 1. 获取 Figma Access Token

1. 登录 [Figma](https://www.figma.com)
2. 进入 **Settings** → **Account**
3. 滚动到 **Personal access tokens** 部分
4. 点击 **Create new token**
5. 复制生成的 token（只显示一次！）

## 2. 设置环境变量

### Windows (永久)
```powershell
# 在 PowerShell 中运行
[System.Environment]::SetEnvironmentVariable('FIGMA_ACCESS_TOKEN', '你的_token_这里', 'User')
```

### Windows (临时，仅当前会话)
```powershell
$env:FIGMA_ACCESS_TOKEN = "你的_token_这里"
```

### 或者创建 .env 文件
在项目根目录创建 `.env` 文件：
```
FIGMA_ACCESS_TOKEN=你的_token_这里
```

## 3. 可用的 Figma 命令

配置完成后，可以使用以下功能：

- **获取文件信息** - 读取 Figma 设计文件
- **获取组件** - 提取设计系统中的组件
- **获取样式** - 获取颜色、文本样式等
- **导出资源** - 获取图片、SVG 等资源

## 4. 使用示例

请求我帮你：
- "从 Figma 文件获取颜色样式"
- "分析这个 Figma 设计的布局"
- "导出 Figma 中的 logo 组件"

提供 Figma 文件 URL 即可，例如：
`https://www.figma.com/file/FILE_ID/...`

## 5. 验证配置

配置完成后，重启 Qwen Code，然后可以问我：
"连接到 Figma" 或 "获取 Figma 文件信息"
