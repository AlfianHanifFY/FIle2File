import Foundation
import SwiftUI

public enum AppToolCategory: String, CaseIterable, Identifiable {
    case database = "Database & SQL"
    case media = "Media & Image"
    case dataConversion = "Data Conversion"
    case preferences = "Preferences"
    
    public var id: String { rawValue }
}

public struct AppTool: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let category: AppToolCategory
    public let isAvailable: Bool
    
    public static let allTools: [AppTool] = [
        AppTool(
            id: "xlsx2sql",
            name: "Xlsx2SQL",
            description: "Convert Excel & CSV files into clean PostgreSQL INSERT or COPY statements.",
            icon: "tablecells.badge.ellipsis",
            category: .database,
            isAvailable: true
        ),
        AppTool(
            id: "imageCompressor",
            name: "Image Compressor",
            description: "Compress images by target percentage or exact file size.",
            icon: "photo.stack",
            category: .media,
            isAvailable: true
        ),
        AppTool(
            id: "removeBackground",
            name: "Background Remover",
            description: "Automatically detect foreground subjects and remove or replace image backgrounds.",
            icon: "person.and.background.striped.horizontal",
            category: .media,
            isAvailable: true
        ),
        AppTool(
            id: "video2gif",
            name: "Video to GIF",
            description: "Convert video clips into animated GIF files with timeline trimming and scale controls.",
            icon: "video.badge.plus",
            category: .media,
            isAvailable: true
        ),
        AppTool(
            id: "imageToPdf",
            name: "Image to PDF",
            description: "Convert single or multiple images into a structured PDF document.",
            icon: "doc.richtext",
            category: .media,
            isAvailable: true
        ),
        AppTool(
            id: "pdfToImage",
            name: "PDF to Image",
            description: "Extract high-resolution image files from PDF document pages.",
            icon: "doc.viewfinder",
            category: .media,
            isAvailable: true
        ),
        AppTool(
            id: "mergePdf",
            name: "Merge PDF",
            description: "Combine multiple PDF documents into a single PDF file.",
            icon: "doc.on.doc",
            category: .media,
            isAvailable: true
        ),
        AppTool(
            id: "splitPdf",
            name: "Split PDF",
            description: "Extract ranges, split into single pages, or chunk PDF documents.",
            icon: "scissors",
            category: .media,
            isAvailable: true
        ),
        AppTool(
            id: "signPdf",
            name: "Sign PDF",
            description: "Add visual signature overlays or digital certificate signatures to PDF documents.",
            icon: "signature",
            category: .media,
            isAvailable: true
        ),
        AppTool(
            id: "csv2json",
            name: "CSV2JSON",
            description: "Transform CSV tabular data into structured JSON objects.",
            icon: "curlybraces",
            category: .dataConversion,
            isAvailable: true
        ),
        AppTool(
            id: "excel2csv",
            name: "Excel2CSV",
            description: "Extract and convert Excel worksheets to standardized CSV files.",
            icon: "document.on.document",
            category: .dataConversion,
            isAvailable: true
        ),
        AppTool(
            id: "settings",
            name: "Settings",
            description: "Configure output directory, appearance mode, and export description.",
            icon: "gearshape.fill",
            category: .preferences,
            isAvailable: true
        )
    ]
}
