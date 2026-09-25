import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit

public struct PdfConverterToolView: View {
    @State private var mode: PdfConverterMode
    
    // Image to PDF State
    @State private var imageItems: [ImageToPdfItem] = []
    @State private var imageOptions = ImageToPdfOptions()
    @State private var generatedPdfResults: [PdfExportResult] = []
    @State private var isProcessingImages: Bool = false
    
    // PDF to Image State
    @State private var pdfItem: PdfToImageItem? = nil
    @State private var pdfOptions = PdfToImageOptions()
    @State private var renderedPages: [RenderedPageItem] = []
    @State private var isProcessingPdf: Bool = false
    @State private var selectedPageId: UUID? = nil
    
    // Merge PDF State
    @State private var mergeItems: [MergePdfItem] = []
    @State private var mergeOptions = MergePdfOptions()
    @State private var mergedResult: PdfExportResult? = nil
    @State private var isMergingPdf: Bool = false
    
    // Split PDF State
    @State private var splitPdfItem: MergePdfItem? = nil
    @State private var splitThumbnails: [PdfSplitPageThumbnail] = []
    @State private var selectedSplitPages: Set<Int> = []
    @State private var splitOptions = PdfSplitOptions()
    @State private var splitResults: [PdfExportResult] = []
    @State private var isProcessingSplit: Bool = false
    @State private var isLoadingSplitThumbnails: Bool = false
    
    public init(initialMode: PdfConverterMode = .imageToPdf) {
        _mode = State(initialValue: initialMode)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            Divider()
            
            switch mode {
            case .imageToPdf:
                imageToPdfView
            case .pdfToImage:
                pdfToImageView
            case .pdfToWord:
                FileDropZoneCardView(
                    title: "Drag & Drop PDF File(s) Here",
                    subtitle: "Convert PDF documents into editable Word (.docx) files.",
                    iconName: "doc.text.fill",
                    buttonTitle: "Browse",
                    onBrowse: {},
                    onDropFiles: { _ in }
                )
                .padding(24)
            case .mergePdf, .splitPdf:
                mergePdfView
            case .signPdf:
                PdfSignerView()
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerIconName: String {
        switch mode {
        case .imageToPdf: return "doc.richtext"
        case .pdfToImage: return "doc.viewfinder"
        case .pdfToWord: return "doc.text.fill"
        case .mergePdf: return "doc.on.doc"
        case .splitPdf: return "scissors"
        case .signPdf: return "signature"
        }
    }
    
    private var headerTitle: String {
        switch mode {
        case .imageToPdf: return "Image to PDF Converter"
        case .pdfToImage: return "PDF to Image Converter"
        case .pdfToWord: return "PDF to Word Converter"
        case .mergePdf: return "Merge PDF Documents"
        case .splitPdf: return "PDF Splitter & Page Extractor"
        case .signPdf: return "PDF Signer"
        }
    }
    
    private var headerSubtitle: String {
        switch mode {
        case .imageToPdf: return "Combine multiple images into clean PDF documents or export individual PDFs."
        case .pdfToImage: return "Extract high-resolution images from PDF pages with full DPI control."
        case .pdfToWord: return "Convert PDF documents into editable Word (.docx) files."
        case .mergePdf: return "Combine multiple PDF files into a single structured PDF document."
        case .splitPdf: return "Extract ranges, split into single pages, or chunk PDF documents."
        case .signPdf: return "Add visual signature overlays or PKCS#12 digital certificate signatures to PDF documents."
        }
    }
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: headerIconName)
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    Text(headerTitle)
                        .font(.title2.bold())
                }
                
