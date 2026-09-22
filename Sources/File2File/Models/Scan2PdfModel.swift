import Foundation
import AppKit
import UniformTypeIdentifiers

public enum ScanPreset: String, CaseIterable, Identifiable {
    case autoEnhance = "Auto Enhance"
    case highContrastBW = "B&W Document"
    case grayscale = "Grayscale"
    case magicColor = "Magic Color"
    case original = "Original"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .autoEnhance: return "wand.and.stars"
        case .highContrastBW: return "doc.text.fill"
        case .grayscale: return "square.fill.and.line.grid.1x2"
        case .magicColor: return "paintpalette.fill"
        case .original: return "photo"
        }
    }
    
    public var description: String {
        switch self {
        case .autoEnhance: return "Automatically optimizes contrast, sharpness, and brightness for document clarity."
        case .highContrastBW: return "CamScanner-style crisp black & white binarization for clean printed & written text."
        case .grayscale: return "Smooth grayscale output removing color stains while maintaining document depth."
        case .magicColor: return "Boosts color vibrancy and flattens paper background shadows."
        case .original: return "Unprocessed original photo."
        }
    }
}

public struct ScanFineTuning: Hashable, Equatable {
    public var brightness: Double // -0.5 to 0.5, default 0.0
    public var contrast: Double   // 0.5 to 2.0, default 1.0
    public var sharpness: Double  // 0.0 to 2.0, default 0.0
    
    public init(brightness: Double = 0.0, contrast: Double = 1.0, sharpness: Double = 0.0) {
        self.brightness = brightness
        self.contrast = contrast
        self.sharpness = sharpness
    }
    
    public var isDefault: Bool {
        brightness == 0.0 && contrast == 1.0 && sharpness == 0.0
    }
}

public struct ScanPageItem: Identifiable, Hashable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let originalSize: Int64
    public let originalImage: NSImage
    
    public var preset: ScanPreset
    public var rotationDegrees: Int // 0, 90, 180, 270
    public var fineTuning: ScanFineTuning
    
    public var processedThumbnail: NSImage?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        originalSize: Int64,
        originalImage: NSImage,
        preset: ScanPreset = .autoEnhance,
        rotationDegrees: Int = 0,
        fineTuning: ScanFineTuning = ScanFineTuning(),
        processedThumbnail: NSImage? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.originalSize = originalSize
        self.originalImage = originalImage
        self.preset = preset
        self.rotationDegrees = rotationDegrees
        self.fineTuning = fineTuning
        self.processedThumbnail = processedThumbnail
    }
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(preset)
        hasher.combine(rotationDegrees)
        hasher.combine(fineTuning)
    }
    
    public static func == (lhs: ScanPageItem, rhs: ScanPageItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.preset == rhs.preset &&
        lhs.rotationDegrees == rhs.rotationDegrees &&
        lhs.fineTuning == rhs.fineTuning
    }
}

public enum ScanPdfCompressionQuality: Double, CaseIterable, Identifiable {
    case low = 0.5
    case medium = 0.75
    case high = 0.90
    case lossless = 1.0
    
    public var id: Double { rawValue }
    
    public var label: String {
        switch self {
        case .low: return "Compact (Low Quality / Small File)"
        case .medium: return "Balanced (Medium Quality)"
        case .high: return "High Resolution (High Quality)"
        case .lossless: return "Lossless / Original Detail"
        }
    }
}

public struct Scan2PdfOptions {
    public var pageSize: PdfPageSize
    public var orientation: PdfOrientation
    public var marginPoints: CGFloat
    public var compressionQuality: ScanPdfCompressionQuality
    public var pdfFileName: String
    
    public init(
        pageSize: PdfPageSize = .fitImage,
        orientation: PdfOrientation = .auto,
        marginPoints: CGFloat = 0,
        compressionQuality: ScanPdfCompressionQuality = .high,
        pdfFileName: String = "Scanned_Document.pdf"
    ) {
        self.pageSize = pageSize
        self.orientation = orientation
        self.marginPoints = marginPoints
        self.compressionQuality = compressionQuality
        self.pdfFileName = pdfFileName
    }
}
