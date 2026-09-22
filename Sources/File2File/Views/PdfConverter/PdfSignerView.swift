import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

public struct PdfSignerView: View {
    @ObservedObject private var settings = AppSettings.shared
    
    // PDF State
    @State private var pdfItem: PdfSignItem? = nil
    @State private var pdfDocument: PDFDocument? = nil
    @State private var pageThumbnails: [PdfSplitPageThumbnail] = []
    @State private var currentPageIndex: Int = 0
    @State private var isLoadingPages: Bool = false
    
    // Signatures State
    @State private var visualOverlays: [VisualSignatureOverlay] = []
    @State private var selectedOverlayId: UUID? = nil
    
    // Creation Sheet State
    @State private var isShowingAddSignatureSheet: Bool = false
    
    // Digital Signature State
    @State private var enableDigitalCert: Bool = false
    @State private var digitalConfig = DigitalSignatureConfig()
    
    // Processing & Export State
    @State private var isProcessingExport: Bool = false
    @State private var exportErrorMessage: String? = nil
    @State private var signedExportResult: PdfExportResult? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            if let _ = pdfItem {
                mainEditorView
            } else {
                emptyFileDropView
            }
        }
        .sheet(isPresented: $isShowingAddSignatureSheet) {
            SignatureCreationSheet { newOverlayImage in
                let overlay = VisualSignatureOverlay(
                    image: newOverlayImage,
                    pageIndex: currentPageIndex
                )
                visualOverlays.append(overlay)
                selectedOverlayId = overlay.id
            }
        }
        .alert("Export Error", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
    }
    
    // MARK: - Empty File Drop View
    
    private var emptyFileDropView: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sign PDF Document")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Add visual signatures or digital PKCS#12 certificate signatures to your PDF.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            FileDropZoneCardView(
                title: "Drag & Drop your PDF file here",
                subtitle: "Supports standard PDF documents",
                iconName: "signature",
                buttonTitle: "Select PDF File...",
                onBrowse: selectPdfFile,
                onDropFiles: { urls in
                    if let first = urls.first {
                        loadPdfFile(first)
                    }
                }
            )

            Spacer()
        }
        .padding(24)
    }
    
    // MARK: - Main Editor View
    
    private var mainEditorView: some View {
        VStack(spacing: 0) {
            toolbarHeader
            
            Divider()
            
            HStack(spacing: 0) {
                // Left Panel: Page Thumbnails & Digital Cert Options
                leftControlPanel
                    .frame(width: 280)
                
                Divider()
                
                // Central Workspace: Interactive PDF Page Canvas
                centralCanvasWorkspace
            }
            
            Divider()
            
            bottomExportBar
        }
    }
    
    // MARK: - Toolbar Header
    
    private var toolbarHeader: some View {
        HStack {
            if let item = pdfItem {
                HStack(spacing: 10) {
                    Image(systemName: "doc.richtext")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text("\(item.pageCount) Pages • \(item.formattedSize)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Button {
                isShowingAddSignatureSheet = true
            } label: {
                Label("Add Signature", systemImage: "pencil.and.outline")
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .disabled(pdfItem == nil)
            
            Button {
                pdfItem = nil
                pdfDocument = nil
                visualOverlays.removeAll()
                pageThumbnails.removeAll()
                signedExportResult = nil
            } label: {
                Label("Change PDF", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Left Control Panel
    
    private var leftControlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Document Page Selector Header
            Text("DOCUMENT PAGES")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 12)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(pageThumbnails) { thumb in
                        let isSelected = thumb.pageNumber == currentPageIndex + 1
                        let overlayCount = visualOverlays.filter { $0.pageIndex == thumb.pageNumber - 1 }.count
                        
                        HStack(spacing: 10) {
                            Image(nsImage: thumb.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 60)
                                .cornerRadius(4)
                                .shadow(radius: 1)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Page \(thumb.pageNumber)")
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .bold : .regular)
                                
                                if overlayCount > 0 {
                                    Text("\(overlayCount) signature\(overlayCount > 1 ? "s" : "")")
                                        .font(.caption2)
                                        .foregroundColor(.accentColor)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            currentPageIndex = thumb.pageNumber - 1
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Divider()
            
            // Digital Signature Settings Section
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $enableDigitalCert) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(enableDigitalCert ? .accentColor : .secondary)
                        Text("Digital PKCS#12 Certificate")
                            .font(.caption.bold())
                    }
                }
                .toggleStyle(.checkbox)
                
                if enableDigitalCert {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(digitalConfig.certificateURL?.lastPathComponent ?? "No .p12 / .pfx selected")
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundColor(digitalConfig.certificateURL != nil ? .primary : .secondary)
                            Spacer()
                            Button("Browse") {
                                selectDigitalCertificateFile()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        SecureField("Certificate Password", text: $digitalConfig.password)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                        
                        TextField("Signature Reason", text: $digitalConfig.reason)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
                }
            }
            .padding(12)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Central Canvas Workspace
    
    private var centralCanvasWorkspace: some View {
        GeometryReader { geometry in
            ZStack {
                Color(NSColor.darkGray).opacity(0.15)
                    .ignoresSafeArea()
                
                if currentPageIndex < pageThumbnails.count {
                    let thumb = pageThumbnails[currentPageIndex]
                    
                    // Render page preview
                    ZStack {
                        Image(nsImage: thumb.image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .shadow(radius: 6)
                            .background(
                                GeometryReader { pageGeo in
                                    Color.clear
                                        .onAppear {
                                            // Page rendered geometry
                                        }
                                }
                            )
                        
                        // Signature Overlays layer for current page
                        ForEach($visualOverlays) { $overlay in
                            if overlay.pageIndex == currentPageIndex {
                                let isSelected = selectedOverlayId == overlay.id
                                
                                GeometryReader { overlayGeo in
                                    let canvasW = geometry.size.width * 0.8
                                    let canvasH = geometry.size.height * 0.8
                                    
                                    let posX = overlay.position.x * canvasW
                                    let posY = overlay.position.y * canvasH
                                    let sigW = overlay.size.width * canvasW
                                    let sigH = overlay.size.height * canvasH
                                    
                                    ZStack {
                                        Image(nsImage: overlay.image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: max(40, sigW), height: max(20, sigH))
                                            .border(isSelected ? Color.accentColor : Color.clear, width: 2)
                                        
                                        if isSelected {
                                            // Delete handle
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    Button {
                                                        visualOverlays.removeAll { $0.id == overlay.id }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.title3)
                                                            .foregroundColor(.red)
                                                            .background(Circle().fill(Color.white))
                                                    }
                                                    .buttonStyle(.plain)
                                                    .offset(x: 10, y: -10)
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                    .position(x: posX, y: posY)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                selectedOverlayId = overlay.id
                                                let newX = max(0.1, min(0.9, value.location.x / canvasW))
                                                let newY = max(0.1, min(0.9, value.location.y / canvasH))
                                                overlay.position = CGPoint(x: newX, y: newY)
                                            }
                                    )
                                    .onTapGesture {
                                        selectedOverlayId = overlay.id
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: geometry.size.width * 0.8, height: geometry.size.height * 0.8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedOverlayId = nil
            }
        }
    }
    
    // MARK: - Bottom Export Bar
    
    private var bottomExportBar: some View {
        HStack {
            if signedExportResult != nil {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Successfully signed! Ready to save.")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            } else {
                Text("\(visualOverlays.count) signature overlay\(visualOverlays.count != 1 ? "s" : "") placed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isProcessingExport {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            }
            
            Button {
                exportSignedPdf()
            } label: {
                Label(signedExportResult != nil ? "Save Signed PDF" : "Sign & Export PDF", systemImage: "square.and.arrow.down")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(pdfItem == nil || isProcessingExport)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - File Actions
    
    private func selectPdfFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            loadPdfFile(url)
        }
    }
    
    private func selectDigitalCertificateFile() {
        let panel = NSOpenPanel()
        if let p12Type = UTType(filenameExtension: "p12"),
           let pfxType = UTType(filenameExtension: "pfx") {
            panel.allowedContentTypes = [p12Type, pfxType]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            digitalConfig.certificateURL = url
        }
    }
    
    private func loadPdfFromProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url = url {
                DispatchQueue.main.async {
                    self.loadPdfFile(url)
                }
            }
        }
        return true
    }
    
    private func loadPdfFile(_ url: URL) {
        guard let item = PdfSignerEngine.loadPdfSignItem(from: url),
              let doc = PDFDocument(url: url) else { return }
        
        self.pdfItem = item
        self.pdfDocument = doc
        self.visualOverlays.removeAll()
        self.currentPageIndex = 0
        self.signedExportResult = nil
        
        // Render thumbnails asynchronously
        Task {
            var thumbs: [PdfSplitPageThumbnail] = []
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    let image = page.thumbnail(of: CGSize(width: 140, height: 180), for: .mediaBox)
                    thumbs.append(PdfSplitPageThumbnail(pageNumber: i + 1, image: image))
                }
            }
            await MainActor.run {
                self.pageThumbnails = thumbs
            }
        }
    }
    
    private func exportSignedPdf() {
        guard let item = pdfItem else { return }
        
        if let existingResult = signedExportResult {
            saveResultToDisk(existingResult)
            return
        }
        
        isProcessingExport = true
        let config = enableDigitalCert ? digitalConfig : nil
        let overlays = visualOverlays
        
        Task {
            do {
                let data = try PdfSignerEngine.signPdf(
                    pdfUrl: item.url,
                    visualOverlays: overlays,
                    digitalConfig: config
                )
                
                let outputName = item.url.deletingPathExtension().lastPathComponent + "_signed.pdf"
                let result = PdfExportResult(name: outputName, data: data, pageCount: item.pageCount)
                
                await MainActor.run {
                    self.signedExportResult = result
                    self.isProcessingExport = false
                    self.saveResultToDisk(result)
                }
            } catch {
                await MainActor.run {
                    self.isProcessingExport = false
                    self.exportErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func saveResultToDisk(_ result: PdfExportResult) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = result.name
        
        if panel.runModal() == .OK, let targetUrl = panel.url {
            try? result.data.write(to: targetUrl)
        }
    }
}

// MARK: - Signature Creation Sheet

struct SignatureCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (NSImage) -> Void
    
    @State private var selectedTab = 0
    
    // Draw Tab State
    @State private var drawingPaths: [Path] = []
    @State private var currentPath = Path()
    @State private var strokeColor: Color = .black
    @State private var strokeWidth: CGFloat = 3.0
    
    // Image Tab State
    @State private var importedImage: NSImage? = nil
    
    // Text Tab State
    @State private var typedText: String = "John Doe"
    @State private var selectedFontName: String = "Zapfino"
    @State private var textColor: Color = .blue
    
    let fontOptions = ["Zapfino", "Snell Roundhand", "Bradley Hand", "Helvetica Neue", "Times New Roman"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Signature")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Picker("", selection: $selectedTab) {
                Text("Draw").tag(0)
                Text("Upload Image").tag(1)
                Text("Type Text").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            Spacer()
            
            switch selectedTab {
            case 0:
                drawTabView
            case 1:
                uploadImageTabView
            default:
                typeTextTabView
            }
            
            Spacer()
            
            // Footer Action
            HStack {
                Button("Clear") {
                    drawingPaths.removeAll()
                    currentPath = Path()
                    importedImage = nil
                }
                Spacer()
                Button("Add to PDF") {
                    if let image = generateSignatureImage() {
                        onSave(image)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 480, height: 420)
    }
    
    // MARK: - Draw Tab
    
    private var drawTabView: some View {
        VStack(spacing: 8) {
            Color.white
                .overlay(
                    Canvas { context, size in
                        for path in drawingPaths {
                            context.stroke(path, with: .color(strokeColor), lineWidth: strokeWidth)
                        }
                        context.stroke(currentPath, with: .color(strokeColor), lineWidth: strokeWidth)
                    }
                )
                .cornerRadius(8)
                .border(Color.secondary.opacity(0.3), width: 1)
                .padding(.horizontal)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if currentPath.isEmpty {
                                currentPath.move(to: value.location)
                            } else {
                                currentPath.addLine(to: value.location)
                            }
                        }
                        .onEnded { _ in
                            drawingPaths.append(currentPath)
                            currentPath = Path()
                        }
                )
            
            HStack {
                ColorPicker("Color", selection: $strokeColor)
                Spacer()
                Text("Thickness:")
                    .font(.caption)
                Slider(value: $strokeWidth, in: 1...8)
                    .frame(width: 100)
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Upload Image Tab
    
    private var uploadImageTabView: some View {
        VStack(spacing: 12) {
            if let image = importedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(8)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("Select a signature image file (PNG with transparency recommended)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: 180)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            Button("Choose Image File...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.png, .jpeg]
                if panel.runModal() == .OK, let url = panel.url {
                    importedImage = NSImage(contentsOf: url)
                }
            }
        }
    }
    
    // MARK: - Type Text Tab
    
    private var typeTextTabView: some View {
        VStack(spacing: 16) {
            TextField("Type Signature Name", text: $typedText)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .padding(.horizontal)
            
            HStack {
                Picker("Font", selection: $selectedFontName) {
                    ForEach(fontOptions, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .frame(width: 220)
                
                ColorPicker("Color", selection: $textColor)
            }
            .padding(.horizontal)
            
            Text(typedText.isEmpty ? "Signature Preview" : typedText)
                .font(.custom(selectedFontName, size: 36))
                .foregroundColor(textColor)
                .padding()
                .frame(maxWidth: .infinity, minHeight: 100)
                .background(Color.white)
                .cornerRadius(8)
                .padding(.horizontal)
        }
    }
    
    private func generateSignatureImage() -> NSImage? {
        switch selectedTab {
        case 0:
            let size = CGSize(width: 400, height: 200)
            let img = NSImage(size: size)
            img.lockFocus()
            NSColor.clear.set()
            NSRect(origin: .zero, size: size).fill()
            
            let nsColor = NSColor(strokeColor)
            nsColor.setStroke()
            
            for path in drawingPaths {
                let cgPath = path.cgPath
                let nsBezier = NSBezierPath(cgPath: cgPath)
                nsBezier.lineWidth = strokeWidth
                nsBezier.stroke()
            }
            img.unlockFocus()
            return img
            
        case 1:
            return importedImage
            
        default:
            let text = typedText.isEmpty ? "Signature" : typedText
            let size = CGSize(width: 400, height: 120)
            let img = NSImage(size: size)
            img.lockFocus()
            NSColor.clear.set()
            NSRect(origin: .zero, size: size).fill()
            
            let font = NSFont(name: selectedFontName, size: 38) ?? NSFont.systemFont(ofSize: 38)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor(textColor)
            ]
            let attrStr = NSAttributedString(string: text, attributes: attrs)
            let strSize = attrStr.size()
            let rect = CGRect(
                x: (size.width - strSize.width) / 2.0,
                y: (size.height - strSize.height) / 2.0,
                width: strSize.width,
                height: strSize.height
            )
            attrStr.draw(in: rect)
            img.unlockFocus()
            return img
        }
    }
}
