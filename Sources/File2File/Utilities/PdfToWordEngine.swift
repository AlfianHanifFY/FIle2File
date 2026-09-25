import Foundation
import PDFKit
import AppKit
import ZIPFoundation

public enum PdfToWordError: LocalizedError {
    case cannotOpenPdf
    case failedToCreateOutputDirectory
    case failedToWriteDocx
    
    public var errorDescription: String? {
        switch self {
        case .cannotOpenPdf:
            return "Could not load or open the specified PDF document."
        case .failedToCreateOutputDirectory:
            return "Failed to create temporary output directory for Word document generation."
        case .failedToWriteDocx:
            return "Failed to compile OpenXML structure into final .docx archive."
        }
    }
}

public struct PdfToWordEngine {
    
    /// Converts a PDF document at `pdfURL` into an editable Microsoft Word (`.docx`) document at `outputURL`.
    public static func convertToDocx(
        pdfURL: URL,
        outputURL: URL? = nil,
        options: PdfToWordOptions = PdfToWordOptions()
    ) throws -> URL {
        guard let pdfDocument = PDFDocument(url: pdfURL) else {
            throw PdfToWordError.cannotOpenPdf
        }
        
        let destinationURL = outputURL ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("docx")
        
        let tempFolderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("docx_build_\(UUID().uuidString)")
        
        let wordFolderURL = tempFolderURL.appendingPathComponent("word")
        let wordRelsFolderURL = wordFolderURL.appendingPathComponent("_rels")
        let mediaFolderURL = wordFolderURL.appendingPathComponent("media")
        let relsFolderURL = tempFolderURL.appendingPathComponent("_rels")
        
        try FileManager.default.createDirectory(at: wordRelsFolderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mediaFolderURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: relsFolderURL, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempFolderURL)
        }
        
        var imageRels: [(id: String, fileName: String, widthPt: Double, heightPt: Double)] = []
        var imageCounter = 1
        
        // Build document body XML content
        var bodyXML = ""
        let totalPages = pdfDocument.pageCount
        
        for pageIndex in 0..<totalPages {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            // Extract Page Text
            let pageText = page.string ?? ""
            let lines = pageText.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    continue
                }
                let escapedText = escapeXML(trimmed)
                bodyXML += """
                        <w:p>
                          <w:r>
                            <w:t xml:space="preserve">\(escapedText)</w:t>
                          </w:r>
                        </w:p>
                \n
                """
            }
            
            // Extract images / render page thumbnail if options.extractImages is enabled and page has drawing elements
            if options.extractImages {
                let bounds = page.bounds(for: .mediaBox)
                if bounds.width > 0 && bounds.height > 0 {
                    // Check for images in page using PDFKit thumbnail rendering or image extraction
                    let imageSize = NSMakeSize(min(bounds.width, 600), min(bounds.height, 800))
                    let pageImg = page.thumbnail(of: imageSize, for: .mediaBox)
                    
                    if let tiffData = pageImg.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiffData),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        
                        let imgFileName = "image\(imageCounter).png"
                        let imgFileURL = mediaFolderURL.appendingPathComponent(imgFileName)
                        try pngData.write(to: imgFileURL)
                        
                        let rId = "rId\(imageCounter + 1)"
                        let widthEmu = Int(bounds.width * 12700) // Points to EMUs (1 pt = 12700 EMUs)
                        let heightEmu = Int(bounds.height * 12700)
                        
                        imageRels.append((id: rId, fileName: imgFileName, widthPt: Double(bounds.width), heightPt: Double(bounds.height)))
                        
                        // Add image drawing paragraph
                        bodyXML += """
                                <w:p>
                                  <w:r>
                                    <w:drawing>
                                      <wp:inline distT="0" distB="0" distL="0" distR="0">
                                        <wp:extent cx="\(widthEmu)" cy="\(heightEmu)"/>
                                        <wp:docPr id="\(imageCounter)" name="Picture \(imageCounter)"/>
                                        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                                          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                                            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                                              <pic:nvPicPr>
                                                <pic:cNvPr id="\(imageCounter)" name="\(imgFileName)"/>
                                                <pic:cNvLPr/>
                                              </pic:nvPicPr>
                                              <pic:blipFill>
                                                <a:blip r:embed="\(rId)"/>
                                                <a:stretch><a:fillRect/></a:stretch>
                                              </pic:blipFill>
                                              <pic:spPr>
                                                <a:xfrm>
                                                  <a:off x="0" y="0"/>
                                                  <a:ext cx="\(widthEmu)" cy="\(heightEmu)"/>
                                                </a:xfrm>
                                                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                                              </pic:spPr>
                                            </pic:pic>
                                          </a:graphicData>
                                        </a:graphic>
                                      </wp:inline>
                                    </w:drawing>
                                  </w:r>
                                </w:p>
                        \n
                        """
                        imageCounter += 1
                    }
                }
            }
            
            // Maintain page break between pages
            if options.maintainPageBreaks && pageIndex < totalPages - 1 {
                bodyXML += """
                        <w:p>
                          <w:r>
                            <w:br w:type="page"/>
                          </w:r>
                        </w:p>
                \n
                """
            }
        }
        
        // 1. [Content_Types].xml
        let contentTypesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Default Extension="jpeg" ContentType="image/jpeg"/>
          <Default Extension="jpg" ContentType="image/jpeg"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
        try contentTypesXML.write(to: tempFolderURL.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        
        // 2. _rels/.rels
        let rootRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
        try rootRelsXML.write(to: relsFolderURL.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)
        
        // 3. word/_rels/document.xml.rels
        var docRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        """
        for img in imageRels {
            docRelsXML += "\n  <Relationship Id=\"\(img.id)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"media/\(img.fileName)\"/>"
        }
        docRelsXML += "\n</Relationships>"
        try docRelsXML.write(to: wordRelsFolderURL.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)
        
        // 4. word/document.xml
        let fullDocumentXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                    xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                    xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                    xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">
          <w:body>
        \(bodyXML)
          </w:body>
        </w:document>
        """
        try fullDocumentXML.write(to: wordFolderURL.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)
        
        // 5. Zip folder contents into .docx output archive
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.zipItem(at: tempFolderURL, to: destinationURL, shouldKeepParent: false)
        
        return destinationURL
    }
    
    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
