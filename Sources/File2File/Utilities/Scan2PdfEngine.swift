import Foundation
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PDFKit

public enum Scan2PdfEngine {
    
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    // MARK: - File Loader
    
    public static func loadScanItem(from url: URL, defaultPreset: ScanPreset = .autoEnhance) -> ScanPageItem? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        
        let sizeBytes: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let sz = attrs[.size] as? Int64 {
            sizeBytes = sz
        } else {
            sizeBytes = 0
        }
        
        var item = ScanPageItem(
            url: url,
            name: url.lastPathComponent,
            originalSize: sizeBytes,
            originalImage: image,
            preset: defaultPreset
        )
        
        item.processedThumbnail = generateThumbnail(for: item, maxDimension: 300)
        return item
    }
    
    // MARK: - Core Image Processing
    
    public static func processImage(_ originalImage: NSImage, preset: ScanPreset, rotationDegrees: Int, fineTuning: ScanFineTuning) -> NSImage? {
        guard let cgImage = originalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        var ciImage = CIImage(cgImage: cgImage)
        
        // 1. Rotation
        let normalizedDegrees = ((rotationDegrees % 360) + 360) % 360
        if normalizedDegrees != 0 {
            let radians = -CGFloat(normalizedDegrees) * .pi / 180.0
            let transform = CGAffineTransform(rotationAngle: radians)
            ciImage = ciImage.transformed(by: transform)
        }
        
        // 2. Preset Filter Application
        switch preset {
        case .original:
            break
            
        case .autoEnhance:
            // Contrast boost & slight sharpness
            if let colorFilter = CIFilter(name: "CIColorControls") {
                colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
                colorFilter.setValue(1.2, forKey: kCIInputContrastKey)
                colorFilter.setValue(1.05, forKey: kCIInputSaturationKey)
                colorFilter.setValue(0.02, forKey: kCIInputBrightnessKey)
                if let output = colorFilter.outputImage {
                    ciImage = output
                }
            }
            if let unsharp = CIFilter(name: "CIUnsharpMask") {
                unsharp.setValue(ciImage, forKey: kCIInputImageKey)
                unsharp.setValue(2.5, forKey: kCIInputRadiusKey)
                unsharp.setValue(0.4, forKey: kCIInputIntensityKey)
                if let output = unsharp.outputImage {
                    ciImage = output
                }
            }
            
        case .highContrastBW:
            // CamScanner-style B&W document binarization
            if let colorMonochrome = CIFilter(name: "CIColorMonochrome") {
                colorMonochrome.setValue(ciImage, forKey: kCIInputImageKey)
                colorMonochrome.setValue(CIColor(red: 1.0, green: 1.0, blue: 1.0), forKey: kCIInputColorKey)
                colorMonochrome.setValue(1.0, forKey: kCIInputIntensityKey)
                if let output = colorMonochrome.outputImage {
                    ciImage = output
                }
            }
            if let colorFilter = CIFilter(name: "CIColorControls") {
                colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
                colorFilter.setValue(2.2, forKey: kCIInputContrastKey)
                colorFilter.setValue(-0.02, forKey: kCIInputBrightnessKey)
                if let output = colorFilter.outputImage {
                    ciImage = output
                }
            }
            if let unsharp = CIFilter(name: "CIUnsharpMask") {
                unsharp.setValue(ciImage, forKey: kCIInputImageKey)
                unsharp.setValue(3.0, forKey: kCIInputRadiusKey)
                unsharp.setValue(0.8, forKey: kCIInputIntensityKey)
                if let output = unsharp.outputImage {
                    ciImage = output
                }
            }
            
        case .grayscale:
            if let colorFilter = CIFilter(name: "CIColorControls") {
                colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
                colorFilter.setValue(0.0, forKey: kCIInputSaturationKey)
                colorFilter.setValue(1.15, forKey: kCIInputContrastKey)
                colorFilter.setValue(0.02, forKey: kCIInputBrightnessKey)
                if let output = colorFilter.outputImage {
                    ciImage = output
                }
            }
            
        case .magicColor:
            // Color pop & shadow flattening
            if let colorFilter = CIFilter(name: "CIColorControls") {
                colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
                colorFilter.setValue(1.3, forKey: kCIInputContrastKey)
                colorFilter.setValue(1.35, forKey: kCIInputSaturationKey)
                colorFilter.setValue(0.04, forKey: kCIInputBrightnessKey)
                if let output = colorFilter.outputImage {
                    ciImage = output
                }
            }
            if let unsharp = CIFilter(name: "CIUnsharpMask") {
                unsharp.setValue(ciImage, forKey: kCIInputImageKey)
                unsharp.setValue(2.0, forKey: kCIInputRadiusKey)
                unsharp.setValue(0.5, forKey: kCIInputIntensityKey)
                if let output = unsharp.outputImage {
                    ciImage = output
                }
            }
        }
        
        // 3. Fine-tuning adjustments
        if !fineTuning.isDefault {
            if fineTuning.brightness != 0.0 || fineTuning.contrast != 1.0 {
                if let colorFilter = CIFilter(name: "CIColorControls") {
                    colorFilter.setValue(ciImage, forKey: kCIInputImageKey)
                    colorFilter.setValue(fineTuning.contrast, forKey: kCIInputContrastKey)
                    colorFilter.setValue(fineTuning.brightness, forKey: kCIInputBrightnessKey)
                    if let output = colorFilter.outputImage {
                        ciImage = output
                    }
                }
            }
            
            if fineTuning.sharpness > 0 {
                if let unsharp = CIFilter(name: "CIUnsharpMask") {
                    unsharp.setValue(ciImage, forKey: kCIInputImageKey)
                    unsharp.setValue(2.0, forKey: kCIInputRadiusKey)
                    unsharp.setValue(fineTuning.sharpness, forKey: kCIInputIntensityKey)
                    if let output = unsharp.outputImage {
                        ciImage = output
                    }
                }
            }
        }
        
        // 4. Render to CGImage / NSImage
        let extent = ciImage.extent
        guard !extent.isEmpty && !extent.isInfinite else { return originalImage }
        
        guard let outputCGImage = ciContext.createCGImage(ciImage, from: extent) else {
            return nil
        }
        
        let targetSize = NSSize(width: outputCGImage.width, height: outputCGImage.height)
        return NSImage(cgImage: outputCGImage, size: targetSize)
    }
    
    public static func generateThumbnail(for item: ScanPageItem, maxDimension: CGFloat = 300) -> NSImage? {
        guard let processed = processImage(
            item.originalImage,
            preset: item.preset,
            rotationDegrees: item.rotationDegrees,
            fineTuning: item.fineTuning
        ) else { return nil }
        
        let origSize = processed.size
        guard origSize.width > 0 && origSize.height > 0 else { return processed }
        
        let scale = min(maxDimension / origSize.width, maxDimension / origSize.height)
        if scale >= 1.0 { return processed }
        
        let thumbSize = NSSize(width: origSize.width * scale, height: origSize.height * scale)
        let thumbnail = NSImage(size: thumbSize, flipped: false) { rect in
            processed.draw(in: rect, from: NSRect(origin: .zero, size: origSize), operation: .copy, fraction: 1.0)
            return true
        }
        
        return thumbnail
    }
    
    // MARK: - PDF Generation
    
    public static func generatePdfDocument(items: [ScanPageItem], options: Scan2PdfOptions) async -> PdfExportResult? {
        guard !items.isEmpty else { return nil }
        
        let pdfDoc = PDFDocument()
        var validPagesCount = 0
        
        for item in items {
            guard let processedImage = processImage(
                item.originalImage,
                preset: item.preset,
                rotationDegrees: item.rotationDegrees,
                fineTuning: item.fineTuning
            ) else { continue }
            
            if let pdfPage = createPdfPage(from: processedImage, options: options) {
                pdfDoc.insert(pdfPage, at: pdfDoc.pageCount)
                validPagesCount += 1
            }
        }
        
        guard validPagesCount > 0, let data = pdfDoc.dataRepresentation() else { return nil }
        
        var fileName = options.pdfFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        if fileName.isEmpty {
            fileName = "Scanned_Document.pdf"
        } else if !fileName.lowercased().hasSuffix(".pdf") {
            fileName += ".pdf"
        }
        
        return PdfExportResult(name: fileName, data: data, pageCount: validPagesCount)
    }
    
    private static func createPdfPage(from image: NSImage, options: Scan2PdfOptions) -> PDFPage? {
        let imageSize = image.size
        guard imageSize.width > 0 && imageSize.height > 0 else { return nil }
        
        var pageSize: CGSize
        if let stdSize = options.pageSize.sizePoints {
            pageSize = stdSize
        } else {
            pageSize = imageSize
        }
        
        // Orientation handling
        if options.pageSize != .fitImage {
            let isLandscapeImage = imageSize.width > imageSize.height
            switch options.orientation {
            case .landscape:
                pageSize = CGSize(width: max(pageSize.width, pageSize.height), height: min(pageSize.width, pageSize.height))
            case .portrait:
                pageSize = CGSize(width: min(pageSize.width, pageSize.height), height: max(pageSize.width, pageSize.height))
            case .auto:
                if isLandscapeImage {
                    pageSize = CGSize(width: max(pageSize.width, pageSize.height), height: min(pageSize.width, pageSize.height))
                } else {
                    pageSize = CGSize(width: min(pageSize.width, pageSize.height), height: max(pageSize.width, pageSize.height))
                }
            }
        }
        
        let margin = max(0, options.marginPoints)
        let printableRect = CGRect(
            x: margin,
            y: margin,
            width: max(1, pageSize.width - 2 * margin),
            height: max(1, pageSize.height - 2 * margin)
        )
        
        let scale = min(printableRect.width / imageSize.width, printableRect.height / imageSize.height)
        let drawWidth = imageSize.width * scale
        let drawHeight = imageSize.height * scale
        let drawX = printableRect.minX + (printableRect.width - drawWidth) / 2
        let drawY = printableRect.minY + (printableRect.height - drawHeight) / 2
        let drawRect = CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight)
        
        // Apply compression quality if needed
        let finalImage: NSImage
        if options.compressionQuality != .lossless,
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            if let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: options.compressionQuality.rawValue]),
               let compressedImage = NSImage(data: jpegData) {
                finalImage = compressedImage
            } else {
                finalImage = image
            }
        } else {
            finalImage = image
        }
        
        let renderedPageImage = NSImage(size: pageSize, flipped: false) { rect in
            NSColor.white.set()
            rect.fill()
            
            finalImage.draw(
                in: drawRect,
                from: NSRect(origin: .zero, size: finalImage.size),
                operation: .copy,
                fraction: 1.0
            )
            return true
        }
        
        return PDFPage(image: renderedPageImage)
    }
}
