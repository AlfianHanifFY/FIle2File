import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

public struct ImageCompressionConfig {
    public var mode: CompressionTargetMode
    public var qualityPercent: Double // 1.0 ... 100.0
    public var targetSizeBytes: Int64
    public var outputFormat: ImageOutputFormat
    public var maxDimension: Int? // Optional max width/height in pixels
    
    public init(
        mode: CompressionTargetMode = .byPercentage,
        qualityPercent: Double = 80.0,
        targetSizeBytes: Int64 = 500 * 1024,
        outputFormat: ImageOutputFormat = .auto,
        maxDimension: Int? = nil
    ) {
        self.mode = mode
        self.qualityPercent = qualityPercent
        self.targetSizeBytes = targetSizeBytes
        self.outputFormat = outputFormat
        self.maxDimension = maxDimension
    }
}

public class ImageCompressor {
    
    /// Extract metadata and create an initial ImageItem from a File URL
    public static func loadItem(from url: URL) -> ImageItem? {
        guard let data = try? Data(contentsOf: url),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let format = url.pathExtension.uppercased()
        
        let originalSize = Int64(data.count)
        
        return ImageItem(
            url: url,
            name: url.lastPathComponent,
            originalData: data,
            originalSize: originalSize,
            originalWidth: width,
            originalHeight: height,
            originalFormat: format.isEmpty ? "IMAGE" : format
        )
    }
    
