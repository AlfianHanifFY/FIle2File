import Foundation
import CoreGraphics

public enum VideoToGifResolution: String, CaseIterable, Identifiable {
    case original = "Original"
    case p720 = "720p (HD)"
    case p480 = "480p (SD)"
    case p360 = "360p"
    case p240 = "240p"
    
    public var id: String { rawValue }
    
    public var targetWidth: CGFloat? {
        switch self {
        case .original: return nil
        case .p720: return 1280
        case .p480: return 854
        case .p360: return 640
        case .p240: return 426
        }
    }
}

public struct VideoToGifOptions: Equatable {
    public var startTime: Double
    public var endTime: Double
    public var fps: Int
    public var resolution: VideoToGifResolution
    public var speedMultiplier: Double
    public var loopCount: Int // 0 = infinite loop
    
    public init(
        startTime: Double = 0,
        endTime: Double = 0,
        fps: Int = 15,
        resolution: VideoToGifResolution = .p480,
        speedMultiplier: Double = 1.0,
        loopCount: Int = 0
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.fps = fps
        self.resolution = resolution
        self.speedMultiplier = speedMultiplier
        self.loopCount = loopCount
    }
}

public struct VideoToGifItem: Identifiable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let totalDuration: Double
    public let originalSize: CGSize
    public let fileSizeByteCount: Int64
    
    public var options: VideoToGifOptions
    public var gifData: Data?
    public var isConverting: Bool
    public var progress: Double
    public var errorMessage: String?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        totalDuration: Double,
        originalSize: CGSize,
        fileSizeByteCount: Int64,
        options: VideoToGifOptions,
        gifData: Data? = nil,
        isConverting: Bool = false,
        progress: Double = 0.0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.totalDuration = totalDuration
        self.originalSize = originalSize
        self.fileSizeByteCount = fileSizeByteCount
        self.options = options
        self.gifData = gifData
        self.isConverting = isConverting
        self.progress = progress
        self.errorMessage = errorMessage
    }
    
    public var formattedOriginalFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeByteCount, countStyle: .file)
    }
    
    public var formattedGifFileSize: String? {
        guard let data = gifData else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}
