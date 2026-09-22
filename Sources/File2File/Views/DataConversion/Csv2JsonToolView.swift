import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct Csv2JsonToolView: View {
    @State private var fileData: FileData? = nil
    @State private var prettyPrint: Bool = true
    @State private var outputFileName: String = ""
    @State private var jsonPreview: String = ""
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isCopied: Bool = false

    @State private var isTargeted: Bool = false

    @ObservedObject private var settings = AppSettings.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            if fileData == nil {
                emptyDropZoneView
                    .padding(24)
            } else {
                mainWorkspaceView
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "curlybraces")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    Text("CSV to JSON Converter")
                        .font(.title2.bold())
                }

                Text("Transform CSV tabular data into structured JSON objects.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if fileData != nil {
                Button(action: resetFile) {
                    Label("Change File", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Empty Drop Zone

    private var emptyDropZoneView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Select CSV / TSV File")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Choose or drag & drop a CSV or TSV data file to begin conversion.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            FileDropZoneCardView(
                title: "Drag & Drop your CSV / TSV file here",
                subtitle: "Supports .csv, .tsv, and .txt delimited data files",
                iconName: "doc.text",
                buttonTitle: "Browse Files...",
                onBrowse: openFilePicker,
                onDropFiles: { urls in
                    if let first = urls.first {
                        loadFile(at: first)
                    }
                }
            )

            Spacer()
        }
    }

    // MARK: - Main Workspace

    private var mainWorkspaceView: some View {
        HSplitView {
            // Left sidebar: Options & Summary
            VStack(alignment: .leading, spacing: 18) {
                if let file = fileData {
                    fileSummaryCard(file)
                }

                Divider()

                optionsCard

                Spacer()

                actionButtons
            }
            .padding(16)
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)

            // Right area: Live JSON Preview
            jsonPreviewArea
        }
    }

    // MARK: - File Summary Card

    private func fileSummaryCard(_ file: FileData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INPUT FILE")
                .font(.caption2.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "doc.text.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(file.name)
                        .font(.headline)
                        .lineLimit(1)

                    Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Rows")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(file.totalRows)")
                        .font(.subheadline.bold())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Columns")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(file.headers.count)")
                        .font(.subheadline.bold())
                }
            }
            .padding(.top, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Options Card

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CONVERSION OPTIONS")
                .font(.caption2.bold())
                .foregroundColor(.secondary)

            Toggle("Pretty-print JSON", isOn: $prettyPrint)
                .onChange(of: prettyPrint) { _ in
                    generateJsonPreview()
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Output Filename")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("output.json", text: $outputFileName)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if let msg = statusMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(msg.contains("Failed") || msg.contains("Error") ? .red : .green)
                    .lineLimit(2)
            }

            Button(action: exportJSON) {
                HStack {
                    Spacer()
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                        Text("Export JSON File")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing || fileData == nil)
        }
    }

    // MARK: - JSON Preview Area

    private var jsonPreviewArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("JSON Output Preview")
                    .font(.headline)

                Spacer()

                Button(action: copyToClipboard) {
                    Label(isCopied ? "Copied!" : "Copy JSON", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .disabled(jsonPreview.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                Text(jsonPreview.isEmpty ? "// Processing preview..." : jsonPreview)
                    .font(.system(.body, design: .monospaced))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }

    // MARK: - Actions & Logic

    private func handleDroppedProviders(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async {
                    self.loadFile(at: url)
                }
            }
        }
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.commaSeparatedText, .tabSeparatedText, .text, UTType(filenameExtension: "csv")!].compactMap { $0 }

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(at: url)
        }
    }

    private func loadFile(at url: URL) {
        do {
            let data = try FileParser.parseFile(at: url, maxPreviewRows: 100)
            fileData = data

            let baseName = url.deletingPathExtension().lastPathComponent
            outputFileName = "\(baseName).json"
            statusMessage = nil

            generateJsonPreview()
        } catch {
            statusMessage = "Failed to parse CSV file: \(error.localizedDescription)"
        }
    }

    private func resetFile() {
        fileData = nil
        jsonPreview = ""
        outputFileName = ""
        statusMessage = nil
    }

    private func generateJsonPreview() {
        guard let file = fileData else { return }
        let rowsToConvert = file.previewRows

        do {
            let options: JSONSerialization.WritingOptions = prettyPrint ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
            let jsonObjectData = try JSONSerialization.data(withJSONObject: rowsToConvert, options: options)
            if let str = String(data: jsonObjectData, encoding: .utf8) {
                jsonPreview = str
            }
        } catch {
            jsonPreview = "// Error generating JSON preview: \(error.localizedDescription)"
        }
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(jsonPreview, forType: .string)

        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }

    private func exportJSON() {
        guard let file = fileData, file.fileURL != nil else { return }
        isProcessing = true
        statusMessage = "Exporting JSON..."

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                var allRows: [[String: String]] = []
                try FileParser.streamBatches(from: file, batchSize: 1000) { batch, _ in
                    allRows.append(contentsOf: batch)
                }

                let options: JSONSerialization.WritingOptions = prettyPrint ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
                let jsonObjectData = try JSONSerialization.data(withJSONObject: allRows, options: options)

                let filename = outputFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "export.json" : outputFileName
                let savedURL = try settings.saveOutputFile(filename: filename, content: String(data: jsonObjectData, encoding: .utf8) ?? "[]")

                DispatchQueue.main.async {
                    isProcessing = false
                    statusMessage = "Successfully exported to \(savedURL.lastPathComponent)"
                }
            } catch {
                DispatchQueue.main.async {
                    isProcessing = false
                    statusMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
