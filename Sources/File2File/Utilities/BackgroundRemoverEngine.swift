import Foundation
import AppKit
import SwiftUI
import Vision
import CoreImage

@available(macOS 14.0, *)
public struct BackgroundRemoverEngine {
    
    public static func loadItem(from url: URL) -> BackgroundRemoverItem? {
        guard let data = try? Data(contentsOf: url),
              let image = NSImage(data: data),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? data.count
        return BackgroundRemoverItem(
            url: url,
            name: url.lastPathComponent,
            originalData: data,
            originalSize: Int64(size),
            originalWidth: cgImage.width,
            originalHeight: cgImage.height
        )
    }
    
    public static func removeBackground(
        item: BackgroundRemoverItem,
        config: BackgroundRemoverConfig
    ) async -> BackgroundRemoverItem {
        var updatedItem = item
        updatedItem.isProcessing = true
        updatedItem.errorMessage = nil
        
        guard let ciInputImage = CIImage(data: item.originalData) else {
            updatedItem.isProcessing = false
            updatedItem.errorMessage = "Failed to load image data."
            return updatedItem
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciInputImage, options: [:])
        
        do {
            try handler.perform([request])
            guard let result = request.results?.first else {
                updatedItem.isProcessing = false
                updatedItem.errorMessage = "No foreground objects detected in image."
                return updatedItem
            }
            
            let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)
            
            let blendedCIImage = applyBackgroundFill(
                original: ciInputImage,
                mask: maskCIImage,
                config: config
            )
            
            let context = CIContext()
            guard let outputCGImage = context.createCGImage(blendedCIImage, from: blendedCIImage.extent) else {
                updatedItem.isProcessing = false
                updatedItem.errorMessage = "Failed to render processed image."
                return updatedItem
            }
            
            let processedData = try exportCGImage(outputCGImage, format: config.outputFormat)
            updatedItem.processedData = processedData
            updatedItem.processedSize = Int64(processedData.count)
            updatedItem.isProcessing = false
            return updatedItem
        } catch {
            updatedItem.isProcessing = false
            updatedItem.errorMessage = error.localizedDescription
            return updatedItem
        }
    }
    
    private static func applyBackgroundFill(
        original: CIImage,
        mask: CIImage,
        config: BackgroundRemoverConfig
    ) -> CIImage {
        let scaleX = original.extent.width / mask.extent.width
        let scaleY = original.extent.height / mask.extent.height
        let scaledMask = mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: original.extent)
        
        let foregroundOnly = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: original,
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: scaledMask
        ])?.outputImage ?? original
        
        switch config.fillType {
        case .transparent:
            return foregroundOnly
            
        case .solidWhite:
            let whiteBG = CIImage(color: CIColor.white).cropped(to: original.extent)
            return CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: original,
                kCIInputBackgroundImageKey: whiteBG,
                kCIInputMaskImageKey: scaledMask
            ])?.outputImage ?? foregroundOnly
            
        case .solidBlack:
            let blackBG = CIImage(color: CIColor.black).cropped(to: original.extent)
            return CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: original,
                kCIInputBackgroundImageKey: blackBG,
                kCIInputMaskImageKey: scaledMask
            ])?.outputImage ?? foregroundOnly
            
        case .customColor:
            let nsColor = NSColor(config.customColor)
            let ciColor = CIColor(color: nsColor) ?? CIColor.white
            let colorBG = CIImage(color: ciColor).cropped(to: original.extent)
            return CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: original,
                kCIInputBackgroundImageKey: colorBG,
                kCIInputMaskImageKey: scaledMask
            ])?.outputImage ?? foregroundOnly
            
        case .customImage:
            if let bgData = config.customBgImageData, let customBG = CIImage(data: bgData) {
                let bgScaleX = original.extent.width / customBG.extent.width
                let bgScaleY = original.extent.height / customBG.extent.height
                let scaledCustomBG = customBG.transformed(by: CGAffineTransform(scaleX: bgScaleX, y: bgScaleY))
                    .cropped(to: original.extent)
                
                return CIFilter(name: "CIBlendWithMask", parameters: [
                    kCIInputImageKey: original,
                    kCIInputBackgroundImageKey: scaledCustomBG,
                    kCIInputMaskImageKey: scaledMask
                ])?.outputImage ?? foregroundOnly
            }
            return foregroundOnly
        }
    }
    
    private static func exportCGImage(
        _ cgImage: CGImage,
        format: BackgroundRemoverOutputFormat
    ) throws -> Data {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            format.utiType as CFString,
            1,
            nil
        ) else {
            throw NSError(domain: "BackgroundRemoverEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "BackgroundRemoverEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image export"])
        }
        
        return mutableData as Data
    }
}
