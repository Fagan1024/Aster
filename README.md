# Aster

一个极简 macOS 预览器：把 `.md`、`.markdown`、`.html`、`.htm` 或 `.csv` 文件拖进窗口就能查看。
文件会复制到应用自己的资料库里，重启后仍然显示在左侧 sidebar。

## 构建

```bash
./build.sh
```

构建完成后打开：

```bash
open "build/Aster.app"
```

也可以直接用 Xcode 打开 `Aster.xcodeproj`。

## 分发打包

先在钥匙串里安装 Apple Developer 账号的 `Developer ID Application` 证书，然后运行：

```bash
./package.sh
```

生成的 DMG 在：

```bash
build/dist/Aster.dmg
```

如果已经配置好 `notarytool` 凭据，可以同时公证并 staple：

```bash
./package.sh --notarize
```

默认使用名为 `AsterNotary` 的 notarytool keychain profile。可以这样创建：

```bash
xcrun notarytool store-credentials AsterNotary --apple-id "你的 Apple ID" --team-id "你的 Team ID"
```

## 功能

- 拖放 Markdown / HTML / CSV 文件预览
- 点击按钮选择一个或多个本地文件
- 左侧 sidebar 显示已添加的所有文件
- 文件行通过 Markdown / HTML / CSV 图标区分格式
- 添加后复制到 `~/Library/Application Support/Aster/Documents/`
- HTML 使用 WKWebView 原样显示
- Markdown 转成 HTML 后显示，支持标题、段落、列表、引用、代码块、粗体、斜体、链接和图片
- CSV 转成可横向滚动的表格后显示，支持带引号的逗号和换行字段
