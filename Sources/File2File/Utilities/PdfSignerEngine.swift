import Foundation
import AppKit
import PDFKit
import Security
import CoreGraphics

public enum PdfSignerEngineError: LocalizedError {
    case invalidPdfFile
    case invalidCertificateFile
    case invalidCertificatePassword
    case signingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidPdfFile:
            return "Unable to open or process target PDF document."
        case .invalidCertificateFile:
            return "Failed to parse .p12/.pfx PKCS#12 digital certificate file."
        case .invalidCertificatePassword:
            return "Incorrect password for the digital certificate."
        case .signingFailed(let msg):
            return "Digital signature failed: \(msg)"
        }
    }
}

public enum PdfSignerEngine {
    
    public static func loadPdfSignItem(from url: URL) -> PdfSignItem? {
        guard let pdfDoc = PDFDocument(url: url) else { return nil }
        let sizeBytes: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let sz = attrs[.size] as? Int64 {
            sizeBytes = sz
        } else {
            sizeBytes = 0
        }
        return PdfSignItem(
            url: url,
            name: url.lastPathComponent,
            originalSize: sizeBytes,
            pageCount: pdfDoc.pageCount
        )
    }
    
    /// Stamped visual signatures onto PDF pages and optionally applies digital certificate metadata.
    public static func signPdf(
        pdfUrl: URL,
        visualOverlays: [VisualSignatureOverlay],
        digitalConfig: DigitalSignatureConfig?
    ) throws -> Data {
        guard let pdfDoc = PDFDocument(url: pdfUrl) else {
            throw PdfSignerEngineError.invalidPdfFile
        }
        
        // If digital certificate provided, validate identity first
        var signingIdentity: SecIdentity? = nil
        if let config = digitalConfig, let certUrl = config.certificateURL {
            signingIdentity = try importPKCS12Identity(from: certUrl, password: config.password)
        }
        
        let pdfData = NSMutableData()
        guard let dataConsumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw PdfSignerEngineError.signingFailed("Could not create PDF data consumer.")
        }
        
        // Use first page box as default bounds
        let firstPageBounds = pdfDoc.page(at: 0)?.bounds(for: .mediaBox) ?? CGRect(x: 0, y: 0, width: 612, height: 792)
        var mediaBox = firstPageBounds
        
        guard let pdfContext = CGContext(consumer: dataConsumer, mediaBox: &mediaBox, nil) else {
            throw PdfSignerEngineError.signingFailed("Failed to initialize CGContext.")
        }
        
        for pageIndex in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            var pageMediaBox = pageBounds
            
            pdfContext.beginPage(mediaBox: &pageMediaBox)
            
            // Draw original PDF page
            NSGraphicsContext.saveGraphicsState()
            let nsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
            NSGraphicsContext.current = nsContext
            
            page.draw(with: .mediaBox, to: pdfContext)
            
            // Draw visual signature overlays for this page
            let overlaysForPage = visualOverlays.filter { $0.pageIndex == pageIndex }
            for overlay in overlaysForPage {
                guard let cgImage = overlay.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    continue
                }
                
                // Calculate position in PDF coordinate system (0,0 is bottom-left)
                let sigWidth = pageBounds.width * overlay.size.width
                let sigHeight = pageBounds.height * overlay.size.height
                
                let sigX = (pageBounds.width * overlay.position.x) - (sigWidth / 2.0)
                // overlay.position.y is normalized from top (0.0 top, 1.0 bottom)
                let sigY = (pageBounds.height * (1.0 - overlay.position.y)) - (sigHeight / 2.0)
                
                let sigRect = CGRect(x: sigX, y: sigY, width: sigWidth, height: sigHeight)
                
                pdfContext.draw(cgImage, in: sigRect)
            }
            
            NSGraphicsContext.restoreGraphicsState()
            pdfContext.endPage()
        }
        
        pdfContext.closePDF()
        
        // If digital identity present, inject digital signature metadata
        if let identity = signingIdentity, let config = digitalConfig {
            return try applyDigitalCertificateMetadata(
                to: pdfData as Data,
                identity: identity,
                config: config
            )
        }
        
        return pdfData as Data
    }
    
    // MARK: - Security & PKCS#12 Helpers
    
    private static func importPKCS12Identity(from url: URL, password: String) throws -> SecIdentity {
        let p12Data: Data
        do {
            p12Data = try Data(contentsOf: url)
        } catch {
            throw PdfSignerEngineError.invalidCertificateFile
        }
        
        let options = [kSecImportExportPassphrase as String: password] as CFDictionary
        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options, &rawItems)
        
        if status == errSecAuthFailed || status == errSecPkcs12VerifyFailure {
            throw PdfSignerEngineError.invalidCertificatePassword
        }
        
        guard status == errSecSuccess,
              let items = rawItems as? [[String: Any]],
              let firstItem = items.first,
              let identity = firstItem[kSecImportItemIdentity as String] as! SecIdentity? else {
            throw PdfSignerEngineError.invalidCertificateFile
        }
        
        return identity
    }
    
    private static func applyDigitalCertificateMetadata(
        to pdfData: Data,
        identity: SecIdentity,
        config: DigitalSignatureConfig
    ) throws -> Data {
        // Embed Certificate Common Name and Digital Signature attributes into PDF metadata
        var certRef: SecCertificate?
        SecIdentityCopyCertificate(identity, &certRef)
        
        var commonName = "Digital Certificate"
        if let cert = certRef,
           let summary = SecCertificateCopySubjectSummary(cert) as String? {
            commonName = summary
        }
        
        guard let doc = PDFDocument(data: pdfData) else {
            return pdfData
        }
        
        var attributes = doc.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.authorAttribute] = commonName
        attributes[PDFDocumentAttribute.subjectAttribute] = "Digitally signed: \(config.reason)"
        if !config.location.isEmpty {
            attributes[PDFDocumentAttribute.keywordsAttribute] = ["Signed at \(config.location)"]
        }
        
        doc.documentAttributes = attributes
        return doc.dataRepresentation() ?? pdfData
    }
}
