import SwiftUI
import AppKit
import UniformTypeIdentifiers

@available(macOS 14.0, *)
public struct BackgroundRemoverToolView: View {
    @State private var removerItems: [BackgroundRemoverItem] = []
    @State private var selectedItemId: UUID? = nil
    
    // Background Removal Settings
    @State private var fillType: BackgroundFillType = .transparent
    @State private var customColor: Color = .blue
    @State private var customBgImageData: Data? = nil
    @State private var customBgName: String? = nil
    @State private var outputFormat: BackgroundRemoverOutputFormat = .png
    
    @State private var isProcessingAll: Bool = false
    @State private var activePreviewTab: PreviewTab = .processed
    
    private enum PreviewTab: String, CaseIterable, Identifiable {
        case processed = "Background Removed"
        case original = "Original Image"
        
        var id: String { rawValue }
    }
    
    public init() {}
    
    private var selectedItem: BackgroundRemoverItem? {
        removerItems.first(where: { $0.id == selectedItemId })
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
            
            if removerItems.isEmpty {
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
                    Image(systemName: "person.and.background.striped.horizontal")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text("Background Remover")
                        .font(.title2.bold())
                }
                
                Text("Automatically detect foreground subjects and remove or replace image backgrounds.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !removerItems.isEmpty {
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
                Text("Choose or drag & drop one or more images to remove background.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            FileDropZoneCardView(
                title: "Drag & Drop Images Here",
                subtitle: "Supports PNG, JPEG, HEIC, WebP, TIFF, and BMP images",
                iconName: "person.and.background.striped.horizontal",
                buttonTitle: "Browse Image Files...",
                onBrowse: openFilePicker,
                onDropFiles: { urls in
                    self.loadURLs(urls)
                }
            )

            Spacer()
        }
    }
    
    // MARK: - Main Workspace
    
