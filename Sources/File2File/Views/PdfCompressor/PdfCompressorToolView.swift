import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit

public struct PdfCompressorToolView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    // Items state
    @State private var pdfItems: [PdfCompressorItem] = []
    @State private var selectedItemId: UUID? = nil
    
    // Compression Options State
    @State private var preset: PdfCompressorPreset = .medium
    @State private var qualityPercent: Double = 55.0
    @State private var targetDpi: PdfDpiLimit = .dpi150
    @State private var stripMetadata: Bool = true
    @State private var outputSuffix: String = "_compressed"
    @State private var overwriteOriginal: Bool = false
    @State private var useCustomFolder: Bool = false
    @State private var customOutputFolder: URL? = nil
    
    // Status & Drawer State
    @State private var isProcessing: Bool = false
    @State private var statusMessage: String? = nil
    @State private var isShowingPreviewDrawer: Bool = false
    @State private var previewItem: PdfCompressorItem? = nil
    
    public init() {}
    
    private var selectedItem: PdfCompressorItem? {
        pdfItems.first(where: { $0.id == selectedItemId })
    }
    
    private var totalOriginalBytes: Int64 {
        pdfItems.reduce(0) { $0 + $1.originalSize }
    }
    
    private var totalCompressedBytes: Int64 {
        pdfItems.reduce(0) { $0 + ($1.compressedSize ?? 0) }
    }
    
    private var totalSavingsPercent: Double? {
        let compressedCount = pdfItems.filter { $0.compressedSize != nil }.count
        guard compressedCount > 0, totalOriginalBytes > 0 else { return nil }
        let rawCompressedTotal = pdfItems.reduce(0) { $0 + ($1.compressedSize ?? $1.originalSize) }
        let diff = Double(totalOriginalBytes - rawCompressedTotal)
        return max(0, (diff / Double(totalOriginalBytes)) * 100.0)
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
            
            if pdfItems.isEmpty {
                emptyDropZoneView
                    .padding(24)
            } else {
                mainWorkspaceView
            }
        }
        .sheet(isPresented: $isShowingPreviewDrawer) {
            if let item = previewItem {
                pdfPreviewSheet(for: item)
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.ellipsis")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("PDF Compressor")
                        .font(.title2.bold())
                }
                
                Text("Compress PDF documents by downsampling images and optimizing stream data.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !pdfItems.isEmpty {
                HStack(spacing: 10) {
                    Button(action: addPdfFiles) {
                        Label("Add", systemImage: "plus")
                    }
                    .disabled(isProcessing)
                    .help("Add PDF files")
                    
                    Button(action: clearAll) {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(isProcessing)
                    .help("Clear all PDF files")
                    
                    Button(action: compressAll) {
                        if isProcessing {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Processing...")
                            }
                        } else {
                            Label("Compress", systemImage: "arrow.down.doc.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                    .help("Compress all PDF files")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Empty Drop Zone View
    
    private var emptyDropZoneView: some View {
        VStack {
            Spacer()
            FileDropZoneCardView(
                title: "Drag & Drop PDF files here",
                subtitle: "Select single or multiple PDF documents to compress",
                iconName: "doc.richtext.fill",
                buttonTitle: "Browse PDFs...",
                onBrowse: addPdfFiles,
                onDropFiles: handleDroppedUrls
            )
            .frame(maxWidth: 560)
            Spacer()
        }
    }
    
    // MARK: - Main Workspace Layout
    
    private var mainWorkspaceView: some View {
        HStack(spacing: 0) {
            // Settings Sidebar
            settingsSidebarView
                .frame(width: 300)
            
            Divider()
            
            // Batch Table & Summary View
            VStack(spacing: 0) {
                batchTableView
                
                Divider()
                
                summaryFooterView
            }
        }
    }
    
    // MARK: - Settings Sidebar
    
    private var settingsSidebarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Compression Preset
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preset Quality")
                        .font(.headline)
                    
                    Picker("Preset", selection: $preset) {
                        ForEach(PdfCompressorPreset.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: preset) { _, newPreset in
                        if newPreset != .custom {
                            qualityPercent = newPreset.defaultQuality
                            targetDpi = newPreset.defaultDpi
                        }
                    }
                }
                
                Divider()
                
                // Quality Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("JPEG Quality")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(qualityPercent))%")
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $qualityPercent, in: 10...100, step: 5)
                        .onChange(of: qualityPercent) { _, _ in
                            preset = .custom
                        }
                    
                    Text("Lower quality produces smaller PDF sizes.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Target Resolution (DPI)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Resolution (DPI)")
                        .font(.subheadline.bold())
                    
                    Picker("Resolution Limit", selection: $targetDpi) {
                        ForEach(PdfDpiLimit.allCases) { dpi in
                            Text(dpi.rawValue).tag(dpi)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: targetDpi) { _, _ in
                        preset = .custom
                    }
                    
                    Text("Downsamples high-resolution embedded page images.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Export Settings
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Naming & Folder")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Filename Suffix")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        TextField("Suffix", text: $outputSuffix)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Toggle("Use Custom Output Folder", isOn: $useCustomFolder)
                        .onChange(of: useCustomFolder) { _, enabled in
                            if enabled && customOutputFolder == nil {
                                chooseCustomFolder()
                            }
                        }
                    
                    if useCustomFolder {
                        HStack {
                            Text(customOutputFolder?.path ?? "No folder chosen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button("Browse") {
                                chooseCustomFolder()
                            }
                            .font(.caption)
                            .help("Choose custom output folder")
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }
    
    // MARK: - Batch Table View
    
    private var batchTableView: some View {
        List {
            ForEach(pdfItems) { item in
                batchRowView(for: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItemId = item.id
                    }
            }
            .onDelete(perform: removeItems)
        }
        .listStyle(.inset)
    }
    
    private func batchRowView(for item: PdfCompressorItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(item.pageCount) \(item.pageCount == 1 ? "page" : "pages")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(item.formattedOriginalSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Compression status & metrics
            switch item.status {
            case .idle:
                Text("Ready")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
                
            case .processing(let progress):
                HStack(spacing: 6) {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
                
            case .completed:
                HStack(spacing: 10) {
                    if let compressedSizeStr = item.formattedCompressedSize {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(compressedSizeStr)
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            
                            if let savings = item.savingsRatioPercent {
                                Text(String(format: "-%.1f%%", savings))
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
            case .failed(let msg):
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Failed")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }
                .help(msg)
            }
            
            // Action buttons
            HStack(spacing: 6) {
                if let compressedUrl = item.compressedUrl {
                    Button(action: {
                        NSWorkspace.shared.activateFileViewerSelecting([compressedUrl])
                    }) {
                        Image(systemName: "folder")
                            .font(.subheadline)
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
                }
                
                Button(action: {
                    previewItem = item
                    isShowingPreviewDrawer = true
                }) {
                    Image(systemName: "eye")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .help("Preview PDF")
                
                Button(action: {
                    removeSingleItem(item)
                }) {
                    Image(systemName: "xmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove")
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Summary Footer View
    
    private var summaryFooterView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pdfItems.count) PDF \(pdfItems.count == 1 ? "file" : "files") added")
                    .font(.subheadline.bold())
                
                HStack(spacing: 12) {
                    Text("Original: \(ByteCountFormatter.string(fromByteCount: totalOriginalBytes, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if totalCompressedBytes > 0 {
                        Text("Compressed: \(ByteCountFormatter.string(fromByteCount: totalCompressedBytes, countStyle: .file))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let savings = totalSavingsPercent, savings > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundColor(.green)
                    Text(String(format: "Total Saved: %.1f%%", savings))
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - PDF Preview Sheet Drawer
    
    private func pdfPreviewSheet(for item: PdfCompressorItem) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                    Text("Pages: \(item.pageCount) • Size: \(item.formattedCompressedSize ?? item.formattedOriginalSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    isShowingPreviewDrawer = false
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            PdfKitViewWrapper(url: item.compressedUrl ?? item.url)
        }
        .frame(minWidth: 600, minHeight: 700)
    }
    
    // MARK: - Helper Actions
    
    private func addPdfFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK {
            handleDroppedUrls(panel.urls)
        }
    }
    
    private func handleDroppedUrls(_ urls: [URL]) {
        let pdfUrls = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        for url in pdfUrls {
            if !pdfItems.contains(where: { $0.url == url }) {
                if let newItem = PdfCompressorEngine.loadPdfItem(from: url) {
                    pdfItems.append(newItem)
                }
            }
        }
    }
    
    private func removeSingleItem(_ item: PdfCompressorItem) {
        pdfItems.removeAll(where: { $0.id == item.id })
    }
    
    private func removeItems(at offsets: IndexSet) {
        pdfItems.remove(atOffsets: offsets)
    }
    
    private func clearAll() {
        pdfItems.removeAll()
        selectedItemId = nil
    }
    
    private func chooseCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            customOutputFolder = panel.url
        }
    }
    
    private func compressAll() {
        guard !pdfItems.isEmpty else { return }
        isProcessing = true
        
        let options = PdfCompressorOptions(
            preset: preset,
            qualityPercent: qualityPercent,
            targetDpi: targetDpi,
            stripMetadata: stripMetadata,
            outputSuffix: outputSuffix,
            overwriteOriginal: overwriteOriginal,
            customOutputFolder: useCustomFolder ? customOutputFolder : nil
        )
        
        Task {
            for index in pdfItems.indices {
                let item = pdfItems[index]
                pdfItems[index].status = .processing(progress: 0.0)
                
                do {
                    let result = try await PdfCompressorEngine.compressPdf(
                        item: item,
                        options: options,
                        progressHandler: { progress in
                            DispatchQueue.main.async {
                                if index < pdfItems.count {
                                    pdfItems[index].status = .processing(progress: progress)
                                }
                            }
                        }
                    )
                    
                    DispatchQueue.main.async {
                        if index < pdfItems.count {
                            pdfItems[index].compressedUrl = result.outputUrl
                            pdfItems[index].compressedSize = result.compressedSize
                            pdfItems[index].status = .completed
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        if index < pdfItems.count {
                            pdfItems[index].status = .failed(error.localizedDescription)
                            pdfItems[index].errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                isProcessing = false
            }
        }
    }
}

// MARK: - PDFKit NSViewRepresentable Wrapper

private struct PdfKitViewWrapper: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        if nsView.document?.documentURL != url {
            nsView.document = PDFDocument(url: url)
        }
    }
}
