import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct Excel2CsvToolView: View {
    @State private var fileData: FileData? = nil
    @State private var outputFileName: String = ""
    @State private var csvPreview: String = ""
    @State private var convertedCSVURL: URL? = nil
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
                    Image(systemName: "document.on.document")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                    Text("Excel to CSV Converter")
                        .font(.title2.bold())
                }

                Text("Extract and convert Excel worksheets (.xlsx) to standardized CSV files.")
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
                Text("Select Source File")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Choose or drag & drop an Excel (.xlsx) dataset to begin conversion.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            FileDropZoneCardView(
                title: "Drag & Drop your Excel (.xlsx) file here",
                subtitle: "Supports Microsoft Excel .xlsx format",
                iconName: "tablecells",
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

            // Right area: CSV Preview
            csvPreviewArea
        }
    }

    // MARK: - File Summary Card

    private func fileSummaryCard(_ file: FileData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INPUT FILE")
                .font(.caption2.bold())
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Image(systemName: "tablecells.fill")
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
                    Text("Worksheets")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(file.sheets.count)")
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Output Filename")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("output.csv", text: $outputFileName)
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

            Button(action: exportCSV) {
                HStack {
                    Spacer()
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                        Text("Export CSV File")
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

    // MARK: - CSV Preview Area

    private var csvPreviewArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CSV Output Preview")
                    .font(.headline)

                Spacer()

                Button(action: copyToClipboard) {
                    Label(isCopied ? "Copied!" : "Copy CSV", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .disabled(csvPreview.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                Text(csvPreview.isEmpty ? "// Processing preview..." : csvPreview)
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
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx")!].compactMap { $0 }

        if panel.runModal() == .OK, let url = panel.url {
            loadFile(at: url)
        }
    }

    private func loadFile(at url: URL) {
        do {
            let data = try FileParser.parseFile(at: url, maxPreviewRows: 100)
            fileData = data

            let baseName = url.deletingPathExtension().lastPathComponent
            outputFileName = "\(baseName).csv"
            statusMessage = nil

            generateCSVPreview(xlsxURL: url)
        } catch {
            statusMessage = "Failed to parse Excel file: \(error.localizedDescription)"
        }
    }

    private func resetFile() {
        fileData = nil
        csvPreview = ""
        convertedCSVURL = nil
        outputFileName = ""
        statusMessage = nil
    }

    private func generateCSVPreview(xlsxURL: URL) {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tempCSVURL = try XLSXToCSVConverter.convertToCSV(xlsxURL: xlsxURL)
                let text = try String(contentsOf: tempCSVURL, encoding: .utf8)
                
                // Truncate preview if very long
                let lines = text.components(separatedBy: .newlines)
                let previewText = lines.prefix(100).joined(separator: "\n") + (lines.count > 100 ? "\n... [\(lines.count - 100) more lines]" : "")

                DispatchQueue.main.async {
                    convertedCSVURL = tempCSVURL
                    csvPreview = previewText
                    isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    csvPreview = "// Error converting Excel file: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }

    private func copyToClipboard() {
        guard let tempURL = convertedCSVURL, let fullText = try? String(contentsOf: tempURL, encoding: .utf8) else {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(csvPreview, forType: .string)
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)

        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }

    private func exportCSV() {
        guard let tempURL = convertedCSVURL else { return }
        isProcessing = true
        statusMessage = "Exporting CSV..."

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fullContent = try String(contentsOf: tempURL, encoding: .utf8)
                let filename = outputFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "export.csv" : outputFileName
                let savedURL = try settings.saveOutputFile(filename: filename, content: fullContent)

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
