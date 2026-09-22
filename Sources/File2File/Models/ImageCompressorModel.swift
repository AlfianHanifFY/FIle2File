import Foundation
import AppKit

public enum CompressionTargetMode: String, CaseIterable, Identifiable, Codable {
    case byPercentage = "By Percentage / Quality"
    case byTargetSize = "By Target File Size"
    
    public var id: String { rawValue }
}

public enum TargetSizeUnit: String, CaseIterable, Identifiable, Codable {
    case kb = "KB"
    case mb = "MB"
    
    public var id: String { rawValue }
    
    public var bytesMultiplier: Int64 {
        switch self {
        case .kb: return 1024
        case .mb: return 1024 * 1024
        }
    }
}

public enum ImageOutputFormat: String, CaseIterable, Identifiable, Codable {
    case auto = "Match Original (or JPEG)"
    case jpeg = "JPEG"
    case png = "PNG"
    case heic = "HEIC"
    
    public var id: String { rawValue }
    
    public var fileExtension: String {
        switch self {
        case .auto: return "jpg"
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }
    
    public var utiType: String {
        switch self {
        case .auto, .jpeg: return "public.jpeg"
        case .png: return "public.png"
        case .heic: return "public.heic"
        }
    }
}

public struct ImageItem: Identifiable, Equatable {
    public let id: UUID
    public var url: URL?
    public var name: String
    public var originalData: Data
    public var originalSize: Int64
    public var originalWidth: Int
    public var originalHeight: Int
    public var originalFormat: String
    
    public var compressedData: Data?
    public var compressedSize: Int64?
    public var compressedWidth: Int?
    public var compressedHeight: Int?
    public var appliedQuality: Double?
    public var isCompressing: Bool
    public var errorMessage: String?
    
    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        name: String,
        originalData: Data,
        originalSize: Int64,
        originalWidth: Int,
        originalHeight: Int,
        originalFormat: String
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.originalData = originalData
        self.originalSize = originalSize
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.originalFormat = originalFormat
        self.compressedData = nil
        self.compressedSize = nil
        self.compressedWidth = nil
        self.compressedHeight = nil
        self.appliedQuality = nil
        self.isCompressing = false
        self.errorMessage = nil
    }
    
    public static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.compressedSize == rhs.compressedSize &&
        lhs.isCompressing == rhs.isCompressing
    }
    
    public var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public var formattedCompressedSize: String {
        guard let size = compressedSize else { return "-" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    public var savingsBytes: Int64 {
        guard let comp = compressedSize else { return 0 }
        return max(0, originalSize - comp)
    }
    
    public var savingsPercentage: Double {
        guard let comp = compressedSize, originalSize > 0 else { return 0 }
        let saved = Double(originalSize - comp)
        return (saved / Double(originalSize)) * 100.0
    }
    
    public var savingsPercentageString: String {
        let percent = savingsPercentage
        if percent > 0 {
            return String(format: "-%.1f%%", percent)
        } else if percent < 0 {
            return String(format: "+%.1f%%", abs(percent))
        } else {
            return "0%"
        }
    }
}
