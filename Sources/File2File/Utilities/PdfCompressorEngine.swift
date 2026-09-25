import Foundation
import AppKit
import PDFKit
import CoreGraphics
import UniformTypeIdentifiers

public enum PdfCompressorEngine {
    
    /// Load basic information for a PDF item from a URL.
    public static func loadPdfItem(from url: URL) -> PdfCompressorItem? {
        guard let pdfDoc = PDFDocument(url: url) else { return nil }
        let sizeBytes: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let sz = attrs[.size] as? Int64 {
            sizeBytes = sz
        } else {
            sizeBytes = 0
        }
        return PdfCompressorItem(
            url: url,
            name: url.lastPathComponent,
            originalSize: sizeBytes,
            pageCount: pdfDoc.pageCount
        )
    }
    
    /// Compress a single PDF document asynchronously with progress tracking.
    public static func compressPdf(
        item: PdfCompressorItem,
        options: PdfCompressorOptions,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> (outputUrl: URL, compressedSize: Int64) {
        guard let sourceDoc = PDFDocument(url: item.url) else {
            throw NSError(
                domain: "PdfCompressorEngine",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF document at \(item.url.lastPathComponent)"]
            )
        }
        
        let pageCount = sourceDoc.pageCount
        guard pageCount > 0 else {
            throw NSError(
                domain: "PdfCompressorEngine",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "PDF document contains no pages."]
            )
        }
        
        // Prepare destination document
        let compressedDoc = PDFDocument()
        
        // Target JPEG compression factor: 0.1 to 1.0
        let jpegQuality = CGFloat(max(0.05, min(1.0, options.qualityPercent / 100.0)))
        
        // DPI multiplier relative to default 72 points per inch
        let dpiScale: CGFloat
        if let targetDpi = options.targetDpi.dpiValue {
            dpiScale = max(0.5, targetDpi / 72.0)
        } else {
            // Original DPI / default 1.0x (or 150 DPI default equivalent if not limited)
            dpiScale = 2.0 // Render at high quality 144 DPI then compress JPEG
        }
        
        for i in 0..<pageCount {
            await Task.yield()
            guard let page = sourceDoc.page(at: i) else { continue }
            
            let mediaBox = page.bounds(for: .mediaBox)
            let rotation = page.rotation
            
            let renderWidth = max(1, Int(mediaBox.width * dpiScale))
            let renderHeight = max(1, Int(mediaBox.height * dpiScale))
            
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                    data: nil,
                    width: renderWidth,
                    height: renderHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: renderWidth * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                continue
            }
            
            // Draw page into context
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: CGFloat(renderWidth), height: CGFloat(renderHeight)))
            
            context.saveGState()
            context.scaleBy(x: dpiScale, y: dpiScale)
            
            // Handle page rotation transform if needed
            let pdfTransform = page.transform(for: .mediaBox)
            context.concatenate(pdfTransform)
            
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            
            guard let cgImage = context.makeImage() else { continue }
            
            // Convert CGImage to compressed JPEG data
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let jpegData = bitmapRep.representation(
                using: .jpeg,
                properties: [.compressionFactor: jpegQuality]
            ) else { continue }
            
            guard let compressedImage = NSImage(data: jpegData),
                  let compressedPdfPage = PDFPage(image: compressedImage) else { continue }
            
            compressedPdfPage.rotation = rotation
            compressedDoc.insert(compressedPdfPage, at: compressedDoc.pageCount)
            
            let progress = Double(i + 1) / Double(pageCount)
            progressHandler(progress)
        }
        
        // Output path determination
        let destinationUrl: URL
        if let customFolder = options.customOutputFolder {
            let baseName = item.url.deletingPathExtension().lastPathComponent
            let outputName = "\(baseName)\(options.outputSuffix).pdf"
            destinationUrl = customFolder.appendingPathComponent(outputName)
        } else {
            let directory = item.url.deletingLastPathComponent()
            let baseName = item.url.deletingPathExtension().lastPathComponent
            let outputName = "\(baseName)\(options.outputSuffix).pdf"
            destinationUrl = directory.appendingPathComponent(outputName)
        }
        
        // Write compressed PDF file
        guard compressedDoc.write(to: destinationUrl) else {
            throw NSError(
                domain: "PdfCompressorEngine",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to write compressed PDF to disk."]
            )
        }
        
        // Fetch compressed file size
        let compressedSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: destinationUrl.path),
           let sz = attrs[.size] as? Int64 {
            compressedSize = sz
        } else {
            compressedSize = 0
        }
        
        return (destinationUrl, compressedSize)
    }
}
