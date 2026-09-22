import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum VideoToGifError: LocalizedError {
    case invalidVideoFile
    case noVideoTrackFound
    case frameGenerationFailed
    case gifEncodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidVideoFile:
            return "Unable to open or parse the specified video file."
        case .noVideoTrackFound:
            return "The video file does not contain a valid video track."
        case .frameGenerationFailed:
            return "Failed to extract frame images from the video timeline."
        case .gifEncodingFailed:
            return "Failed to encode images into animated GIF format."
        }
    }
}

public actor VideoToGifEngine {
    
    /// Extract video metadata (duration & size) from URL
    public static func loadMetadata(from url: URL) async throws -> (duration: Double, size: CGSize, fileSize: Int64) {
        let asset = AVURLAsset(url: url)
        
        let durationTime = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(durationTime)
        guard durationSeconds > 0 else {
            throw VideoToGifError.invalidVideoFile
        }
        
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let firstTrack = tracks.first else {
            throw VideoToGifError.noVideoTrackFound
        }
        
        let trackSize = try await firstTrack.load(.naturalSize)
        let transform = try await firstTrack.load(.preferredTransform)
        
        // Handle rotation in video natural size
        let rect = CGRect(origin: .zero, size: trackSize).applying(transform)
        let actualSize = CGSize(width: abs(rect.width), height: abs(rect.height))
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        
        return (duration: durationSeconds, size: actualSize, fileSize: fileSize)
    }
    
    /// Convert video file to GIF with given options and optional progress callback
    public static func convertToGif(
        url: URL,
        options: VideoToGifOptions,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> Data {
        let asset = AVURLAsset(url: url)
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        // Apply resolution scaling if specified
        if let targetWidth = options.resolution.targetWidth {
            // Maximum size restricts dimension while retaining aspect ratio
            generator.maximumSize = CGSize(width: targetWidth, height: 0)
        }
        
        let start = max(0, options.startTime)
        let end = options.endTime > start ? options.endTime : try await asset.load(.duration).seconds
        let duration = max(0.1, end - start)
        
        let fps = max(1, min(60, options.fps))
        let frameCount = max(1, Int(duration * Double(fps)))
        let timeStep = duration / Double(frameCount)
        
        let frameDelay = max(0.02, (1.0 / Double(fps)) / options.speedMultiplier)
        
        // Create frame timestamps
        var timeValues: [CMTime] = []
        for i in 0..<frameCount {
            let sampleTimeSeconds = start + (Double(i) * timeStep)
            timeValues.append(CMTime(seconds: sampleTimeSeconds, preferredTimescale: 600))
        }
        
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            UTType.gif.identifier as CFString,
            frameCount,
            nil
        ) else {
            throw VideoToGifError.gifEncodingFailed
        }
        
        // Container GIF properties (loop count)
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: options.loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
        
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay,
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]
        
        var generatedCount = 0
        
        for cmTime in timeValues {
            do {
                let cgImage = try await generator.image(at: cmTime).image
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            } catch {
                // If single frame fails, log or continue
                print("Failed frame at time \(cmTime.seconds): \(error.localizedDescription)")
            }
            
            generatedCount += 1
            let currentProgress = Double(generatedCount) / Double(frameCount)
            progressHandler(currentProgress)
        }
        
        guard CGImageDestinationFinalize(destination) else {
            throw VideoToGifError.gifEncodingFailed
        }
        
        return mutableData as Data
    }
}
