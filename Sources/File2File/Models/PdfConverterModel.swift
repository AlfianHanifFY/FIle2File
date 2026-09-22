import Foundation
import AppKit
import UniformTypeIdentifiers

public enum PdfConverterMode: String, CaseIterable, Identifiable {
    case imageToPdf = "Image to PDF"
    case pdfToImage = "PDF to Image"
    case mergePdf = "Merge PDF"
    case splitPdf = "Split PDF"
    case signPdf = "Sign PDF"
    
    public var id: String { rawValue }
}

public enum PdfPageSize: String, CaseIterable, Identifiable {
    case fitImage = "Fit to Image"
    case a4 = "A4 (210 × 297 mm)"
    case letter = "US Letter (8.5 × 11 in)"
    
    public var id: String { rawValue }
    
    public var sizePoints: CGSize? {
        switch self {
        case .fitImage:
            return nil
        case .a4:
            return CGSize(width: 595.2, height: 841.8)
        case .letter:
            return CGSize(width: 612.0, height: 792.0)
        }
    }
}

public enum PdfOrientation: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case portrait = "Portrait"
    case landscape = "Landscape"
    
    public var id: String { rawValue }
}

public enum PdfImageOutputFormat: String, CaseIterable, Identifiable {
    case png = "PNG"
    case jpeg = "JPEG"
    case webp = "WebP"
    case tiff = "TIFF"
    
    public var id: String { rawValue }
    
    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .webp: return "webp"
        case .tiff: return "tiff"
        }
    }
    
    public var utType: UTType {
        switch self {
        case .png: return .png
        case .jpeg: return .jpeg
        case .webp: return .webP
        case .tiff: return .tiff
        }
    }
}

public enum PdfDPI: Int, CaseIterable, Identifiable {
    case standard = 72
    case medium = 150
    case high = 300
    
    public var id: Int { rawValue }
    
    public var label: String {
        switch self {
        case .standard: return "72 DPI (Web)"
        case .medium: return "150 DPI (Medium)"
        case .high: return "300 DPI (Print)"
        }
    }
}

public struct ImageToPdfOptions {
    public var pageSize: PdfPageSize
    public var orientation: PdfOrientation
    public var marginPoints: CGFloat
    public var mergeIntoSinglePdf: Bool
    public var pdfFileName: String
    
    public init(
        pageSize: PdfPageSize = .fitImage,
        orientation: PdfOrientation = .auto,
        marginPoints: CGFloat = 0,
        mergeIntoSinglePdf: Bool = true,
        pdfFileName: String = "Converted_Document.pdf"
    ) {
        self.pageSize = pageSize
        self.orientation = orientation
        self.marginPoints = marginPoints
        self.mergeIntoSinglePdf = mergeIntoSinglePdf
        self.pdfFileName = pdfFileName
    }
}

public struct PdfToImageOptions {
    public var targetFormat: PdfImageOutputFormat
    public var dpi: PdfDPI
    public var jpegQuality: Double
    
    public init(
        targetFormat: PdfImageOutputFormat = .png,
        dpi: PdfDPI = .medium,
        jpegQuality: Double = 0.85
    ) {
        self.targetFormat = targetFormat
        self.dpi = dpi
        self.jpegQuality = jpegQuality
    }
}