                Text(headerSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            .frame(width: 440)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Image to PDF View
    
    private var imageToPdfView: some View {
        VStack(spacing: 0) {
            if imageItems.isEmpty {
                emptyDropZoneView(
                    title: "Drag & Drop Image Files Here",
                    subtitle: "Supports PNG, JPEG, HEIC, WebP, TIFF, and BMP images",
                    iconName: "photo.on.rectangle.angled",
                    buttonTitle: "Browse Images",
                    allowedTypes: [.image, .jpeg, .png, .heic, .webP, .tiff, .bmp],
                    onSelectURLs: loadImagesFromURLs
                )
                .padding(24)
            } else {
                imageToPdfWorkspace
            }
        }
    }
    
    private var imageToPdfWorkspace: some View {
        VStack(spacing: 0) {
            imageToPdfControlsCard
                .padding(16)
            
            Divider()
            
            HStack(spacing: 0) {
                imageSidebarView
                    .frame(width: 260)
                
                Divider()
                
                pdfResultPreviewView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            imageToPdfBottomBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private var imageSidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("IMAGES (\(imageItems.count))")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
                
                Button("Add More", action: openImagePicker)
                    .font(.caption)
                
                Button("Clear", action: clearImages)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(12)
            
            Divider()
            
            List {
                ForEach(imageItems) { item in
                    HStack(spacing: 10) {
                        if let nsImg = item.image {
                            Image(nsImage: nsImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .cornerRadius(6)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.caption.bold())
                                .lineLimit(1)
                            
                            Text(item.formattedSize)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { removeImage(item) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    private var pdfResultPreviewView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if isProcessingImages {
                ProgressView("Generating PDF Document...")
                    .progressViewStyle(.circular)
            } else if !generatedPdfResults.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    VStack(spacing: 4) {
                        Text("PDF Ready to Export!")
                            .font(.title3.bold())
                        
                        Text("\(generatedPdfResults.count) file(s) generated • Total \(imageItems.count) image(s)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(generatedPdfResults) { res in
                            HStack(spacing: 10) {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.red)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(res.name)
                                        .font(.caption.bold())
                                    Text("\(res.pageCount) page(s) • \(ByteCountFormatter.string(fromByteCount: Int64(res.data.count), countStyle: .file))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: 320, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Configure options above and click Convert to PDF")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var imageToPdfBottomBar: some View {
        HStack {
            Text("Total Original Images: \(imageItems.count)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: triggerImageToPdfConversion) {
                Label("Convert", systemImage: "doc.badge.plus")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessingImages || imageItems.isEmpty)
            .help("Convert images to PDF")
            
            if !generatedPdfResults.isEmpty {
                Button(action: savePdfResults) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .help("Save generated PDF files")
            }
        }
    }
    
    private var imageToPdfControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                pageSizeControlSection
                Divider().frame(height: 36)
                orientationControlSection
                Divider().frame(height: 36)
                marginControlSection
                Divider().frame(height: 36)
                fileNameControlSection
            }
            
            HStack {
                Toggle("Combine all images into a single PDF document", isOn: $imageOptions.mergeIntoSinglePdf)
                    .font(.caption.bold())
                Spacer()
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .onChange(of: imageOptions.pageSize) { _ in triggerImageToPdfConversion() }
        .onChange(of: imageOptions.orientation) { _ in triggerImageToPdfConversion() }
        .onChange(of: imageOptions.marginPoints) { _ in triggerImageToPdfConversion() }
        .onChange(of: imageOptions.mergeIntoSinglePdf) { _ in triggerImageToPdfConversion() }
        .onChange(of: imageOptions.pdfFileName) { _ in triggerImageToPdfConversion() }
    }
    
    private var pageSizeControlSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PAGE SIZE")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            Picker("Page Size", selection: $imageOptions.pageSize) {
                ForEach(PdfPageSize.allCases) { sz in
                    Text(sz.rawValue).tag(sz)
                }
            }
            .frame(width: 180)
        }
    }
    
    private var orientationControlSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ORIENTATION")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            Picker("Orientation", selection: $imageOptions.orientation) {
                ForEach(PdfOrientation.allCases) { o in
                    Text(o.rawValue).tag(o)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .disabled(imageOptions.pageSize == .fitImage)
        }
    }
    
    private var marginControlSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MARGIN")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                marginButton(pts: 0, label: "None")
                marginButton(pts: 10, label: "10pt")
                marginButton(pts: 20, label: "20pt")
                marginButton(pts: 36, label: "36pt")
            }
        }
    }
    
    @ViewBuilder
    private func marginButton(pts: Int, label: String) -> some View {
        let isSelected = imageOptions.marginPoints == CGFloat(pts)
        if isSelected {
            Button(label) {
                imageOptions.marginPoints = CGFloat(pts)
            }
            .font(.caption2)
            .buttonStyle(.borderedProminent)
        } else {
            Button(label) {
                imageOptions.marginPoints = CGFloat(pts)
            }
            .font(.caption2)
            .buttonStyle(.bordered)
        }
    }
    
    private var fileNameControlSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PDF FILE NAME")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            TextField("Converted_Document.pdf", text: $imageOptions.pdfFileName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .disabled(!imageOptions.mergeIntoSinglePdf)
        }
    }
    
    // MARK: - PDF to Image View
    
    private var pdfToImageView: some View {
        VStack(spacing: 0) {
            if pdfItem == nil {
                emptyDropZoneView(
                    title: "Drag & Drop PDF File Here",
                    subtitle: "Extract document pages into PNG, JPEG, WebP, or TIFF images",
                    iconName: "doc.viewfinder.fill",
                    buttonTitle: "Browse PDF Document",
                    allowedTypes: [.pdf],
                    onSelectURLs: loadPdfFromURLs
                )
                .padding(24)
            } else {
                pdfToImageWorkspace
            }
        }
    }
    
    private var pdfToImageWorkspace: some View {
        VStack(spacing: 0) {
            pdfToImageControlsCard
                .padding(16)
            
            Divider()
            
            HStack(spacing: 0) {
                pdfSidebarView
                    .frame(width: 250)
                
                Divider()
                
                pagePreviewView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            pdfToImageBottomBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private var pdfSidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let item = pdfItem {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.caption.bold())
                            .lineLimit(1)
                        Text("\(item.pageCount) page(s) • \(item.formattedSize)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Change", action: openPdfPicker)
                    .font(.caption)
                    .help("Change selected PDF")
            }
            .padding(12)
            
            Divider()
            
            if isProcessingPdf {
                VStack {
                    Spacer()
                    ProgressView("Rendering Pages...")
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(selection: $selectedPageId) {
                    ForEach(renderedPages) { page in
                        HStack(spacing: 10) {
                            Image(nsImage: page.image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .background(Color.white)
                                .cornerRadius(4)
                                .shadow(radius: 1)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Page \(page.pageNumber)")
                                    .font(.caption.bold())
                                
                                Text(page.formattedSize)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(page.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }
    
    private var pagePreviewView: some View {
        VStack(spacing: 0) {
            if let selId = selectedPageId, let selectedPage = renderedPages.first(where: { $0.id == selId }) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Page \(selectedPage.pageNumber) Preview")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(selectedPage.image.size.width)) × \(Int(selectedPage.image.size.height)) px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    Divider()
                    
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: selectedPage.image)
                            .resizable()
                            .scaledToFit()
                            .shadow(radius: 4)
                            .padding(20)
                    }
                }
            } else if !renderedPages.isEmpty {
                Text("Select a page from sidebar to preview")
                    .foregroundColor(.secondary)
            } else {
                Text("No pages rendered yet")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var pdfToImageBottomBar: some View {
        HStack {
            if let item = pdfItem {
                Text("PDF: \(item.name) (\(renderedPages.count) pages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let selId = selectedPageId, let selectedPage = renderedPages.first(where: { $0.id == selId }) {
                Button(action: { saveSinglePage(selectedPage) }) {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help("Save selected page image")
            }
            
            if !renderedPages.isEmpty {
                Button(action: saveAllPages) {
                    Label("Save", systemImage: "folder.badge.plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .help("Save all rendered page images")
            }
        }
    }
    
    private var pdfToImageControlsCard: some View {
        HStack(spacing: 24) {
            formatControlSection
            Divider().frame(height: 36)
            dpiControlSection
            
            if pdfOptions.targetFormat == .jpeg {
                Divider().frame(height: 36)
                jpegQualityControlSection
            }
            
            Spacer()
            
            Button(action: triggerPdfToImageConversion) {
                Label("Render", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(isProcessingPdf || pdfItem == nil)
            .help("Render PDF pages as images")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .onChange(of: pdfOptions.targetFormat) { _ in triggerPdfToImageConversion() }
        .onChange(of: pdfOptions.dpi) { _ in triggerPdfToImageConversion() }
        .onChange(of: pdfOptions.jpegQuality) { _ in triggerPdfToImageConversion() }
    }
    
    private var formatControlSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OUTPUT IMAGE FORMAT")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            Picker("Format", selection: $pdfOptions.targetFormat) {
                ForEach(PdfImageOutputFormat.allCases) { fmt in
                    Text(fmt.rawValue).tag(fmt)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
    }
    
    private var dpiControlSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("IMAGE RESOLUTION (DPI)")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            Picker("DPI", selection: $pdfOptions.dpi) {
                ForEach(PdfDPI.allCases) { dpi in
                    Text(dpi.label).tag(dpi)
                }
            }
            .frame(width: 180)
        }
    }
    
    private var jpegQualityControlSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("JPEG QUALITY")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(pdfOptions.jpegQuality * 100))%")
                    .font(.caption.bold())
                    .foregroundColor(.accentColor)
            }
            
            Slider(value: $pdfOptions.jpegQuality, in: 0.2...1.0, step: 0.05)
                .frame(width: 160)
        }
    }
    
    // MARK: - Generic Empty Drop Zone
    
    private func emptyDropZoneView(
        title: String,
        subtitle: String,
        iconName: String,
        buttonTitle: String,
        allowedTypes: [UTType],
        onSelectURLs: @escaping ([URL]) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            FileDropZoneCardView(
                title: "Drag & Drop your file(s) here",
                subtitle: subtitle,
                iconName: iconName,
                buttonTitle: buttonTitle,
                onBrowse: { openFilePicker(allowedTypes: allowedTypes, onSelectURLs: onSelectURLs) },
                onDropFiles: onSelectURLs
            )
            
            Spacer()
        }
    }
    
    // MARK: - Actions & Conversion Handlers
    
    private func loadImagesFromURLs(_ urls: [URL]) {
        var loaded: [ImageToPdfItem] = []
        for url in urls {
            if let item = PdfConverterEngine.loadImageItem(from: url) {
                loaded.append(item)
            }
        }
        guard !loaded.isEmpty else { return }
        self.imageItems.append(contentsOf: loaded)
        triggerImageToPdfConversion()
    }
    
    private func loadPdfFromURLs(_ urls: [URL]) {
        guard let firstURL = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else { return }
        if let item = PdfConverterEngine.loadPdfItem(from: firstURL) {
            self.pdfItem = item
            triggerPdfToImageConversion()
        }
    }
    
    private func openImagePicker() {
        openFilePicker(allowedTypes: [.image, .jpeg, .png, .heic, .webP, .tiff, .bmp], onSelectURLs: loadImagesFromURLs)
    }
    
    private func openPdfPicker() {
        openFilePicker(allowedTypes: [.pdf], onSelectURLs: loadPdfFromURLs)
    }
    
    private func openFilePicker(allowedTypes: [UTType], onSelectURLs: @escaping ([URL]) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowedTypes.contains(.image)
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = allowedTypes
        
        if panel.runModal() == .OK {
            onSelectURLs(panel.urls)
        }
    }
    
    private func handleDroppedImageProviders(_ providers: [NSItemProvider]) {
        providers.extractURLs { urls in
            guard !urls.isEmpty else { return }
            self.loadImagesFromURLs(urls)
        }
    }
    
    private func handleDroppedPdfProviders(_ providers: [NSItemProvider]) {
        providers.extractURLs { urls in
            guard !urls.isEmpty else { return }
            self.loadPdfFromURLs(urls)
        }
    }

    
    private func removeImage(_ item: ImageToPdfItem) {
        imageItems.removeAll(where: { $0.id == item.id })
        if imageItems.isEmpty {
            generatedPdfResults.removeAll()
        } else {
            triggerImageToPdfConversion()
        }
    }
    
    private func clearImages() {
        imageItems.removeAll()
        generatedPdfResults.removeAll()
    }
    
    private func triggerImageToPdfConversion() {
        guard !imageItems.isEmpty else { return }
        isProcessingImages = true
        let items = imageItems
        let opts = imageOptions
        
        Task {
            let results = await PdfConverterEngine.convertImagesToPdf(items: items, options: opts)
            await MainActor.run {
                self.generatedPdfResults = results
                self.isProcessingImages = false
            }
        }
    }
    
    private func triggerPdfToImageConversion() {
        guard let pdf = pdfItem else { return }
        isProcessingPdf = true
        let opts = pdfOptions
        
        Task {
            let pages = await PdfConverterEngine.convertPdfToImages(pdfURL: pdf.url, options: opts)
            await MainActor.run {
                self.renderedPages = pages
                self.selectedPageId = pages.first?.id
                self.isProcessingPdf = false
            }
        }
    }
    
    private func savePdfResults() {
        guard !generatedPdfResults.isEmpty else { return }
        
        if generatedPdfResults.count == 1, let res = generatedPdfResults.first {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = res.name
            panel.allowedContentTypes = [.pdf]
            
            if panel.runModal() == .OK, let url = panel.url {
                try? res.data.write(to: url)
            }
        } else {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.title = "Select Folder to Save PDF Files"
            
            if panel.runModal() == .OK, let folderURL = panel.url {
                for res in generatedPdfResults {
                    let fileURL = folderURL.appendingPathComponent(res.name)
                    try? res.data.write(to: fileURL)
                }
            }
        }
    }
    
    private func saveSinglePage(_ page: RenderedPageItem) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = page.name
        panel.allowedContentTypes = [pdfOptions.targetFormat.utType]
        
        if panel.runModal() == .OK, let url = panel.url {
            try? page.data.write(to: url)
        }
    }
    
    private func saveAllPages() {
        guard !renderedPages.isEmpty else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.title = "Select Folder to Save Rendered Page Images"
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            for page in renderedPages {
                let fileURL = folderURL.appendingPathComponent(page.name)
                try? page.data.write(to: fileURL)
            }
        }
    }
    
    // MARK: - Merge PDF Views & Handlers
    
    private var mergePdfView: some View {
        VStack(spacing: 0) {
            if mergeItems.isEmpty {
                emptyDropZoneView(
                    title: "Drag & Drop PDF Files Here",
                    subtitle: "Combine two or more PDF documents into a single document",
                    iconName: "doc.on.doc.fill",
                    buttonTitle: "Browse PDF Files",
                    allowedTypes: [.pdf],
                    onSelectURLs: loadMergePdfsFromURLs
                )
                .padding(24)
            } else {
                mergePdfWorkspace
            }
        }
    }
    
    private var mergePdfWorkspace: some View {
        VStack(spacing: 0) {
            mergePdfControlsCard
                .padding(16)
            
            Divider()
            
            HStack(spacing: 0) {
                mergePdfSidebarView
                    .frame(width: 280)
                
                Divider()
                
                mergePdfPreviewView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Divider()
            
            mergePdfBottomBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }
    
    private var mergePdfControlsCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MERGED PDF FILE NAME")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                
                TextField("Merged_Document.pdf", text: $mergeOptions.outputFileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .onChange(of: mergeOptions.outputFileName) { _ in triggerMergePdf() }
    }
    
    private var mergePdfSidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PDF FILES (\(mergeItems.count))")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Spacer()
                
                Button("Add More", action: openMergePdfPicker)
                    .font(.caption)
                
                Button("Clear", action: clearMergePdfs)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(12)
            
            Divider()
            
            List {
                ForEach(Array(mergeItems.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.caption.bold())
                                .lineLimit(1)
                            
                            Text("\(item.pageCount) page(s) • \(item.formattedSize)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Button(action: { moveMergePdfItemUp(index: index) }) {
                                Image(systemName: "chevron.up")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            
                            Button(action: { moveMergePdfItemDown(index: index) }) {
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .disabled(index == mergeItems.count - 1)
                        }
                        
                        Button(action: { removeMergePdfItem(item) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.sidebar)
        }
    }
    
    private var mergePdfPreviewView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            if isMergingPdf {
                ProgressView("Merging PDF Documents...")
                    .progressViewStyle(.circular)
            } else if let res = mergedResult {
                VStack(spacing: 16) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    VStack(spacing: 4) {
                        Text("Merged PDF Ready!")
                            .font(.title3.bold())
                        
                        Text("Combined \(mergeItems.count) PDF file(s) into 1 document")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(res.name)
                                    .font(.caption.bold())
                                Text("\(res.pageCount) total page(s) • \(ByteCountFormatter.string(fromByteCount: Int64(res.data.count), countStyle: .file))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: 340, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Click Merge PDF Documents to combine selected PDF files")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    private var mergePdfBottomBar: some View {
        HStack {
            let totalInputPages = mergeItems.reduce(0) { $0 + $1.pageCount }
            Text("Total PDF Files: \(mergeItems.count) (\(totalInputPages) pages)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: triggerMergePdf) {
                Label("Merge PDF Documents", systemImage: "doc.on.doc")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isMergingPdf || mergeItems.isEmpty)
            
            if mergedResult != nil {
                Button(action: saveMergedPdf) {
                    Label("Save Merged PDF...", systemImage: "square.and.arrow.down")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
    }
    
    private func loadMergePdfsFromURLs(_ urls: [URL]) {
        var loaded: [MergePdfItem] = []
        for url in urls {
            if url.pathExtension.lowercased() == "pdf", let item = PdfConverterEngine.loadMergePdfItem(from: url) {
                loaded.append(item)
            }
        }
        guard !loaded.isEmpty else { return }
        self.mergeItems.append(contentsOf: loaded)
        triggerMergePdf()
    }
    
    private func openMergePdfPicker() {
        openFilePicker(allowedTypes: [.pdf], onSelectURLs: loadMergePdfsFromURLs)
    }
    
    private func handleDroppedMergePdfProviders(_ providers: [NSItemProvider]) {
        providers.extractURLs { urls in
            guard !urls.isEmpty else { return }
            self.loadMergePdfsFromURLs(urls)
        }
    }

    
    private func removeMergePdfItem(_ item: MergePdfItem) {
        mergeItems.removeAll(where: { $0.id == item.id })
        if mergeItems.isEmpty {
            mergedResult = nil
        } else {
            triggerMergePdf()
        }
    }
    
    private func moveMergePdfItemUp(index: Int) {
        guard index > 0 && index < mergeItems.count else { return }
        mergeItems.swapAt(index, index - 1)
        triggerMergePdf()
    }
    
    private func moveMergePdfItemDown(index: Int) {
        guard index >= 0 && index < mergeItems.count - 1 else { return }
        mergeItems.swapAt(index, index + 1)
        triggerMergePdf()
    }
    
    private func clearMergePdfs() {
        mergeItems.removeAll()
        mergedResult = nil
    }
    
    private func triggerMergePdf() {
        guard !mergeItems.isEmpty else { return }
        isMergingPdf = true
        let items = mergeItems
        let opts = mergeOptions
        
        Task {
            let res = await PdfConverterEngine.mergePdfFiles(items: items, options: opts)
            await MainActor.run {
                self.mergedResult = res
                self.isMergingPdf = false
            }
        }
    }
    
    private func saveMergedPdf() {
        guard let res = mergedResult else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = res.name
        panel.allowedContentTypes = [.pdf]
        
        if panel.runModal() == .OK, let url = panel.url {
            try? res.data.write(to: url)
        }
    }
    
    // MARK: - Split PDF View & Components
    
    private var splitPdfView: some View {
        VStack(spacing: 0) {
            if splitPdfItem == nil {
                emptyDropZoneView(
                    title: "Drag & Drop PDF File to Split",
                    subtitle: "Extract custom ranges, single pages, or chunk multi-page PDFs",
                    iconName: "scissors",
                    buttonTitle: "Browse PDF Document",
                    allowedTypes: [.pdf],
                    onSelectURLs: loadSplitPdfFromURLs
                )
                .padding(24)
            } else {
                splitPdfWorkspace
            }
        }
    }

    private var splitPdfWorkspace: some View {
        VStack(spacing: 0) {
            splitPdfControlsCard
                .padding(16)
            
            Divider()
            
            if isLoadingSplitThumbnails {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView("Rendering Page Thumbnails...")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    splitQuickSelectionBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 140), spacing: 16)], spacing: 16) {
                            ForEach(splitThumbnails) { thumb in
                                splitPageCard(thumb)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            
            Divider()
            
            splitPdfBottomBar
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private var splitQuickSelectionBar: some View {
        HStack(spacing: 12) {
            if let item = splitPdfItem {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text("\(item.pageCount) total page(s) • \(selectedSplitPages.count) selected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Group {
                Button("Select All") {
                    guard let item = splitPdfItem else { return }
                    selectedSplitPages = Set(1...item.pageCount)
                    updateRangeStringFromSelection()
                }
                
                Button("Deselect All") {
                    selectedSplitPages.removeAll()
                    updateRangeStringFromSelection()
                }
                
                Button("Invert") {
                    guard let item = splitPdfItem else { return }
                    let all = Set(1...item.pageCount)
                    selectedSplitPages = all.subtracting(selectedSplitPages)
                    updateRangeStringFromSelection()
                }
                
                Button("Odd Pages") {
                    guard let item = splitPdfItem else { return }
                    selectedSplitPages = Set((1...item.pageCount).filter { $0 % 2 != 0 })
                    updateRangeStringFromSelection()
                }
                
                Button("Even Pages") {
                    guard let item = splitPdfItem else { return }
                    selectedSplitPages = Set((1...item.pageCount).filter { $0 % 2 == 0 })
                    updateRangeStringFromSelection()
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            
            Button("Change PDF") {
                openSplitPdfPicker()
            }
            .font(.caption)
        }
    }

    private func splitPageCard(_ thumb: PdfSplitPageThumbnail) -> some View {
        let isSelected = selectedSplitPages.contains(thumb.pageNumber)
        
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: thumb.image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .background(Color.white)
                    .cornerRadius(6)
                    .shadow(color: isSelected ? Color.accentColor.opacity(0.4) : Color.black.opacity(0.1), radius: isSelected ? 4 : 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .padding(6)
            }
            
            Text("Page \(thumb.pageNumber)")
                .font(.caption2.bold())
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                selectedSplitPages.remove(thumb.pageNumber)
            } else {
                selectedSplitPages.insert(thumb.pageNumber)
            }
            updateRangeStringFromSelection()
        }
    }

    private var splitPdfControlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SPLIT MODE")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    Picker("Mode", selection: $splitOptions.mode) {
                        ForEach(PdfSplitMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
                
                Divider().frame(height: 36)
                
                if splitOptions.mode == .customRanges {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PAGE RANGES")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        
                        TextField("e.g. 1-3, 5, 8-10", text: $splitOptions.rangeString)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 180)
                            .onChange(of: splitOptions.rangeString) { newValue in
                                if let total = splitPdfItem?.pageCount {
                                    let parsed = PdfConverterEngine.parsePageRanges(newValue, totalPages: total)
                                    selectedSplitPages = Set(parsed)
                                }
                            }
                    }
                    
                    Divider().frame(height: 36)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPORT OPTION")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        
                        Toggle("Merge selected pages into one PDF", isOn: $splitOptions.combineSelectedRanges)
                            .font(.caption)
                    }
                } else if splitOptions.mode == .fixedChunks {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PAGES PER CHUNK")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        
                        Stepper("\(splitOptions.chunkSize) pages", value: $splitOptions.chunkSize, in: 1...100)
                            .font(.caption)
                            .frame(width: 160)
                    }
                }
                
                Divider().frame(height: 36)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("FILE PREFIX")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    
                    TextField("Output Prefix", text: $splitOptions.outputPrefix)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private var splitPdfBottomBar: some View {
        HStack {
            if let item = splitPdfItem {
                Text("Source: \(item.name) (\(item.pageCount) pages)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isProcessingSplit {
                ProgressView("Splitting PDF...")
                    .progressViewStyle(.circular)
            } else if !splitResults.isEmpty {
                Button(action: saveSplitResults) {
                    Label("Save \(splitResults.count) Output File(s)...", systemImage: "folder.badge.plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            
            Button(action: triggerSplitPdf) {
                Label("Split PDF Document", systemImage: "scissors")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessingSplit || splitPdfItem == nil || (splitOptions.mode == .customRanges && selectedSplitPages.isEmpty && splitOptions.rangeString.isEmpty))
        }
    }

    private func updateRangeStringFromSelection() {
        let str = PdfConverterEngine.formatPageRanges(selectedPages: selectedSplitPages)
        splitOptions.rangeString = str
    }

    private func loadSplitPdfFromURLs(_ urls: [URL]) {
        guard let firstURL = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else { return }
        if let item = PdfConverterEngine.loadMergePdfItem(from: firstURL) {
            self.splitPdfItem = item
            self.splitOptions.outputPrefix = (item.name as NSString).deletingPathExtension
            self.selectedSplitPages = Set(1...item.pageCount)
            self.updateRangeStringFromSelection()
            self.splitResults.removeAll()
            
            self.isLoadingSplitThumbnails = true
            Task {
                let thumbs = await PdfConverterEngine.loadSplitThumbnails(from: firstURL)
                await MainActor.run {
                    self.splitThumbnails = thumbs
                    self.isLoadingSplitThumbnails = false
                }
            }
        }
    }

    private func openSplitPdfPicker() {
        openFilePicker(allowedTypes: [.pdf], onSelectURLs: loadSplitPdfFromURLs)
    }

    private func handleDroppedSplitPdfProviders(_ providers: [NSItemProvider]) {
        providers.extractURLs { urls in
            guard !urls.isEmpty else { return }
            self.loadSplitPdfFromURLs(urls)
        }
    }

    private func triggerSplitPdf() {
        guard let item = splitPdfItem else { return }
        isProcessingSplit = true
        let url = item.url
        let opts = splitOptions
        let selected = selectedSplitPages
        
        Task {
            let results = await PdfConverterEngine.splitPdfDocument(url: url, options: opts, selectedPages: selected)
            await MainActor.run {
                self.splitResults = results
                self.isProcessingSplit = false
            }
        }
    }

    private func saveSplitResults() {
        guard !splitResults.isEmpty else { return }
        
        if splitResults.count == 1, let singleRes = splitResults.first {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = singleRes.name
            panel.allowedContentTypes = [.pdf]
            if panel.runModal() == .OK, let url = panel.url {
                try? singleRes.data.write(to: url)
            }
        } else {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.title = "Select Folder to Save Split PDF Files"
            
            if panel.runModal() == .OK, let targetDir = panel.url {
                for res in splitResults {
                    let fileURL = targetDir.appendingPathComponent(res.name)
                    try? res.data.write(to: fileURL)
                }
                NSWorkspace.shared.activateFileViewerSelecting([targetDir])
            }
        }
    }
}

