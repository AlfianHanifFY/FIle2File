import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct ImageCompressorToolView: View {
    @State private var imageItems: [ImageItem] = []
    @State private var selectedItemId: UUID? = nil
    
    // Compression Settings
    @State private var mode: CompressionTargetMode = .byPercentage
    @State private var qualityPercent: Double = 75.0
    @State private var targetSizeValue: String = "500"
    @State private var targetSizeUnit: TargetSizeUnit = .kb
    @State private var outputFormat: ImageOutputFormat = .auto
    @State private var enableMaxDimension: Bool = false
    @State private var maxDimensionValue: String = "1920"
    
    @State private var isProcessingAll: Bool = false
    @State private var statusMessage: String? = nil
    
    public init() {}
    
    private var selectedItem: ImageItem? {
        imageItems.first(where: { $0.id == selectedItemId })
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
            
            if imageItems.isEmpty {
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
                    Image(systemName: "photo.stack")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("Image Compressor")
                        .font(.title2.bold())
                }
                
                Text("Compress images by target quality percentage or exact file size.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !imageItems.isEmpty {
                HStack(spacing: 10) {
                    Button(action: addMoreFiles) {
                        Label("Add Images", systemImage: "plus.circle")
                    }
                    
                    Button(action: clearAll) {
                        Label("Clear All", systemImage: "trash")
                    }
                    .foregroundColor(.red)
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
                Text("Select Image Files")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Choose or drag & drop one or more images to compress.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            FileDropZoneCardView(
                title: "Drag & Drop Image Files Here",
                subtitle: "Supports JPEG, PNG, HEIC, WebP, TIFF, and BMP images",
                iconName: "photo.on.rectangle.angled",
                buttonTitle: "Browse Image Files...",
                onBrowse: openFilePicker,
                onDropFiles: { urls in
                    self.loadURLs(urls)
                }
            )

            Spacer()
        }
    }
    
    // MARK: - Main Workspace (Controls + Sidebar + Preview)
    
    private var mainWorkspaceView: some View {
        VStack(spacing: 0) {
            controlPanelCard
                .padding(16)
            
            Divider()
            
            HStack(spacing: 0) {
                if imageItems.count > 1 {
                    batchSidebarView
                        .frame(width: 240)
                    Divider()
                }
                
                VStack(spacing: 0) {
                    if let item = selectedItem {
                        ImagePreviewComparisonView(item: item)
                            .padding(16)
                    } else {
                        Text("Select an image to preview")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            bottomActionBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    // MARK: - Control Panel Card
    
    private var controlPanelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            topControlRow
            bottomControlRow
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
    
    private var topControlRow: some View {
        HStack(spacing: 20) {
            // Mode Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("COMPRESSION MODE")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                
                Picker("Mode", selection: $mode) {
                    ForEach(CompressionTargetMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 185)
            }
            
            Divider()
                .frame(height: 38)
            
            // Target Controls
            if mode == .byPercentage {
                percentageControlView
            } else {
                targetSizeControlView
            }
            
            Divider()
                .frame(height: 38)
            
            // Output Format Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("OUTPUT FORMAT")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                
                Picker("Format", selection: $outputFormat) {
                    ForEach(ImageOutputFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 140)
            }
            
            Spacer(minLength: 0)
        }
    }
    
    private var bottomControlRow: some View {
        HStack(spacing: 14) {
            Toggle("Limit Max Dimension:", isOn: $enableMaxDimension)
                .font(.caption)
            
            if enableMaxDimension {
                HStack(spacing: 6) {
                    TextField("1920", text: $maxDimensionValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 65)
                        .font(.caption)
                    
                    Text("px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        Button("1080 px (HD)") { maxDimensionValue = "1080"; triggerCompressionAll() }
                        Button("1440 px (2K)") { maxDimensionValue = "1440"; triggerCompressionAll() }
                        Button("1920 px (Full HD)") { maxDimensionValue = "1920"; triggerCompressionAll() }
                        Button("2560 px (QHD)") { maxDimensionValue = "2560"; triggerCompressionAll() }
                    } label: {
                        Text("Presets")
                            .font(.caption)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            
            Spacer()
            
            Button(action: triggerCompressionAll) {
                Label(isProcessingAll ? "Compressing..." : "Apply Compression", systemImage: "bolt.fill")
                    .font(.headline)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessingAll)
        }
    }
    
    // MARK: - Sub Controls
    
    private var percentageControlView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TARGET QUALITY / PERCENTAGE")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(qualityPercent))%")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
            }
            
            HStack(spacing: 10) {
                Slider(value: $qualityPercent, in: 5...100, step: 1) { editing in
                    if !editing {
                        triggerCompressionAll()
                    }
                }
                .frame(width: 150)
                
                Menu {
                    Button("Maximum Quality (95%)") { qualityPercent = 95; triggerCompressionAll() }
                    Button("High Quality (85%)") { qualityPercent = 85; triggerCompressionAll() }
                    Button("Balanced (75%)") { qualityPercent = 75; triggerCompressionAll() }
                    Button("Low / Small Size (50%)") { qualityPercent = 50; triggerCompressionAll() }
                } label: {
                    Text("Presets")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }
    
    private var targetSizeControlView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TARGET FILE SIZE")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                TextField("500", text: $targetSizeValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                
                Picker("Unit", selection: $targetSizeUnit) {
                    ForEach(TargetSizeUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 65)
                
                Menu {
                    Button("200 KB") { targetSizeValue = "200"; targetSizeUnit = .kb; triggerCompressionAll() }
                    Button("500 KB") { targetSizeValue = "500"; targetSizeUnit = .kb; triggerCompressionAll() }
                    Button("1 MB") { targetSizeValue = "1"; targetSizeUnit = .mb; triggerCompressionAll() }
                    Button("2 MB") { targetSizeValue = "2"; targetSizeUnit = .mb; triggerCompressionAll() }
                } label: {
                    Text("Presets")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }
    
    // MARK: - Batch Sidebar View
    
    private var batchSidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("IMAGES (\(imageItems.count))")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(12)
            
            Divider()
            
            List(selection: $selectedItemId) {
                ForEach(imageItems) { item in
                    HStack(spacing: 10) {
                        if let compData = item.compressedData, let nsImg = NSImage(data: compData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .cornerRadius(6)
                        } else if let nsImg = NSImage(data: item.originalData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 36, height: 36)
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.caption.bold())
                                .lineLimit(1)
                            
                            HStack(spacing: 4) {
                                Text(item.formattedOriginalSize)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                if let compSize = item.formattedCompressedSize as String?, item.compressedData != nil {
                                    Text("→ \(compSize)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .tag(item.id)
                }
            }
            .listStyle(.sidebar)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack {
            if !imageItems.isEmpty {
                let totalOrig = imageItems.reduce(0) { $0 + $1.originalSize }
                let totalComp = imageItems.reduce(0) { $0 + ($1.compressedSize ?? $1.originalSize) }
                let totalSaved = max(0, totalOrig - totalComp)
                
                HStack(spacing: 12) {
                    Text("Total Original: \(ByteCountFormatter.string(fromByteCount: totalOrig, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Compressed: \(ByteCountFormatter.string(fromByteCount: totalComp, countStyle: .file))")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                    
                    if totalSaved > 0 {
                        Text("Saved: \(ByteCountFormatter.string(fromByteCount: totalSaved, countStyle: .file))")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if selectedItem?.compressedData != nil {
                    Button(action: saveSingleSelected) {
                        Label("Save Current Image...", systemImage: "square.and.arrow.down")
                    }
                }
                
                if imageItems.contains(where: { $0.compressedData != nil }) {
                    Button(action: saveAllImages) {
                        Label("Save All Images...", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    // MARK: - Actions & Logic
    
    private func currentConfig() -> ImageCompressionConfig {
        let parsedTargetVal = Double(targetSizeValue.replacingOccurrences(of: ",", with: ".")) ?? 500.0
        let targetBytes = Int64(parsedTargetVal * Double(targetSizeUnit.bytesMultiplier))
        let maxDim = enableMaxDimension ? Int(maxDimensionValue) : nil
        
        return ImageCompressionConfig(
            mode: mode,
            qualityPercent: qualityPercent,
            targetSizeBytes: targetBytes,
            outputFormat: outputFormat,
            maxDimension: maxDim
        )
    }
    
    private func triggerCompressionAll() {
        guard !imageItems.isEmpty else { return }
        
        let config = currentConfig()
        isProcessingAll = true
        
        Task {
            var updatedList: [ImageItem] = []
            for item in imageItems {
                let compressed = await ImageCompressor.compress(item, config: config)
                updatedList.append(compressed)
            }
            
            await MainActor.run {
                self.imageItems = updatedList
                self.isProcessingAll = false
            }
        }
    }
    
    private func addMoreFiles() {
        openFilePicker()
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .webP, .tiff, .bmp]
        
        if panel.runModal() == .OK {
            loadURLs(panel.urls)
        }
    }
    
    private func loadURLs(_ urls: [URL]) {
        var newItems: [ImageItem] = []
        for url in urls {
            if let item = ImageCompressor.loadItem(from: url) {
                newItems.append(item)
            }
        }
        
        guard !newItems.isEmpty else { return }
        
        self.imageItems.append(contentsOf: newItems)
        if selectedItemId == nil || selectedItem == nil {
            selectedItemId = imageItems.first?.id
        }
        
        triggerCompressionAll()
    }
    
    private func handleDroppedProviders(_ providers: [NSItemProvider]) {
        providers.extractURLs { urls in
            guard !urls.isEmpty else { return }
            self.loadURLs(urls)
        }
    }

    
    private func clearAll() {
        imageItems.removeAll()
        selectedItemId = nil
    }
    
    private func saveSingleSelected() {
        guard let item = selectedItem, let compressedData = item.compressedData else { return }
        
        let targetFormat = resolveFormat(outputFormat, originalFormat: item.originalFormat)
        let defaultName = (item.name as NSString).deletingPathExtension + "_compressed." + targetFormat.fileExtension
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        if let type = UTType(targetFormat.utiType) {
            panel.allowedContentTypes = [type]
        }
        
        if panel.runModal() == .OK, let saveURL = panel.url {
            try? compressedData.write(to: saveURL)
        }
    }
    
    private func saveAllImages() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.title = "Select Destination Folder to Save Compressed Images"
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            for item in imageItems {
                guard let compressedData = item.compressedData else { continue }
                let targetFormat = resolveFormat(outputFormat, originalFormat: item.originalFormat)
                let name = (item.name as NSString).deletingPathExtension + "_compressed." + targetFormat.fileExtension
                let fileURL = folderURL.appendingPathComponent(name)
                try? compressedData.write(to: fileURL)
            }
        }
    }
    
    private func resolveFormat(_ format: ImageOutputFormat, originalFormat: String) -> ImageOutputFormat {
        if format != .auto { return format }
        let upper = originalFormat.uppercased()
        if upper.contains("PNG") { return .png }
        if upper.contains("HEIC") || upper.contains("HEIF") { return .heic }
        return .jpeg
    }
}