public struct ImageToPdfItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let originalSize: Int64
    public let image: NSImage?
    
    public init(id: UUID = UUID(), url: URL, name: String, originalSize: Int64, image: NSImage?) {
        self.id = id
        self.url = url
        self.name = name
        self.originalSize = originalSize
        self.image = image
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ImageToPdfItem, rhs: ImageToPdfItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct PdfToImageItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let originalSize: Int64
    public let pageCount: Int
    
    public init(id: UUID = UUID(), url: URL, name: String, originalSize: Int64, pageCount: Int) {
        self.id = id
        self.url = url
        self.name = name
        self.originalSize = originalSize
        self.pageCount = pageCount
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: PdfToImageItem, rhs: PdfToImageItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct PdfExportResult: Identifiable {
    public let id = UUID()
    public let name: String
    public let data: Data
    public let pageCount: Int
    
    public init(name: String, data: Data, pageCount: Int) {
        self.name = name
        self.data = data
        self.pageCount = pageCount
    }
}

public struct RenderedPageItem: Identifiable, Hashable {
    public let id = UUID()
    public let pageNumber: Int
    public let name: String
    public let image: NSImage
    public let data: Data
    public let sizeBytes: Int64
    
    public init(pageNumber: Int, name: String, image: NSImage, data: Data, sizeBytes: Int64) {
        self.pageNumber = pageNumber
        self.name = name
        self.image = image
        self.data = data
        self.sizeBytes = sizeBytes
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: RenderedPageItem, rhs: RenderedPageItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct MergePdfOptions {
    public var outputFileName: String
    
    public init(outputFileName: String = "Merged_Document.pdf") {
        self.outputFileName = outputFileName
    }
}

public struct MergePdfItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let originalSize: Int64
    public let pageCount: Int
    
    public init(id: UUID = UUID(), url: URL, name: String, originalSize: Int64, pageCount: Int) {
        self.id = id
        self.url = url
        self.name = name
        self.originalSize = originalSize
        self.pageCount = pageCount
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MergePdfItem, rhs: MergePdfItem) -> Bool {
        lhs.id == rhs.id
    }
}

public enum PdfSplitMode: String, CaseIterable, Identifiable {
    case customRanges = "Custom Ranges"
    case fixedChunks = "Fixed Chunks"
    case singlePages = "Single Pages"
    
    public var id: String { rawValue }
}

public struct PdfSplitOptions {
    public var mode: PdfSplitMode
    public var rangeString: String
    public var chunkSize: Int
    public var outputPrefix: String
    public var combineSelectedRanges: Bool
    
    public init(
        mode: PdfSplitMode = .customRanges,
        rangeString: String = "1",
        chunkSize: Int = 2,
        outputPrefix: String = "Split_Page",
        combineSelectedRanges: Bool = false
    ) {
        self.mode = mode
        self.rangeString = rangeString
        self.chunkSize = chunkSize
        self.outputPrefix = outputPrefix
        self.combineSelectedRanges = combineSelectedRanges
    }
}

public struct PdfSplitPageThumbnail: Identifiable, Hashable {
    public let id: UUID
    public let pageNumber: Int
    public let image: NSImage
    
    public init(id: UUID = UUID(), pageNumber: Int, image: NSImage) {
        self.id = id
        self.pageNumber = pageNumber
        self.image = image
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: PdfSplitPageThumbnail, rhs: PdfSplitPageThumbnail) -> Bool {
        lhs.id == rhs.id
    }
}

public struct VisualSignatureOverlay: Identifiable, Hashable {
    public let id: UUID
    public var image: NSImage
    public var pageIndex: Int
    // Normalized position relative to page bounds (0.0 to 1.0)
    public var position: CGPoint
    // Normalized size relative to page bounds (0.0 to 1.0)
    public var size: CGSize
    
    public init(
        id: UUID = UUID(),
        image: NSImage,
        pageIndex: Int,
        position: CGPoint = CGPoint(x: 0.5, y: 0.2),
        size: CGSize = CGSize(width: 0.3, height: 0.1)
    ) {
        self.id = id
        self.image = image
        self.pageIndex = pageIndex
        self.position = position
        self.size = size
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: VisualSignatureOverlay, rhs: VisualSignatureOverlay) -> Bool {
        lhs.id == rhs.id
    }
}

public struct DigitalSignatureConfig {
    public var certificateURL: URL?
    public var password: String
    public var reason: String
    public var location: String
    public var contactInfo: String
    
    public init(
        certificateURL: URL? = nil,
        password: String = "",
        reason: String = "Approved document signature",
        location: String = "",
        contactInfo: String = ""
    ) {
        self.certificateURL = certificateURL
        self.password = password
        self.reason = reason
        self.location = location
        self.contactInfo = contactInfo
    }
}

public struct PdfSignItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let originalSize: Int64
    public let pageCount: Int
    
    public init(id: UUID = UUID(), url: URL, name: String, originalSize: Int64, pageCount: Int) {
        self.id = id
        self.url = url
        self.name = name
        self.originalSize = originalSize
        self.pageCount = pageCount
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: PdfSignItem, rhs: PdfSignItem) -> Bool {
        lhs.id == rhs.id
    }
}



