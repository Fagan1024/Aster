import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

private enum L10n {
    private enum Language {
        case zh
        case en
        case ja
    }

    private static var language: Language {
        let identifier = Locale.preferredLanguages.first ?? Locale.current.identifier
        if identifier.hasPrefix("ja") {
            return .ja
        }
        if identifier.hasPrefix("en") {
            return .en
        }
        return .zh
    }

    private static func text(zh: String, en: String, ja: String) -> String {
        switch language {
        case .zh:
            return zh
        case .en:
            return en
        case .ja:
            return ja
        }
    }

    static let sidebarEmpty = text(
        zh: "你选中的文件会显示在这里",
        en: "Selected files will appear here",
        ja: "選択したファイルがここに表示されます"
    )

    static let addFile = text(
        zh: "添加文件",
        en: "Add File",
        ja: "ファイルを追加"
    )

    static let openErrorTitle = text(
        zh: "无法打开文件",
        en: "Cannot Open File",
        ja: "ファイルを開けません"
    )

    static let ok = text(
        zh: "好",
        en: "OK",
        ja: "OK"
    )

    static let removeFromList = text(
        zh: "从列表移除",
        en: "Remove from List",
        ja: "リストから削除"
    )

    static let copyFile = text(
        zh: "复制",
        en: "Copy",
        ja: "コピー"
    )

    static let showInFinder = text(
        zh: "在 Finder 中显示",
        en: "Show in Finder",
        ja: "Finderで表示"
    )

    static let previewUnavailable = text(
        zh: "无法预览",
        en: "Preview Unavailable",
        ja: "プレビューできません"
    )

    static let fileReadFailed = text(
        zh: "文件读取失败",
        en: "Failed to read the file",
        ja: "ファイルの読み込みに失敗しました"
    )

    static let emptyPrompt = text(
        zh: "拖入 Markdown、HTML 或 CSV 文件开始预览",
        en: "Drop a Markdown, HTML, or CSV file to preview",
        ja: "Markdown、HTML、CSV ファイルをドロップしてプレビュー"
    )

    static let noExtension = text(
        zh: "无扩展名",
        en: "no extension",
        ja: "拡張子なし"
    )

    static let csvEmpty = text(
        zh: "这个 CSV 文件没有内容。",
        en: "This CSV file is empty.",
        ja: "この CSV ファイルは空です。"
    )

    static func unsupportedFileType(_ type: String) -> String {
        switch language {
        case .zh:
            return "暂时只支持 .md、.markdown、.html、.htm 和 .csv 文件，当前文件类型是 \(type)。"
        case .en:
            return "Only .md, .markdown, .html, .htm, and .csv files are supported. The current file type is \(type)."
        case .ja:
            return ".md、.markdown、.html、.htm、.csv ファイルのみ対応しています。現在のファイル形式は \(type) です。"
        }
    }

    static func csvMeta(rowCount: Int, columnCount: Int) -> String {
        switch language {
        case .zh:
            return "\(rowCount) 行 · \(columnCount) 列"
        case .en:
            return "\(rowCount) rows · \(columnCount) columns"
        case .ja:
            return "\(rowCount) 行 · \(columnCount) 列"
        }
    }

    static func csvColumn(_ index: Int) -> String {
        switch language {
        case .zh:
            return "列 \(index)"
        case .en:
            return "Column \(index)"
        case .ja:
            return "列 \(index)"
        }
    }
}

