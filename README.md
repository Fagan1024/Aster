# Aster

Aster is a tiny macOS previewer for Markdown, HTML, and CSV files. Drop files into the window, keep them in a local sidebar, and preview them without sending anything to a server.

![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Preview `.md`, `.markdown`, `.html`, `.htm`, and `.csv` files
- Drag files into the app or pick one or more files from the add button
- Keep imported files in a local library sidebar
- Render HTML directly with WKWebView
- Render Markdown as lightweight HTML
- Render CSV as a scrollable table with quoted fields, escaped quotes, and multiline fields
- Localized UI in English, Simplified Chinese, and Japanese
- Local-first: files are copied to `~/Library/Application Support/Aster/Documents/`

## Build

```bash
./build.sh
```

Open the built app:

```bash
open "build/Aster.app"
```

You can also open `Aster.xcodeproj` in Xcode.

## Package for Distribution

Install a `Developer ID Application` certificate in Keychain first, then run:

```bash
./package.sh
```

The signed DMG is created at:

```bash
build/dist/Aster.dmg
```

To notarize and staple the DMG, configure a notarytool keychain profile first:

```bash
xcrun notarytool store-credentials AsterNotary --apple-id "YOUR_APPLE_ID" --team-id "YOUR_TEAM_ID"
```

Then run:

```bash
./package.sh --notarize
```

## Privacy

Aster is a local previewer. It does not upload your files or include analytics. See [PRIVACY.md](PRIVACY.md).

## License

MIT. See [LICENSE](LICENSE).

---

## 中文

Aster 是一个极简 macOS 文件预览器，支持 Markdown、HTML 和 CSV。把文件拖进窗口，就可以在本地侧边栏里保存并预览；文件不会上传到任何服务器。

### 功能

- 预览 `.md`、`.markdown`、`.html`、`.htm` 和 `.csv` 文件
- 支持拖拽导入，也可以点击添加按钮选择多个文件
- 左侧 sidebar 保存已导入文件
- HTML 使用 WKWebView 原样预览
- Markdown 转成轻量 HTML 后预览
- CSV 转成可滚动表格，支持双引号字段、双引号转义和字段内换行
- 界面支持英文、简体中文、日文
- 本地优先：文件复制到 `~/Library/Application Support/Aster/Documents/`

### 构建

```bash
./build.sh
open "build/Aster.app"
```

### 分发打包

先在钥匙串里安装 Apple Developer 账号的 `Developer ID Application` 证书，然后运行：

```bash
./package.sh
```

如果已经配置好 `notarytool` 凭据，可以同时公证并 staple：

```bash
./package.sh --notarize
```

---

## 日本語

Aster は、Markdown、HTML、CSV ファイル向けの小さな macOS プレビューアです。ファイルをウィンドウにドロップすると、ローカルのサイドバーに保存してプレビューできます。ファイルはサーバーにアップロードされません。

### 機能

- `.md`、`.markdown`、`.html`、`.htm`、`.csv` ファイルをプレビュー
- ドラッグ&ドロップ、または追加ボタンから複数ファイルを読み込み
- 読み込んだファイルをローカルのサイドバーに保存
- HTML は WKWebView でそのまま表示
- Markdown は軽量 HTML に変換して表示
- CSV はスクロール可能な表として表示し、引用符付きフィールド、エスケープされた引用符、複数行フィールドに対応
- UI は英語、簡体字中国語、日本語に対応
- ローカル優先: ファイルは `~/Library/Application Support/Aster/Documents/` にコピーされます

### ビルド

```bash
./build.sh
open "build/Aster.app"
```

### 配布用パッケージ

先に `Developer ID Application` 証明書を Keychain にインストールしてから実行します。

```bash
./package.sh
```

`notarytool` の認証情報を設定済みの場合は、公証と staple も同時に実行できます。

```bash
./package.sh --notarize
```
