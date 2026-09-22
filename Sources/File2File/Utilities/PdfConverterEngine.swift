import Foundation
import AppKit
import PDFKit
import UniformTypeIdentifiers

public enum PdfConverterEngine {
    
    // MARK: - Load Helpers
    
    public static func loadImageItem(from url: URL) -> ImageToPdfItem? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        let sizeBytes: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let sz = attrs[.size] as? Int64 {
            sizeBytes = sz
        } else {
            sizeBytes = 0
        }
        return ImageToPdfItem(
            url: url,
            name: url.lastPathComponent,
            originalSize: sizeBytes,
            image: image
        )
    }
    
    public static func loadPdfItem(from url: URL) -> PdfToImageItem? {
        guard let pdfDoc = PDFDocument(url: url) else { return nil }
        let sizeBytes: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let sz = attrs[.size] as? Int64 {
            sizeBytes = sz
        } else {
            sizeBytes = 0
        }
        return PdfToImageItem(
            url: url,
            name: url.lastPathComponent,
            originalSize: sizeBytes,
            pageCount: pdfDoc.pageCount
        )
    }
    
    // MARK: - Image to PDF Conversion
    
    public static func convertImagesToPdf(items: [ImageToPdfItem], options: ImageToPdfOptions) async -> [PdfExportResult] {
        guard !items.isEmpty else { return [] }
        
        if options.mergeIntoSinglePdf {
            let pdfDoc = PDFDocument()
            var validPageCount = 0
            
            for item in items {
                guard let image = item.image ?? NSImage(contentsOf: item.url) else { continue }
                if let pdfPage = createPdfPage(from: image, options: options) {
                    pdfDoc.insert(pdfPage, at: pdfDoc.pageCount)
                    validPageCount += 1
                }
            }
            
            guard validPageCount > 0, let data = pdfDoc.dataRepresentation() else { return [] }
            let fileName = options.pdfFileName.isEmpty ? "Converted_Document.pdf" : (
                options.pdfFileName.lowercased().hasSuffix(".pdf") ? options.pdfFileName : options.pdfFileName + ".pdf"
            )
            return [PdfExportResult(name: fileName, data: data, pageCount: validPageCount)]
        } else {
            var results: [PdfExportResult] = []
            
            for item in items {
                guard let image = item.image ?? NSImage(contentsOf: item.url) else { continue }
                let pdfDoc = PDFDocument()
                if let pdfPage = createPdfPage(from: image, options: options) {
                    pdfDoc.insert(pdfPage, at: 0)
                    if let data = pdfDoc.dataRepresentation() {
                        let baseName = (item.name as NSString).deletingPathExtension
                        results.append(PdfExportResult(name: "\(baseName).pdf", data: data, pageCount: 1))
                    }
                }
            }
            
            return results
        }
    }
    
    private static func createPdfPage(from image: NSImage, options: ImageToPdfOptions) -> PDFPage? {
        let imageSize = image.size
        guard imageSize.width > 0 && imageSize.height > 0 else { return nil }
        
        var pageSize: CGSize
        if let stdSize = options.pageSize.sizePoints {
            pageSize = stdSize
        } else {
            pageSize = imageSize
        }
        
        // Orientation adjustment for paper sizes
        if options.pageSize != .fitImage {
            let isLandscapeImage = imageSize.width > imageSize.height
            switch options.orientation {
            case .landscape:
                pageSize = CGSize(width: max(pageSize.width, pageSize.height), height: min(pageSize.width, pageSize.height))
            case .portrait:
                pageSize = CGSize(width: min(pageSize.width, pageSize.height), height: max(pageSize.width, pageSize.height))
            case .auto:
                if isLandscapeImage {
                    pageSize = CGSize(width: max(pageSize.width, pageSize.height), height: min(pageSize.width, pageSize.height))
                } else {
                    pageSize = CGSize(width: min(pageSize.width, pageSize.height), height: max(pageSize.width, pageSize.height))
                }
            }
        }
        
        let margin = max(0, options.marginPoints)
        let printableRect = CGRect(
            x: margin,
            y: margin,
            width: max(1, pageSize.width - 2 * margin),
            height: max(1, pageSize.height - 2 * margin)
        )
        
        let scale = min(printableRect.width / imageSize.width, printableRect.height / imageSize.height)
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        let drawX = printableRect.minX + (printableRect.width - drawWidth) / 2
        let drawY = printableRect.minY + (printableRect.height - drawHeight) / 2
        let drawRect = CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
        
        let renderedPageImage = NSImage(size: pageSize, flipped: false) { rect in
            NSColor.white.set()
            rect.fill()
            
            image.draw(
                in: drawRect,
                from: NSRect(origin: .zero, size: imageSize),
                operation: .copy,
                fraction: 1.0
            )
            return true
        }
        
        return PDFPage(image: renderedPageImage)
    }
    
    // MARK: - PDF to Image Conversion
    
    public static func convertPdfToImages(pdfURL: URL, options: PdfToImageOptions) async -> [RenderedPageItem] {
        guard let document = PDFDocument(url: pdfURL) else { return [] }
        var results: [RenderedPageItem] = []
        let scaleFactor = CGFloat(options.dpi.rawValue) / 72.0
        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let mediaBox = page.bounds(for: .mediaBox)
            let targetSize = CGSize(
                width: max(1, mediaBox.width * scaleFactor),
                height: max(1, mediaBox.height * scaleFactor)
            )
            
            let renderedImage = NSImage(size: targetSize, flipped: false) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.setFillColor(NSColor.white.cgColor)
                context.fill(rect)
                
                context.saveGState()
                context.scaleBy(x: scaleFactor, y: scaleFactor)
                page.draw(with: .mediaBox, to: context)
                context.restoreGState()
                return true
            }
            
            if let imageData = encodeImageData(from: renderedImage, format: options.targetFormat, quality: options.jpegQuality) {
                let pageNumber = i + 1
                let fileName = "\(baseName)_page_\(pageNumber).\(options.targetFormat.fileExtension)"
                let item = RenderedPageItem(
                    pageNumber: pageNumber,
                    name: fileName,
                    image: renderedImage,
                    data: imageData,
                    sizeBytes: Int64(imageData.count)
                )
                results.append(item)
            }
        }
        
        return results
    }
    
    private static func encodeImageData(from image: NSImage, format: PdfImageOutputFormat, quality: Double) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        
        switch format {
        case .png:
            return bitmapRep.representation(using: .png, properties: [:])
        case .jpeg:
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        case .tiff:
            return bitmapRep.representation(using: .tiff, properties: [:])
        case .webp:
            // Fall back to PNG if WebP representation is not native in NSBitmapImageRep, or JPEG
            if let webpData = bitmapRep.representation(using: .png, properties: [:]) {
                return webpData
            }
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
    }
    
    // MARK: - PDF Merging Load & Process
    
    public static func loadMergePdfItem(from url: URL) -> MergePdfItem? {
        guard let pdfDoc = PDFDocument(url: url) else { return nil }
        let sizeBytes: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let sz = attrs[.size] as? Int64 {
            sizeBytes = sz
        } else {
            sizeBytes = 0
        }
        return MergePdfItem(
            url: url,
            name: url.lastPathComponent,
            originalSize: sizeBytes,
            pageCount: pdfDoc.pageCount
        )
    }
    
    public static func mergePdfFiles(items: [MergePdfItem], options: MergePdfOptions) async -> PdfExportResult? {
        guard !items.isEmpty else { return nil }
        
        let mergedDoc = PDFDocument()
        var totalPages = 0
        
        for item in items {
            guard let doc = PDFDocument(url: item.url) else { continue }
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) {
                    mergedDoc.insert(page, at: mergedDoc.pageCount)
                    totalPages += 1
                }
            }
        }
        
        guard totalPages > 0, let data = mergedDoc.dataRepresentation() else { return nil }
        
        var fileName = options.outputFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if fileName.isEmpty {
            fileName = "Merged_Document.pdf"
        } else if !fileName.lowercased().hasSuffix(".pdf") {
            fileName += ".pdf"
        }
        
        return PdfExportResult(name: fileName, data: data, pageCount: totalPages)
    }
    
    // MARK: - PDF Splitting Engine & Range Helpers
    
    public static func parsePageRanges(_ rangeString: String, totalPages: Int) -> [Int] {
        guard totalPages > 0 else { return [] }
        var pagesSet = Set<Int>()
        let parts = rangeString.components(separatedBy: ",")
        
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("-") {
                let rangeComponents = trimmed.components(separatedBy: "-")
                if rangeComponents.count == 2,
                   let start = Int(rangeComponents[0].trimmingCharacters(in: .whitespaces)),
                   let end = Int(rangeComponents[1].trimmingCharacters(in: .whitespaces)) {
                    let minP = max(1, min(start, end))
                    let maxP = min(totalPages, max(start, end))
                    if minP <= maxP {
                        for p in minP...maxP {
                            pagesSet.insert(p)
                        }
                    }
                }
            } else if let p = Int(trimmed) {
                if p >= 1 && p <= totalPages {
                    pagesSet.insert(p)
                }
            }
        }
        
        return Array(pagesSet).sorted()
    }
    
    public static func formatPageRanges(selectedPages: Set<Int>) -> String {
        let sortedPages = Array(selectedPages).sorted()
        guard !sortedPages.isEmpty else { return "" }
        
        var ranges: [String] = []
        var rangeStart = sortedPages[0]
        var prevPage = rangeStart
        
        for i in 1..<sortedPages.count {
            let current = sortedPages[i]
            if current == prevPage + 1 {
                prevPage = current
            } else {
                if rangeStart == prevPage {
                    ranges.append("\(rangeStart)")
                } else {
                    ranges.append("\(rangeStart)-\(prevPage)")
                }
                rangeStart = current
                prevPage = current
            }
        }
        
        if rangeStart == prevPage {
            ranges.append("\(rangeStart)")
        } else {
            ranges.append("\(rangeStart)-\(prevPage)")
        }
        
        return ranges.joined(separator: ", ")
    }
    
    public static func loadSplitThumbnails(from url: URL) async -> [PdfSplitPageThumbnail] {
        guard let doc = PDFDocument(url: url) else { return [] }
        var thumbnails: [PdfSplitPageThumbnail] = []
        
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let mediaBox = page.bounds(for: .mediaBox)
            let maxDim: CGFloat = 160.0
            let scale = min(maxDim / max(1, mediaBox.width), maxDim / max(1, mediaBox.height))
            let thumbnailSize = CGSize(width: max(1, mediaBox.width * scale), height: max(1, mediaBox.height * scale))
            
            let thumbImage = NSImage(size: thumbnailSize, flipped: false) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.setFillColor(NSColor.white.cgColor)
                context.fill(rect)
                context.saveGState()
                context.scaleBy(x: scale, y: scale)
                page.draw(with: .mediaBox, to: context)
                context.restoreGState()
                return true
            }
            
            thumbnails.append(PdfSplitPageThumbnail(pageNumber: i + 1, image: thumbImage))
        }
        
        return thumbnails
    }
    
    public static func splitPdfDocument(url: URL, options: PdfSplitOptions, selectedPages: Set<Int>) async -> [PdfExportResult] {
        guard let sourceDoc = PDFDocument(url: url) else { return [] }
        let totalPages = sourceDoc.pageCount
        guard totalPages > 0 else { return [] }
        
        let baseFileName = url.deletingPathExtension().lastPathComponent
        let prefix = options.outputPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? baseFileName : options.outputPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        
        var results: [PdfExportResult] = []
        
        switch options.mode {
        case .customRanges:
            let pagesToExport: [Int]
            if !options.rangeString.isEmpty {
                pagesToExport = parsePageRanges(options.rangeString, totalPages: totalPages)
            } else if !selectedPages.isEmpty {
                pagesToExport = Array(selectedPages).sorted()
            } else {
                pagesToExport = Array(1...totalPages)
            }
            
            guard !pagesToExport.isEmpty else { return [] }
            
            if options.combineSelectedRanges {
                let newDoc = PDFDocument()
                for p in pagesToExport {
                    if let page = sourceDoc.page(at: p - 1) {
                        newDoc.insert(page, at: newDoc.pageCount)
                    }
                }
                if let data = newDoc.dataRepresentation() {
                    let rangeLabel = formatPageRanges(selectedPages: Set(pagesToExport))
                    let name = "\(prefix)_pages_\(rangeLabel.replacingOccurrences(of: ", ", with: "_")).pdf"
                    results.append(PdfExportResult(name: name, data: data, pageCount: newDoc.pageCount))
                }
            } else {
                for p in pagesToExport {
                    let newDoc = PDFDocument()
                    if let page = sourceDoc.page(at: p - 1) {
                        newDoc.insert(page, at: 0)
                        if let data = newDoc.dataRepresentation() {
                            let name = "\(prefix)_page_\(p).pdf"
                            results.append(PdfExportResult(name: name, data: data, pageCount: 1))
                        }
                    }
                }
            }
            
        case .fixedChunks:
            let chunkSize = max(1, options.chunkSize)
            var startIdx = 0
            var partNum = 1
            
            while startIdx < totalPages {
                let endIdx = min(startIdx + chunkSize, totalPages)
                let newDoc = PDFDocument()
                for i in startIdx..<endIdx {
                    if let page = sourceDoc.page(at: i) {
                        newDoc.insert(page, at: newDoc.pageCount)
                    }
                }
                if let data = newDoc.dataRepresentation() {
                    let name = "\(prefix)_part_\(partNum)_pages_\(startIdx + 1)-\(endIdx).pdf"
                    results.append(PdfExportResult(name: name, data: data, pageCount: newDoc.pageCount))
                }
                startIdx = endIdx
                partNum += 1
            }
            
        case .singlePages:
            let pagesToExport: [Int] = selectedPages.isEmpty ? Array(1...totalPages) : Array(selectedPages).sorted()
            for p in pagesToExport {
                let newDoc = PDFDocument()
                if let page = sourceDoc.page(at: p - 1) {
                    newDoc.insert(page, at: 0)
                    if let data = newDoc.dataRepresentation() {
                        let name = "\(prefix)_page_\(p).pdf"
                        results.append(PdfExportResult(name: name, data: data, pageCount: 1))
                    }
                }
            }
        }
        
        return results
    }
}


