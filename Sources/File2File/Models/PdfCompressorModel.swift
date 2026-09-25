import Foundation
import AppKit

public enum PdfCompressorPreset: String, CaseIterable, Identifiable, Codable {
    case low = "Low Compression (High Quality)"
    case medium = "Balanced (Medium Quality)"
    case high = "High Compression (Small File)"
    case custom = "Custom Settings"
    
    public var id: String { rawValue }
    
    public var defaultQuality: Double {
        switch self {
        case .low: return 80.0
        case .medium: return 55.0
        case .high: return 35.0
        case .custom: return 60.0
        }
    }
    
    public var defaultDpi: PdfDpiLimit {
        switch self {
        case .low: return .dpi300
        case .medium: return .dpi150
        case .high: return .dpi72
        case .custom: return .dpi150
        }
    }
}

public enum PdfDpiLimit: String, CaseIterable, Identifiable, Codable {
    case original = "Original Resolution"
    case dpi300 = "300 DPI (Print Quality)"
    case dpi150 = "150 DPI (Standard Screen)"
    case dpi72 = "72 DPI (Web / Compact)"
    
    public var id: String { rawValue }
    
    public var dpiValue: CGFloat? {
        switch self {
        case .original: return nil
        case .dpi300: return 300.0
        case .dpi150: return 150.0
        case .dpi72: return 72.0
        }
    }
}

public struct PdfCompressorOptions: Equatable {
    public var preset: PdfCompressorPreset
    public var qualityPercent: Double // 10.0 ... 100.0
    public var targetDpi: PdfDpiLimit
    public var stripMetadata: Bool
    public var outputSuffix: String
    public var overwriteOriginal: Bool
    public var customOutputFolder: URL?
    
    public init(
        preset: PdfCompressorPreset = .medium,
        qualityPercent: Double = 55.0,
        targetDpi: PdfDpiLimit = .dpi150,
        stripMetadata: Bool = true,
        outputSuffix: String = "_compressed",
        overwriteOriginal: Bool = false,
        customOutputFolder: URL? = nil
    ) {
        self.preset = preset
        self.qualityPercent = qualityPercent
        self.targetDpi = targetDpi
        self.stripMetadata = stripMetadata
        self.outputSuffix = outputSuffix
        self.overwriteOriginal = overwriteOriginal
        self.customOutputFolder = customOutputFolder
    }
}

public enum PdfCompressorStatus: Equatable {
    case idle
    case processing(progress: Double)
    case completed
    case failed(String)
}

public struct PdfCompressorItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let originalSize: Int64
    public let pageCount: Int
    
    public var compressedSize: Int64?
    public var compressedUrl: URL?
    public var status: PdfCompressorStatus
    public var errorMessage: String?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        originalSize: Int64,
        pageCount: Int,
        compressedSize: Int64? = nil,
        compressedUrl: URL? = nil,
        status: PdfCompressorStatus = .idle,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.originalSize = originalSize
        self.pageCount = pageCount
        self.compressedSize = compressedSize
        self.compressedUrl = compressedUrl
        self.status = status
        self.errorMessage = errorMessage
    }
    
    public var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public var formattedCompressedSize: String? {
        guard let size = compressedSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    public var savingsRatioPercent: Double? {
        guard let compressedSize = compressedSize, originalSize > 0 else { return nil }
        let diff = Double(originalSize - compressedSize)
        return (diff / Double(originalSize)) * 100.0
    }
}