@main
struct PreviewerApp: App {
    var body: some Scene {
        WindowGroup {
            PreviewerView()
                .frame(minWidth: 900, minHeight: 560)
                .tint(BrandColor.primary)
        }
        .defaultSize(width: 1280, height: 800)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

private struct PreviewerView: View {
    @State private var items = LibraryStore.load()
    @State private var selection: LibraryItem.ID?
    @State private var errorMessage: String?
    @State private var isDropTargeted = false

    private var selectedItem: LibraryItem? {
        items.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            SidebarFileList(items: items, selection: $selection, remove: remove)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
            .overlay {
                if items.isEmpty {
                    Text(L10n.sidebarEmpty)
                        .font(.callout)
                        .foregroundStyle(NeutralColor.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
        } detail: {
            ZStack {
                if let selectedItem {
                    DetailView(item: selectedItem)
                        .id(selectedItem.id)
                } else {
                    EmptyStateView(openFile: openFiles)
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(BrandColor.primary, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                        .padding(12)
                        .allowsHitTesting(false)
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if let selectedItem {
                    ToolbarFileInfo(item: selectedItem)
                        .frame(minWidth: 520, alignment: .leading)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: openFiles) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderless)
                .background(Color(nsColor: .controlBackgroundColor), in: Circle())
                .help(L10n.addFile)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop(providers:))
        .onOpenURL(perform: importFile)
        .alert(L10n.openErrorTitle, isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(L10n.ok, role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .html,
            UTType(filenameExtension: "htm"),
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            UTType(filenameExtension: "csv")
        ].compactMap { $0 }

        guard panel.runModal() == .OK else {
            return
        }

        panel.urls.forEach(importFile)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else {
            return false
        }

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? Data)
                    .flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                    ?? (item as? URL)

                if let url {
                    DispatchQueue.main.async {
                        importFile(url)
                    }
                }
            }
        }

        return true
    }

    private func importFile(_ url: URL) {
        do {
            let item = try LibraryStore.importFile(url)
            if let existingIndex = items.firstIndex(where: { $0.sourcePath == item.sourcePath }) {
                items[existingIndex] = item
            } else {
                items.insert(item, at: 0)
            }
            LibraryStore.save(items)
            selection = item.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ offsets: IndexSet) {
        for offset in offsets {
            LibraryStore.remove(items[offset])
        }
        items.remove(atOffsets: offsets)
        LibraryStore.save(items)
        if let selection, !items.contains(where: { $0.id == selection }) {
            self.selection = items.first?.id
        }
    }

    private func remove(_ item: LibraryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        remove(IndexSet(integer: index))
    }
}

private struct SidebarFileList: View {
    let items: [LibraryItem]
    @Binding var selection: LibraryItem.ID?
    let remove: (LibraryItem) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(items) { item in
                    LibraryRow(item: item, isSelected: item.id == selection)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selection = item.id
                        }
                        .contextMenu {
                            Button {
                                copyToPasteboard(item)
                            } label: {
                                Label(L10n.copyFile, systemImage: "doc.on.doc")
                            }

                            Button {
                                showInFinder(item)
                            } label: {
                                Label(L10n.showInFinder, systemImage: "folder")
                            }

                            Divider()

                            Button(role: .destructive) {
                                remove(item)
                            } label: {
                                Label(L10n.removeFromList, systemImage: "minus.circle")
                            }
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func copyToPasteboard(_ item: LibraryItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([item.url as NSURL])
    }

    private func showInFinder(_ item: LibraryItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}

private struct LibraryRow: View {
    let item: LibraryItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            FileKindIcon(kind: item.kind)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .lineLimit(1)

                Text(item.sourcePath)
                    .font(.caption)
                    .foregroundStyle(NeutralColor.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? BrandColor.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DetailView: View {
    let item: LibraryItem

    var body: some View {
        PreviewContent(item: item)
    }
}

private struct ToolbarFileInfo: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: 10) {
            FileKindIcon(kind: item.kind)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(item.url.path)
                    .font(.caption)
                    .foregroundStyle(NeutralColor.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
    }
}

private struct PreviewContent: View {
    let item: LibraryItem

    var body: some View {
        if let document = try? PreviewDocument(item: item) {
            WebPreview(document: document)
        } else {
            ContentUnavailableView(L10n.previewUnavailable, systemImage: "exclamationmark.triangle", description: Text(L10n.fileReadFailed))
        }
    }
}

private struct EmptyStateView: View {
    let openFile: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "doc")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(NeutralColor.secondary)

            Text(L10n.emptyPrompt)
                .font(.callout)
                .foregroundStyle(NeutralColor.secondary)
                .multilineTextAlignment(.center)

            Button(action: openFile) {
                Label(L10n.addFile, systemImage: "plus")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .frame(height: 40)
            .padding(.horizontal, 20)
            .background(BrandColor.primary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WebPreview: NSViewRepresentable {
    let document: PreviewDocument

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsMagnification = true
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        switch document.kind {
        case .html:
            webView.loadFileURL(document.url, allowingReadAccessTo: document.url.deletingLastPathComponent())
        case .markdown(let html), .csv(let html):
            webView.loadHTMLString(html, baseURL: document.url.deletingLastPathComponent())
        }
    }
}

private struct LibraryItem: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let storedPath: String
    let sourcePath: String
    let kind: FileKind
    let addedAt: Date

    var url: URL {
        URL(fileURLWithPath: storedPath)
    }
}

private enum FileKind: String, Codable {
    case markdown
    case html
    case csv

    init(fileExtension: String) throws {
        switch fileExtension.lowercased() {
        case "md", "markdown":
            self = .markdown
        case "html", "htm":
            self = .html
        case "csv":
            self = .csv
        default:
            throw PreviewError.unsupportedFileType(fileExtension.isEmpty ? L10n.noExtension : ".\(fileExtension)")
        }
    }

    var systemImage: String {
        switch self {
        case .markdown:
            return "doc.text"
        case .html:
            return "link"
        case .csv:
            return "tablecells"
        }
    }
}

private enum BrandColor {
    static let primary = Color(red: 45 / 255, green: 124 / 255, blue: 78 / 255)
    static let selection = Color(red: 226 / 255, green: 243 / 255, blue: 233 / 255)
}

private struct FileKindIcon: View {
    let kind: FileKind

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(NeutralColor.primary)
        .frame(width: 24, height: 24)
    }
}

private enum NeutralColor {
    static let primary = Color(nsColor: .labelColor)
    static let secondary = Color(nsColor: .secondaryLabelColor)
}

private enum LibraryStore {
    static func load() -> [LibraryItem] {
        guard let data = try? Data(contentsOf: indexURL) else {
            return []
        }
        return (try? JSONDecoder().decode([LibraryItem].self, from: data)) ?? []
    }

    static func save(_ items: [LibraryItem]) {
        do {
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            NSLog("Failed to save library: \(error.localizedDescription)")
        }
    }

    static func importFile(_ url: URL) throws -> LibraryItem {
        let normalizedURL = url.standardizedFileURL
        let kind = try FileKind(fileExtension: normalizedURL.pathExtension)
        try FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)

        let destination = uniqueDestination(for: normalizedURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: normalizedURL, to: destination)

        return LibraryItem(
            id: UUID(),
            name: normalizedURL.lastPathComponent,
            storedPath: destination.path,
            sourcePath: normalizedURL.path,
            kind: kind,
            addedAt: Date()
        )
    }

    static func remove(_ item: LibraryItem) {
        try? FileManager.default.removeItem(at: item.url)
    }

    private static var supportURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return baseURL.appendingPathComponent("Aster", isDirectory: true)
    }

    private static var documentsURL: URL {
        supportURL.appendingPathComponent("Documents", isDirectory: true)
    }

    private static var indexURL: URL {
        supportURL.appendingPathComponent("Library.json")
    }

    private static func uniqueDestination(for fileName: String) -> URL {
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
        var candidate = documentsURL.appendingPathComponent(fileName)
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            let nextName = fileExtension.isEmpty ? "\(baseName) \(index)" : "\(baseName) \(index).\(fileExtension)"
            candidate = documentsURL.appendingPathComponent(nextName)
            index += 1
        }

        return candidate
    }
}

private struct PreviewDocument: Identifiable {
    enum Kind {
        case html
        case markdown(String)
        case csv(String)
    }

    let id = UUID()
    let url: URL
    let kind: Kind

    init(item: LibraryItem) throws {
        switch item.kind {
        case .html:
            self.url = item.url
            self.kind = .html
        case .markdown:
            let source = try String(contentsOf: item.url, encoding: .utf8)
            self.url = item.url
            self.kind = .markdown(MarkdownRenderer.renderDocument(source, title: item.name))
        case .csv:
            let source = try String(contentsOf: item.url, encoding: .utf8)
            self.url = item.url
            self.kind = .csv(CSVRenderer.renderDocument(source, title: item.name))
        }
    }
}

private enum PreviewError: LocalizedError {
    case unsupportedFileType(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let type):
            return L10n.unsupportedFileType(type)
        }
    }
}

private enum CSVRenderer {
    static func renderDocument(_ csv: String, title: String) -> String {
        let rows = parse(csv)
        let table = renderTable(rows)
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            :root {
              color-scheme: light dark;
              --text: light-dark(#1f2328, #e6edf3);
              --muted: light-dark(#59636e, #8b949e);
              --border: light-dark(#d0d7de, #30363d);
              --header: light-dark(#f6f8fa, #161b22);
              --stripe: light-dark(#fbfbfc, #0d1117);
              --accent: light-dark(#2d7c4e, #56d18f);
            }
            * { box-sizing: border-box; }
            body {
              margin: 0;
              color: var(--text);
              font: 14px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            }
            main {
              padding: 24px;
            }
            header {
              margin-bottom: 14px;
              background: Canvas;
            }
            h1 {
              margin: 0 0 4px;
              font-size: 20px;
              line-height: 1.25;
            }
            .meta {
              color: var(--muted);
              font-size: 12px;
            }
            .table-wrap {
              width: 100%;
              max-width: calc(100vw - 48px);
              overflow-x: auto;
              overflow-y: visible;
              border: 1px solid var(--border);
              border-radius: 8px;
            }
            table {
              width: max-content;
              min-width: 100%;
              border-collapse: separate;
              border-spacing: 0;
            }
            th, td {
              padding: 7px 10px;
              border-right: 1px solid var(--border);
              border-bottom: 1px solid var(--border);
              text-align: left;
              vertical-align: top;
              white-space: pre;
            }
            th {
              position: sticky;
              top: 0;
              z-index: 1;
              background: var(--header);
              font-weight: 600;
            }
            tr:nth-child(even) td { background: var(--stripe); }
            tr:last-child td { border-bottom: 0; }
            th:last-child, td:last-child { border-right: 0; }
            .empty {
              padding: 32px;
              color: var(--muted);
              border: 1px dashed var(--border);
              border-radius: 8px;
            }
          </style>
        </head>
        <body>
        <main>
          <header>
            <h1>\(escapeHTML(title))</h1>
            <div class="meta">\(escapeHTML(L10n.csvMeta(rowCount: rows.count, columnCount: rows.map(\.count).max() ?? 0)))</div>
          </header>
          \(table)
        </main>
        </body>
        </html>
        """
    }

    private static func parse(_ csv: String) -> [[String]] {
        let normalized = csv.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = normalized.startIndex

        while index < normalized.endIndex {
            let character = normalized[index]

            if character == "\"" {
                let nextIndex = normalized.index(after: index)
                if inQuotes, nextIndex < normalized.endIndex, normalized[nextIndex] == "\"" {
                    field.append("\"")
                    index = normalized.index(after: nextIndex)
                    continue
                }
                inQuotes.toggle()
            } else if character == "," && !inQuotes {
                row.append(field)
                field.removeAll()
            } else if character == "\n" && !inQuotes {
                row.append(field)
                rows.append(row)
                row.removeAll()
                field.removeAll()
            } else {
                field.append(character)
            }

            index = normalized.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty || normalized.hasSuffix(",") {
            row.append(field)
            rows.append(row)
        }

        return rows.filter { !$0.allSatisfy { $0.isEmpty } }
    }

    private static func renderTable(_ rows: [[String]]) -> String {
        guard let firstRow = rows.first else {
            return "<div class=\"empty\">\(escapeHTML(L10n.csvEmpty))</div>"
        }

        let columnCount = rows.map(\.count).max() ?? 0
        let headers = padded(firstRow, to: columnCount).enumerated().map { index, value in
            let title = value.isEmpty ? L10n.csvColumn(index + 1) : value
            return "<th>\(escapeHTML(title))</th>"
        }.joined()

        let bodyRows = rows.dropFirst().map { row in
            let cells = padded(row, to: columnCount).map { "<td>\(escapeHTML($0))</td>" }.joined()
            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")

        return """
        <div class="table-wrap">
          <table>
            <thead><tr>\(headers)</tr></thead>
            <tbody>
            \(bodyRows)
            </tbody>
          </table>
        </div>
        """
    }

    private static func padded(_ row: [String], to count: Int) -> [String] {
        if row.count >= count {
            return row
        }
        return row + Array(repeating: "", count: count - row.count)
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private enum MarkdownRenderer {
    static func renderDocument(_ markdown: String, title: String) -> String {
        let body = render(markdown)
        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            :root {
              color-scheme: light dark;
              --text: light-dark(#1f2328, #e6edf3);
              --muted: light-dark(#59636e, #8b949e);
              --border: light-dark(#d0d7de, #30363d);
              --code: light-dark(#f6f8fa, #161b22);
              --accent: light-dark(#0969da, #58a6ff);
            }
            body {
              box-sizing: border-box;
              max-width: 920px;
              margin: 0 auto;
              padding: 36px 28px 56px;
              color: var(--text);
              font: 16px/1.62 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            }
            h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.4em 0 .5em; }
            h1 { padding-bottom: .28em; border-bottom: 1px solid var(--border); }
            p, ul, ol, blockquote, pre { margin: 0 0 1em; }
            a { color: var(--accent); }
            blockquote {
              margin-left: 0;
              padding-left: 1em;
              color: var(--muted);
              border-left: 4px solid var(--border);
            }
            pre, code {
              border-radius: 6px;
              background: var(--code);
              font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
            }
            code { padding: .15em .35em; }
            pre { overflow: auto; padding: 14px 16px; }
            pre code { padding: 0; background: transparent; }
            img { max-width: 100%; height: auto; }
            table { border-collapse: collapse; width: 100%; margin-bottom: 1em; }
            th, td { border: 1px solid var(--border); padding: 6px 10px; }
            hr { border: 0; border-top: 1px solid var(--border); margin: 2em 0; }
          </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func render(_ markdown: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var html: [String] = []
        var paragraph: [String] = []
        var listItems: [String] = []
        var codeLines: [String] = []
        var inCodeBlock = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html.append("<p>\(renderInline(paragraph.joined(separator: " ")))</p>")
            paragraph.removeAll()
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            html.append("<ul>\(listItems.joined())</ul>")
            listItems.removeAll()
        }

        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if inCodeBlock {
                    html.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
                    codeLines.removeAll()
                    inCodeBlock = false
                } else {
                    flushParagraph()
                    flushList()
                    inCodeBlock = true
                }
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                flushList()
                continue
            }

            if trimmed == "---" || trimmed == "***" {
                flushParagraph()
                flushList()
                html.append("<hr>")
                continue
            }

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                flushList()
                html.append("<h\(heading.level)>\(renderInline(heading.text))</h\(heading.level)>")
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                flushList()
                let quote = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                html.append("<blockquote>\(renderInline(String(quote)))</blockquote>")
                continue
            }

            if let item = parseListItem(trimmed) {
                flushParagraph()
                listItems.append("<li>\(renderInline(item))</li>")
                continue
            }

            flushList()
            paragraph.append(trimmed)
        }

        if inCodeBlock {
            html.append("<pre><code>\(escapeHTML(codeLines.joined(separator: "\n")))</code></pre>")
        }

        flushParagraph()
        flushList()
        return html.joined(separator: "\n")
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes), line.dropFirst(hashes).first == " " else {
            return nil
        }
        return (hashes, String(line.dropFirst(hashes + 1)))
    }

    private static func parseListItem(_ line: String) -> String? {
        for marker in ["- ", "* ", "+ "] {
            if line.hasPrefix(marker) {
                return String(line.dropFirst(marker.count))
            }
        }
        return nil
    }

    private static func renderInline(_ text: String) -> String {
        var output = escapeHTML(text)
        output = replaceRegex(#"`([^`]+)`"#, in: output, with: "<code>$1</code>")
        output = replaceRegex(#"\*\*([^*]+)\*\*"#, in: output, with: "<strong>$1</strong>")
        output = replaceRegex(#"\*([^*]+)\*"#, in: output, with: "<em>$1</em>")
        output = replaceRegex(#"!\[([^\]]*)\]\(([^)]+)\)"#, in: output, with: "<img alt=\"$1\" src=\"$2\">")
        output = replaceRegex(#"\[([^\]]+)\]\(([^)]+)\)"#, in: output, with: "<a href=\"$2\">$1</a>")
        return output
    }

    private static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func replaceRegex(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}