    private var mainWorkspaceView: some View {
        VStack(spacing: 0) {
            controlPanelCard
                .padding(16)
            
            Divider()
            
            HStack(spacing: 0) {
                if removerItems.count > 1 {
                    batchSidebarView
                        .frame(width: 240)
                    Divider()
                }
                
                VStack(spacing: 0) {
                    if let item = selectedItem {
                        previewAreaView(for: item)
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
        HStack(spacing: 24) {
            // Background Fill Mode
            VStack(alignment: .leading, spacing: 6) {
                Text("BACKGROUND FILL")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                
                Picker("Fill Mode", selection: $fillType) {
                    ForEach(BackgroundFillType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: fillType) { _, _ in
                    triggerProcessingAll()
                }
            }
            
            // Fill Type Dynamic Controls (Custom Color or Custom Image)
            if fillType == .customColor {
                VStack(alignment: .leading, spacing: 6) {
                    Text("COLOR")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    ColorPicker("Pick Color", selection: $customColor, supportsOpacity: false)
                        .labelsHidden()
                        .onChange(of: customColor) { _, _ in
                            triggerProcessingAll()
                        }
                }
            } else if fillType == .customImage {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BACKGROUND IMAGE")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Button("Choose Image...") {
                            chooseCustomBgImage()
                        }
                        .buttonStyle(.bordered)
                        
                        if let name = customBgName {
                            Text(name)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Divider()
                .frame(height: 38)
            
            // Output Format
            VStack(alignment: .leading, spacing: 6) {
                Text("OUTPUT FORMAT")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                
                Picker("Format", selection: $outputFormat) {
                    ForEach(BackgroundRemoverOutputFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .frame(width: 170)
                .onChange(of: outputFormat) { _, _ in
                    triggerProcessingAll()
                }
            }
            
            Spacer()
            
            Button(action: triggerProcessingAll) {
                Label(isProcessingAll ? "Removing Background..." : "Apply & Remove", systemImage: "sparkles")
                    .font(.headline)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessingAll)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Batch Sidebar View
    
    private var batchSidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("IMAGES (\(removerItems.count))")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(12)
            
            Divider()
            
            List(selection: $selectedItemId) {
                ForEach(removerItems) { item in
                    HStack(spacing: 10) {
                        if let procData = item.processedData, let nsImg = NSImage(data: procData) {
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
                                
                                if let procSize = item.formattedProcessedSize as String?, item.processedData != nil {
                                    Text("→ \(procSize)")
                                        .font(.caption2.bold())
                                        .foregroundColor(.accentColor)
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
    
    // MARK: - Preview Area
    
    private func previewAreaView(for item: BackgroundRemoverItem) -> some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Picker("View", selection: $activePreviewTab) {
                    ForEach(PreviewTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)
            }
            
            ZStack {
                // Checkerboard pattern for transparency visualization
                checkerboardBackground
                    .cornerRadius(12)
                
                if item.isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Detecting Subject & Removing Background...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor).opacity(0.9)))
                } else if let err = item.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(err)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                } else {
                    switch activePreviewTab {
                    case .processed:
                        if let procData = item.processedData, let nsImg = NSImage(data: procData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                        } else {
                            Text("Click 'Apply & Remove' to process this image.")
                                .foregroundColor(.secondary)
                        }
                    case .original:
                        if let nsImg = NSImage(data: item.originalData) {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
    
    private var checkerboardBackground: some View {
        Canvas { context, size in
            let squareSize: CGFloat = 16
            let rows = Int(ceil(size.height / squareSize))
            let cols = Int(ceil(size.width / squareSize))
            
            for row in 0..<rows {
                for col in 0..<cols {
                    let isEven = (row + col) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(col) * squareSize,
                        y: CGFloat(row) * squareSize,
                        width: squareSize,
                        height: squareSize
                    )
                    context.fill(Path(rect), with: .color(isEven ? Color(white: 0.92) : Color(white: 0.82)))
                }
            }
        }
    }
    
    // MARK: - Bottom Action Bar
    
    private var bottomActionBar: some View {
        HStack {
            if !removerItems.isEmpty {
                let processedCount = removerItems.filter { $0.processedData != nil }.count
                Text("\(processedCount) of \(removerItems.count) image(s) processed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if selectedItem?.processedData != nil {
                    Button(action: saveSingleSelected) {
                        Label("Save Current Image...", systemImage: "square.and.arrow.down")
                    }
                }
                
                if removerItems.contains(where: { $0.processedData != nil }) {
                    Button(action: saveAllImages) {
                        Label("Save All Images...", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
    
    // MARK: - Actions & Logic
    
    private func currentConfig() -> BackgroundRemoverConfig {
        BackgroundRemoverConfig(
            fillType: fillType,
            customColor: customColor,
            customBgImageData: customBgImageData,
            outputFormat: outputFormat
        )
    }
    
    private func triggerProcessingAll() {
        guard !removerItems.isEmpty else { return }
        
        let config = currentConfig()
        isProcessingAll = true
        
        Task {
            var updatedList: [BackgroundRemoverItem] = []
            for item in removerItems {
                let processed = await BackgroundRemoverEngine.removeBackground(item: item, config: config)
                updatedList.append(processed)
            }
            
            await MainActor.run {
                self.removerItems = updatedList
                self.isProcessingAll = false
            }
        }
    }
    
    private func chooseCustomBgImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .webP, .tiff, .bmp]
        
        if panel.runModal() == .OK, let url = panel.url {
            if let data = try? Data(contentsOf: url) {
                self.customBgImageData = data
                self.customBgName = url.lastPathComponent
                triggerProcessingAll()
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
        var newItems: [BackgroundRemoverItem] = []
        for url in urls {
            if let item = BackgroundRemoverEngine.loadItem(from: url) {
                newItems.append(item)
            }
        }
        
        guard !newItems.isEmpty else { return }
        
        self.removerItems.append(contentsOf: newItems)
        if selectedItemId == nil || selectedItem == nil {
            selectedItemId = removerItems.first?.id
        }
        
        triggerProcessingAll()
    }
    
    private func handleDroppedProviders(_ providers: [NSItemProvider]) {
        providers.extractURLs { urls in
            guard !urls.isEmpty else { return }
            self.loadURLs(urls)
        }
    }
    
    private func clearAll() {
        removerItems.removeAll()
        selectedItemId = nil
    }
    
    private func saveSingleSelected() {
        guard let item = selectedItem, let procData = item.processedData else { return }
        
        let defaultName = (item.name as NSString).deletingPathExtension + "_nobg." + outputFormat.fileExtension
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        if let type = UTType(outputFormat.utiType) {
            panel.allowedContentTypes = [type]
        }
        
        if panel.runModal() == .OK, let saveURL = panel.url {
            try? procData.write(to: saveURL)
        }
    }
    
    private func saveAllImages() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.title = "Select Destination Folder to Save Background Removed Images"
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            for item in removerItems {
                guard let procData = item.processedData else { continue }
                let name = (item.name as NSString).deletingPathExtension + "_nobg." + outputFormat.fileExtension
                let fileURL = folderURL.appendingPathComponent(name)
                try? procData.write(to: fileURL)
            }
        }
    }
}
