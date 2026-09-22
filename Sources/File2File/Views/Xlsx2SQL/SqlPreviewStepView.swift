import SwiftUI
import AppKit

public struct SqlPreviewStepView: View {
    let tableName: String
    let mappings: [ColumnMapping]
    let fileData: FileData
    let onPrevStep: () -> Void

    @ObservedObject private var settings = AppSettings.shared
    @State private var options = GeneratorOptions()
    @State private var sqlOutput: String = ""
    @State private var totalBatches: Int = 0
    @State private var totalRowsProcessed: Int = 0
    @State private var isCopied: Bool = false
    @State private var statusBannerMessage: String? = nil
    @State private var statusIsError: Bool = false

    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var processedRowsCount: Int = 0

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Bar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SQL Generator & Export")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Generated PostgreSQL statements for table **\(tableName)**.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button(action: copyToClipboard) {
                        Label(isCopied ? "Copied!" : "Copy Preview", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isExporting)

                    Button(action: quickSaveToOutputDirectory) {
                        Label("Quick Export to Output Dir", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isExporting)
                    .help("Save directly to: \(settings.outputDirectoryPath)")

                    Button(action: saveToFile) {
                        Label("Export .sql File...", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(isExporting)
                }
            }

            // Export Progress Banner
            if isExporting {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        ProgressView(value: exportProgress)
                            .progressViewStyle(.linear)
                        Text("\(processedRowsCount) / \(fileData.totalRows) rows (\(Int(exportProgress * 100))%)")
                            .font(.caption.bold())
                            .foregroundColor(.accentColor)
                    }
                    Text("Streaming SQL export to disk sequentially...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.1)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor.opacity(0.3), lineWidth: 1))
            }

            // Status notification banner if any
            if let message = statusBannerMessage {
                HStack {
                    Image(systemName: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundColor(statusIsError ? .red : .green)
                    Text(message)
                        .font(.callout)
                    Spacer()
                    Button("Open Folder") {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settings.outputDirectoryPath)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(statusIsError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                )
            }

            // Options Bar Control Strip
            HStack(spacing: 20) {
                Toggle("COPY FROM STDIN", isOn: $options.useCopyFormat)
                    .toggleStyle(.checkbox)
                    .onChange(of: options.useCopyFormat) { _ in generate() }

                if !options.useCopyFormat {
                    Divider()
                        .frame(height: 16)

                    Toggle("ON CONFLICT DO NOTHING", isOn: $options.onConflictDoNothing)
                        .toggleStyle(.checkbox)
                        .onChange(of: options.onConflictDoNothing) { _ in generate() }

                    Divider()
                        .frame(height: 16)

                    HStack(spacing: 8) {
                        Text("Batch Size:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextField("500", value: $options.batchSize, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 65)
                            .onChange(of: options.batchSize) { _ in generate() }
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.green)
                    Text("\(fileData.totalRows) dataset rows • \(fileData.headers.count) cols")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
            )

            // SQL Code Preview Editor
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("GENERATED PREVIEW OUTPUT (FIRST \(fileData.previewRows.count) ROWS)")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(sqlOutput.split(separator: "\n").count) lines previewed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                TextEditor(text: .constant(sqlOutput))
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 1)
                    )
                    .frame(minHeight: 260)
            }

            // Footer Navigation
            HStack {
                Button(action: onPrevStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to Column Mapping")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isExporting)

                Spacer()

                Text("Destination: \(settings.outputDirectoryPath)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .onAppear {
            generate()
            if settings.autoSaveToOutputDirectory {
                quickSaveToOutputDirectory()
            }
        }
    }

    private func generate() {
        var currentOptions = options
        currentOptions.customDescription = settings.customDescription

        let result = SQLGenerator.generateSQL(
            tableName: tableName,
            mappings: mappings,
            rows: fileData.previewRows,
            options: currentOptions
        )
        sqlOutput = result.sql
        totalBatches = result.totalBatches
        totalRowsProcessed = result.totalRowsProcessed
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(sqlOutput, forType: .string)
        withAnimation {
            isCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                isCopied = false
            }
        }
    }

    private func quickSaveToOutputDirectory() {
        let filename = "\(tableName).sql"
        let savedURL = settings.outputDirectoryURL.appendingPathComponent(filename)
        performAsyncExport(to: savedURL)
    }

    private func saveToFile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.init(filenameExtension: "sql")!]
        savePanel.nameFieldStringValue = "\(tableName).sql"
        savePanel.directoryURL = settings.outputDirectoryURL

        if savePanel.runModal() == .OK, let url = savePanel.url {
            performAsyncExport(to: url)
        }
    }

    private func performAsyncExport(to url: URL) {
        isExporting = true
        exportProgress = 0.0
        processedRowsCount = 0
        statusBannerMessage = nil

        var currentOptions = options
        currentOptions.customDescription = settings.customDescription

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try SQLGenerator.exportSQLToFile(
                    tableName: tableName,
                    mappings: mappings,
                    fileData: fileData,
                    options: currentOptions,
                    outputURL: url,
                    progress: { processed, total in
                        DispatchQueue.main.async {
                            self.processedRowsCount = processed
                            self.exportProgress = total > 0 ? Double(processed) / Double(total) : 1.0
                        }
                    }
                )
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.statusIsError = false
                    self.statusBannerMessage = "Successfully exported \(result.totalRowsProcessed) rows (\(result.totalBatches) batches) to '\(url.path)'"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.statusIsError = true
                    self.statusBannerMessage = "Export failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
