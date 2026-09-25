import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit

public struct Scan2PdfToolView: View {
    @State private var items: [ScanPageItem] = []
    @State private var globalPreset: ScanPreset = .highContrastBW
    @State private var selectedItemId: UUID? = nil
    
    @State private var options = Scan2PdfOptions()
    @State private var isProcessing: Bool = false
    @State private var exportResult: PdfExportResult? = nil
    @State private var showSuccessAlert: Bool = false
    @State private var errorMessage: String? = nil
    
    @StateObject private var cameraManager = CameraScanManager()
    @State private var showCameraScanner: Bool = false
    
    @ObservedObject private var settings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
            
            if items.isEmpty {
                emptyDropZone
            } else {
                mainContentSplitView
            }
        }
        .sheet(isPresented: $showCameraScanner) {
            CameraScannerView(manager: cameraManager) { capturedImages in
                addCapturedCameraImages(capturedImages)
            }
        }
        .alert("PDF Exported Successfully", isPresented: $showSuccessAlert) {
            Button("Open") {
                if let res = exportResult {
                    let folder = settings.outputDirectoryURL
                    let fileURL = folder.appendingPathComponent(res.name)
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }
            }
            Button("OK", role: .cancel) {}
        } message: {
            if let res = exportResult {
                Text("Saved '\(res.name)' (\(res.pageCount) pages) to \(settings.outputDirectoryPath).")
            } else {
                Text("Export completed.")
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("Scan to PDF")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Text("Refine paper scan photos with contrast filters and merge into a structured PDF document.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !items.isEmpty {
                Button(action: resetAll) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Clear all scanned pages")
                
                Button(action: { showCameraScanner = true }) {
                    Label("Scan", systemImage: "camera")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Scan document using camera")
                
                Button(action: addMoreFiles) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Add image files from disk")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Empty State Drop Zone
    
    private var emptyDropZone: some View {
        VStack(spacing: 16) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 38))
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 6) {
                Text("Drop Paper Scans or Document Photos Here")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("Scan paper using your laptop camera or drop PNG, JPEG, HEIC, TIFF image files.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            
            HStack(spacing: 12) {
                Button(action: { showCameraScanner = true }) {
                    Label("Scan", systemImage: "camera.fill")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help("Scan document with camera")
                
                Button(action: addMoreFiles) {
                    Label("Browse", systemImage: "photo.on.rectangle")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Select image files from disk")
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
            handleDroppedProviders(providers)
        }
    }
    
    // MARK: - Main Split View
    
    private var selectedItem: ScanPageItem? {
        items.first(where: { $0.id == selectedItemId }) ?? items.first
    }
    
    private var mainContentSplitView: some View {
        HSplitView {
            // Left Panel: Batch Page Grid & Global Filter Selector
            VStack(spacing: 0) {
                globalFilterBar
                Divider()
                pageGridList
            }
            .frame(minWidth: 380, idealWidth: 440)
            
            // Right Panel: Page Fine-Tuning & Export Config
            VStack(spacing: 0) {
                if let currentItem = selectedItem {
                    pageInspectorView(for: currentItem)
                } else {
                    Text("Select a page from the grid to inspect")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Divider()
                exportConfigurationPanel
            }
            .frame(minWidth: 320, idealWidth: 360)
        }
    }
    
    // MARK: - Global Filter Bar
    
    private var globalFilterBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GLOBAL FILTER PRESET")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(items.count) \(items.count == 1 ? "page" : "pages")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 6) {
                ForEach(ScanPreset.allCases) { preset in
                    Button(action: {
                        globalPreset = preset
                        applyPresetToAll(preset)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: preset.icon)
                                .font(.caption)
                            Text(preset.rawValue)
                                .font(.caption)
                                .fontWeight(globalPreset == preset ? .semibold : .regular)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(globalPreset == preset ? Color.accentColor : Color.secondary.opacity(0.12))
                        )
                        .foregroundColor(globalPreset == preset ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
    }
    
    // MARK: - Page Grid List
    
    private var pageGridList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 170), spacing: 12)], spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    pageCardView(item: item, pageIndex: index + 1)
                }
            }
            .padding(12)
        }
        .onDrop(of: [.fileURL, .image], isTargeted: nil) { providers in
            handleDroppedProviders(providers)
        }
    }
    
    private func pageCardView(item: ScanPageItem, pageIndex: Int) -> some View {
        let isSelected = selectedItem?.id == item.id
        
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .topLeading) {
                    if let thumb = item.processedThumbnail {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 160)
                            .cornerRadius(4)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    } else {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 160)
                            .overlay(ProgressView())
                    }
                    
                    // Page Badge
                    Text("\(pageIndex)")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .padding(6)
                }
                
                // Quick Delete
                Button(action: { removeItem(item) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .padding(4)
            }
            
            // Preset Label & Actions
            HStack(spacing: 4) {
                Button(action: { rotateItem(item, degrees: -90) }) {
                    Image(systemName: "rotate.left")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Spacer()
                
                Text(item.preset.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { rotateItem(item, degrees: 90) }) {
                    Image(systemName: "rotate.right")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }
            
            // Move buttons
            HStack(spacing: 4) {
                Button(action: { moveItemUp(item) }) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(pageIndex == 1)
                
                Text(item.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
                
                Button(action: { moveItemDown(item) }) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(pageIndex == items.count)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture {
            selectedItemId = item.id
        }
    }
    
    // MARK: - Page Inspector View
    
    private func pageInspectorView(for item: ScanPageItem) -> some View {
        VStack(spacing: 12) {
            // Inspector Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Page Settings & Inspection")
                        .font(.subheadline.bold())
                    Text(item.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Per-Page Preset Picker
                Picker("Preset", selection: Binding(
                    get: { item.preset },
                    set: { newPreset in updateItemPreset(item, preset: newPreset) }
                )) {
                    ForEach(ScanPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 140)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            
            // Full Resolution Image Preview
            ZStack {
                Color(NSColor.controlBackgroundColor).opacity(0.5)
                
                if let previewImage = Scan2PdfEngine.processImage(
                    item.originalImage,
                    preset: item.preset,
                    rotationDegrees: item.rotationDegrees,
                    fineTuning: item.fineTuning
                ) {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(12)
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Fine-Tuning Sliders
            VStack(alignment: .leading, spacing: 8) {
                Text("FINE-TUNING ADJUSTMENTS")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Brightness: \(Int(item.fineTuning.brightness * 100))%")
                            .font(.caption2)
                        Slider(value: Binding(
                            get: { item.fineTuning.brightness },
                            set: { val in updateItemFineTuning(item, brightness: val) }
                        ), in: -0.5...0.5, step: 0.05)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contrast: \(String(format: "%.1fx", item.fineTuning.contrast))")
                            .font(.caption2)
                        Slider(value: Binding(
                            get: { item.fineTuning.contrast },
                            set: { val in updateItemFineTuning(item, contrast: val) }
                        ), in: 0.5...2.5, step: 0.1)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sharpness: \(String(format: "%.1f", item.fineTuning.sharpness))")
                            .font(.caption2)
                        Slider(value: Binding(
                            get: { item.fineTuning.sharpness },
                            set: { val in updateItemFineTuning(item, sharpness: val) }
                        ), in: 0.0...2.0, step: 0.1)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Export Configuration Panel
    
    private var exportConfigurationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PDF OUTPUT OPTIONS")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Filename")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Scanned_Document.pdf", text: $options.pdfFileName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Page Size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Picker("", selection: $options.pageSize) {
                        ForEach(PdfPageSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality / Size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Picker("", selection: $options.compressionQuality) {
                        ForEach(ScanPdfCompressionQuality.allCases) { quality in
                            Text(quality.label).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save Directory: \(settings.outputDirectoryPath)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: generateAndSavePdf) {
                    if isProcessing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Processing...")
                        }
                    } else {
                        Label("Export", systemImage: "arrow.down.doc.fill")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .help("Export merged PDF document")
                .disabled(items.isEmpty || isProcessing)
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helper Actions
    
    private func resetAll() {
        items.removeAll()
        selectedItemId = nil
        exportResult = nil
    }
    
    private func addMoreFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.image, .png, .jpeg, .heic, .tiff]
        
        if panel.runModal() == .OK {
            loadFiles(urls: panel.urls)
        }
    }
    
    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        var foundURLs: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    foundURLs.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !foundURLs.isEmpty {
                self.loadFiles(urls: foundURLs)
            }
        }
        return true
    }
    
    private func loadFiles(urls: [URL]) {
        for url in urls {
            if let scanItem = Scan2PdfEngine.loadScanItem(from: url, defaultPreset: globalPreset) {
                items.append(scanItem)
            }
        }
        if selectedItemId == nil, let first = items.first {
            selectedItemId = first.id
        }
    }
    
    private func applyPresetToAll(_ preset: ScanPreset) {
        for i in 0..<items.count {
            items[i].preset = preset
            items[i].processedThumbnail = Scan2PdfEngine.generateThumbnail(for: items[i])
        }
    }
    
    private func updateItemPreset(_ item: ScanPageItem, preset: ScanPreset) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].preset = preset
            items[idx].processedThumbnail = Scan2PdfEngine.generateThumbnail(for: items[idx])
        }
    }
    
    private func updateItemFineTuning(_ item: ScanPageItem, brightness: Double? = nil, contrast: Double? = nil, sharpness: Double? = nil) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            if let b = brightness { items[idx].fineTuning.brightness = b }
            if let c = contrast { items[idx].fineTuning.contrast = c }
            if let s = sharpness { items[idx].fineTuning.sharpness = s }
            items[idx].processedThumbnail = Scan2PdfEngine.generateThumbnail(for: items[idx])
        }
    }
    
    private func rotateItem(_ item: ScanPageItem, degrees: Int) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].rotationDegrees = (items[idx].rotationDegrees + degrees) % 360
            items[idx].processedThumbnail = Scan2PdfEngine.generateThumbnail(for: items[idx])
        }
    }
    
    private func removeItem(_ item: ScanPageItem) {
        items.removeAll(where: { $0.id == item.id })
        if selectedItemId == item.id {
            selectedItemId = items.first?.id
        }
    }
    
    private func moveItemUp(_ item: ScanPageItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }), idx > 0 else { return }
        items.swapAt(idx, idx - 1)
    }
    
    private func moveItemDown(_ item: ScanPageItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }), idx < items.count - 1 else { return }
        items.swapAt(idx, idx + 1)
    }
    
    private func generateAndSavePdf() {
        guard !items.isEmpty else { return }
        isProcessing = true
        
        Task {
            if let result = await Scan2PdfEngine.generatePdfDocument(items: items, options: options) {
                let outputDir = settings.outputDirectoryURL
                try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
                let destinationURL = outputDir.appendingPathComponent(result.name)
                
                do {
                    try result.data.write(to: destinationURL)
                    await MainActor.run {
                        self.exportResult = result
                        self.isProcessing = false
                        self.showSuccessAlert = true
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = "Failed to write PDF: \(error.localizedDescription)"
                        self.isProcessing = false
                    }
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Failed to generate PDF document."
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func addCapturedCameraImages(_ images: [NSImage]) {
        for (idx, img) in images.enumerated() {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("CameraScan_\(Int(Date().timeIntervalSince1970))_\(idx).png")
            var item = ScanPageItem(
                url: tempURL,
                name: "Camera Scan \(items.count + 1)",
                originalSize: 0,
                originalImage: img,
                preset: globalPreset
            )
            item.processedThumbnail = Scan2PdfEngine.generateThumbnail(for: item)
            items.append(item)
        }
        if selectedItemId == nil, let first = items.first {
            selectedItemId = first.id
        }
    }
}