    /// Extract metadata from Data directly
    public static func loadItem(from data: Data, name: String = "Dropped Image.jpg") -> ImageItem? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        
        return ImageItem(
            url: nil,
            name: name,
            originalData: data,
            originalSize: Int64(data.count),
            originalWidth: width,
            originalHeight: height,
            originalFormat: "IMAGE"
        )
    }

    /// Primary async compression entry point
    public static func compress(_ item: ImageItem, config: ImageCompressionConfig) async -> ImageItem {
        return await Task.detached(priority: .userInitiated) {
            var updatedItem = item
            updatedItem.isCompressing = true
            updatedItem.errorMessage = nil
            
            guard let imageSource = CGImageSourceCreateWithData(item.originalData as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                updatedItem.isCompressing = false
                updatedItem.errorMessage = "Failed to parse original image data."
                return updatedItem
            }
            
            // Determine effective target format
            let targetFormat = resolveFormat(config.outputFormat, originalFormat: item.originalFormat)
            
            switch config.mode {
            case .byPercentage:
                let quality = max(min(config.qualityPercent / 100.0, 1.0), 0.01)
                let res = encode(cgImage: cgImage, quality: quality, format: targetFormat, maxDimension: config.maxDimension)
                
                if let (compressedData, finalWidth, finalHeight) = res {
                    updatedItem.compressedData = compressedData
                    updatedItem.compressedSize = Int64(compressedData.count)
                    updatedItem.compressedWidth = finalWidth
                    updatedItem.compressedHeight = finalHeight
                    updatedItem.appliedQuality = quality
                } else {
                    updatedItem.errorMessage = "Compression encoding failed."
                }
                
            case .byTargetSize:
                let targetBytes = config.targetSizeBytes
                let res = compressToTargetSize(cgImage: cgImage, targetBytes: targetBytes, format: targetFormat, maxDimension: config.maxDimension)
                
                if let (compressedData, finalWidth, finalHeight, bestQuality) = res {
                    updatedItem.compressedData = compressedData
                    updatedItem.compressedSize = Int64(compressedData.count)
                    updatedItem.compressedWidth = finalWidth
                    updatedItem.compressedHeight = finalHeight
                    updatedItem.appliedQuality = bestQuality
                } else {
                    updatedItem.errorMessage = "Could not compress image down to target file size."
                }
            }
            
            updatedItem.isCompressing = false
            return updatedItem
        }.value
    }
    
    // MARK: - Core Compression Helpers
    
    private static func resolveFormat(_ format: ImageOutputFormat, originalFormat: String) -> ImageOutputFormat {
        if format != .auto {
            return format
        }
        let upper = originalFormat.uppercased()
        if upper.contains("PNG") {
            return .png
        } else if upper.contains("HEIC") || upper.contains("HEIF") {
            return .heic
        } else {
            return .jpeg
        }
    }
    
    /// Encodes a CGImage to specified output format and quality
    private static func encode(
        cgImage: CGImage,
        quality: Double,
        format: ImageOutputFormat,
        maxDimension: Int?
    ) -> (Data, Int, Int)? {
        let (processedImage, width, height) = resizeIfNeeded(cgImage: cgImage, maxDimension: maxDimension)
        
        let mutableData = NSMutableData()
        let utiStr: CFString
        
        switch format {
        case .png:
            utiStr = UTType.png.identifier as CFString
        case .heic:
            utiStr = UTType.heic.identifier as CFString
        case .jpeg, .auto:
            utiStr = UTType.jpeg.identifier as CFString
        }
        
        guard let destination = CGImageDestinationCreateWithData(mutableData as CFMutableData, utiStr, 1, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality as CFNumber
        ]
        
        CGImageDestinationAddImage(destination, processedImage, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return (mutableData as Data, width, height)
    }
    
    /// Smart search to compress an image so its encoded byte size is <= targetBytes
    private static func compressToTargetSize(
        cgImage: CGImage,
        targetBytes: Int64,
        format: ImageOutputFormat,
        maxDimension: Int?
    ) -> (Data, Int, Int, Double)? {
        
        let currentDimension = maxDimension
        let currentImage = cgImage
        let originalMaxDim = max(cgImage.width, cgImage.height)
        
        // Downscale scale factor loop if needed
        var scaleFactor: Double = 1.0
        
        while scaleFactor >= 0.1 {
            let targetMaxDim: Int
            if let userMax = currentDimension {
                targetMaxDim = min(userMax, Int(Double(originalMaxDim) * scaleFactor))
            } else {
                targetMaxDim = Int(Double(originalMaxDim) * scaleFactor)
            }
            
            // Binary search quality range 0.05 ... 1.0
            var low: Double = 0.02
            var high: Double = 1.0
            var bestResult: (Data, Int, Int)? = nil
            var bestQuality: Double = 1.0
            
            for _ in 0..<8 { // 8 iterations of binary search is very accurate & fast
                let mid = (low + high) / 2.0
                if let encoded = encode(cgImage: currentImage, quality: mid, format: format, maxDimension: targetMaxDim) {
                    if encoded.0.count <= targetBytes {
                        bestResult = encoded
                        bestQuality = mid
                        low = mid // try higher quality if still under target
                    } else {
                        high = mid // quality too high, try lower quality
                    }
                } else {
                    high = mid
                }
            }
            
            if let result = bestResult {
                return (result.0, result.1, result.2, bestQuality)
            }
            
            // If even lowest quality at current scale couldn't meet target size, scale dimensions down
            scaleFactor -= 0.15
        }
        
        // Fallback to lowest possible quality at 10% scale if impossible
        if let fallback = encode(cgImage: currentImage, quality: 0.05, format: format, maxDimension: Int(Double(originalMaxDim) * 0.1)) {
            return (fallback.0, fallback.1, fallback.2, 0.05)
        }
        
        return nil
    }
    
    /// Resize CGImage proportionally if maxDimension is provided
    private static func resizeIfNeeded(cgImage: CGImage, maxDimension: Int?) -> (CGImage, Int, Int) {
        let width = cgImage.width
        let height = cgImage.height
        
        guard let maxDim = maxDimension, maxDim > 0, (width > maxDim || height > maxDim) else {
            return (cgImage, width, height)
        }
        
        let aspect = Double(width) / Double(height)
        let newWidth: Int
        let newHeight: Int
        
        if width > height {
            newWidth = maxDim
            newHeight = max(1, Int(Double(maxDim) / aspect))
        } else {
            newHeight = maxDim
            newWidth = max(1, Int(Double(maxDim) * aspect))
        }
        
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = cgImage.bitmapInfo.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return (cgImage, width, height)
        }
        
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        if let resizedCGImage = context.makeImage() {
            return (resizedCGImage, newWidth, newHeight)
        }
        
        return (cgImage, width, height)
    }
}
