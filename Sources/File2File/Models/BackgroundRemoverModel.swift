import Foundation
import AppKit
import SwiftUI

public enum BackgroundFillType: String, CaseIterable, Identifiable, Codable {
    case transparent = "Transparent"
    case solidWhite = "White"
    case solidBlack = "Black"
    case customColor = "Custom Color"
    case customImage = "Custom Image"
    
    public var id: String { rawValue }
}

public enum BackgroundRemoverOutputFormat: String, CaseIterable, Identifiable, Codable {
    case png = "PNG (Transparent)"
    case heic = "HEIC"
    case jpeg = "JPEG"
    
    public var id: String { rawValue }
    
    public var fileExtension: String {
        switch self {
        case .png: return "png"
        case .heic: return "heic"
        case .jpeg: return "jpg"
        }
    }
    
    public var utiType: String {
        switch self {
        case .png: return "public.png"
        case .heic: return "public.heic"
        case .jpeg: return "public.jpeg"
        }
    }
}

public struct BackgroundRemoverConfig: Equatable {
    public var fillType: BackgroundFillType
    public var customColor: Color
    public var customBgImageData: Data?
    public var outputFormat: BackgroundRemoverOutputFormat
    
    public init(
        fillType: BackgroundFillType = .transparent,
        customColor: Color = .blue,
        customBgImageData: Data? = nil,
        outputFormat: BackgroundRemoverOutputFormat = .png
    ) {
        self.fillType = fillType
        self.customColor = customColor
        self.customBgImageData = customBgImageData
        self.outputFormat = outputFormat
    }
}

public struct BackgroundRemoverItem: Identifiable, Equatable {
    public let id: UUID
    public var url: URL?
    public var name: String
    public var originalData: Data
    public var originalSize: Int64
    public var originalWidth: Int
    public var originalHeight: Int
    
    public var processedData: Data?
    public var processedSize: Int64?
    public var isProcessing: Bool
    public var errorMessage: String?
    
    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        name: String,
        originalData: Data,
        originalSize: Int64,
        originalWidth: Int,
        originalHeight: Int
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.originalData = originalData
        self.originalSize = originalSize
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.processedData = nil
        self.processedSize = nil
        self.isProcessing = false
        self.errorMessage = nil
    }
    
    public static func == (lhs: BackgroundRemoverItem, rhs: BackgroundRemoverItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.processedSize == rhs.processedSize &&
        lhs.isProcessing == rhs.isProcessing &&
        lhs.errorMessage == rhs.errorMessage
    }
    
    public var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    public var formattedProcessedSize: String {
        guard let size = processedSize else { return "-" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
