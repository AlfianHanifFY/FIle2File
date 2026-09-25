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
    
    /// Extract metadata and create an initial ImageItem from a File URL efficiently
    public static func loadItem(from url: URL) -> ImageItem? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? 0
        let format = url.pathExtension.uppercased()
        
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        let data = (try? Data(contentsOf: url)) ?? Data()
        
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
    
    /// Bounded concurrent batch compression for high efficiency without exhausting RAM
    public static func compressBatch(_ items: [ImageItem], config: ImageCompressionConfig) async -> [ImageItem] {
        let maxConcurrency = max(1, ProcessInfo.processInfo.activeProcessorCount - 1)
        return await withTaskGroup(of: (Int, ImageItem).self) { group in
            var results = [ImageItem?](repeating: nil, count: items.count)
            var index = 0
            
            while index < items.count && index < maxConcurrency {
                let item = items[index]
                let currentIndex = index
                group.addTask {
                    let compressed = await compress(item, config: config)
                    return (currentIndex, compressed)
                }
                index += 1
            }
            
            for await (i, compressed) in group {
                results[i] = compressed
                if index < items.count {
                    let item = items[index]
                    let currentIndex = index
                    group.addTask {
                        let compressed = await compress(item, config: config)
                        return (currentIndex, compressed)
                    }
                    index += 1
                }
            }
            
            return results.compactMap { $0 }
        }
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
            let resolvedFormat = resolveFormat(config.outputFormat, originalFormat: item.originalFormat)
            
            // PNG is lossless — quality settings have zero effect on PNG encoding.
            // When the user wants lossy compression (quality < 100% or target size mode),
            // automatically use JPEG instead so compression actually works.
            let targetFormat: ImageOutputFormat
            switch config.mode {
            case .byPercentage:
                if resolvedFormat == .png && config.qualityPercent < 100.0 {
                    targetFormat = .jpeg
                } else {
                    targetFormat = resolvedFormat
                }
            case .byTargetSize:
                // compressToTargetSize already handles PNG fallback internally
                targetFormat = resolvedFormat
            }
            
            switch config.mode {
            case .byPercentage:
                let quality = max(min(config.qualityPercent / 100.0, 1.0), 0.01)
                let res = encode(cgImage: cgImage, quality: quality, format: targetFormat, maxDimension: config.maxDimension)
                
                if let (compressedData, finalWidth, finalHeight) = res {
                    // If compressed is somehow larger than original (e.g. format conversion overhead),
                    // return the original data as-is to avoid inflating the file.
                    if Int64(compressedData.count) >= item.originalSize && config.maxDimension == nil {
                        updatedItem.compressedData = item.originalData
                        updatedItem.compressedSize = item.originalSize
                        updatedItem.compressedWidth = item.originalWidth
                        updatedItem.compressedHeight = item.originalHeight
                        updatedItem.appliedQuality = 1.0
                    } else {
                        updatedItem.compressedData = compressedData
                        updatedItem.compressedSize = Int64(compressedData.count)
                        updatedItem.compressedWidth = finalWidth
                        updatedItem.compressedHeight = finalHeight
                        updatedItem.appliedQuality = quality
                    }
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
        
        // 1. Try requested format first (with minScaleFactor 0.75 if auto/png, so resolution isn't excessively degraded if JPEG lossy compression can achieve full resolution)
        let minScale = (format == .auto || format == .png) ? 0.75 : 0.1
        if let result = compressToTargetSizeSingleFormat(cgImage: cgImage, targetBytes: targetBytes, format: format, maxDimension: maxDimension, minScaleFactor: minScale) {
            return result
        }
        
        // 2. If requested format was PNG or Match Original (.auto) and couldn't fit targetBytes at high resolution, fallback to JPEG lossy compression
        if format == .png || format == .auto {
            if let jpegResult = compressToTargetSizeSingleFormat(cgImage: cgImage, targetBytes: targetBytes, format: .jpeg, maxDimension: maxDimension, minScaleFactor: 0.1) {
                return jpegResult
            }
        }
        
        // 3. If JPEG lossy still needs further scaling, allow PNG down to 0.1 scale
        if format == .png {
            if let pngResult = compressToTargetSizeSingleFormat(cgImage: cgImage, targetBytes: targetBytes, format: .png, maxDimension: maxDimension, minScaleFactor: 0.1) {
                return pngResult
            }
        }
        
        // 4. Final fallback: return lowest quality encoding at small dimension
        let originalMaxDim = max(cgImage.width, cgImage.height)
        let fallbackFormat = (format == .png || format == .auto) ? ImageOutputFormat.jpeg : format
        if let fallback = encode(cgImage: cgImage, quality: 0.05, format: fallbackFormat, maxDimension: Int(Double(originalMaxDim) * 0.1)) {
            return (fallback.0, fallback.1, fallback.2, 0.05)
        }
        
        return nil
    }
    
    private static func compressToTargetSizeSingleFormat(
        cgImage: CGImage,
        targetBytes: Int64,
        format: ImageOutputFormat,
        maxDimension: Int?,
        minScaleFactor: Double = 0.1
    ) -> (Data, Int, Int, Double)? {
        let currentDimension = maxDimension
        let currentImage = cgImage
        let originalMaxDim = max(cgImage.width, cgImage.height)
        
        var scaleFactor: Double = 1.0
        
        while scaleFactor >= minScaleFactor - 0.01 {
            let targetMaxDim: Int
            if let userMax = currentDimension {
                targetMaxDim = min(userMax, Int(Double(originalMaxDim) * scaleFactor))
            } else {
                targetMaxDim = Int(Double(originalMaxDim) * scaleFactor)
            }
            
            var low: Double = 0.02
            var high: Double = 1.0
            var bestResult: (Data, Int, Int)? = nil
            var bestQuality: Double = 1.0
            
            for _ in 0..<8 { // 8 iterations of binary search
                let mid = (low + high) / 2.0
                if let encoded = encode(cgImage: currentImage, quality: mid, format: format, maxDimension: targetMaxDim) {
                    if Int64(encoded.0.count) <= targetBytes {
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
            
            if let result = bestResult, Int64(result.0.count) <= targetBytes {
                return (result.0, result.1, result.2, bestQuality)
            }
            
            scaleFactor -= 0.15
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
