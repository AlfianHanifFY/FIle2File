import Foundation

public enum FileFormat: String, Codable {
    case xlsx
    case csv
}

public struct FileData: Identifiable, Equatable {
    public let id = UUID()
    public var fileURL: URL?
    public var name: String
    public var size: Int64
    public var format: FileFormat
    public var headers: [String]
    public var totalRows: Int
    public var previewRows: [[String: String]]
    public var allData: [[String: String]]
    public var sheets: [String]
    public var selectedSheet: String?

    public init(
        fileURL: URL? = nil,
        name: String,
        size: Int64,
        format: FileFormat,
        headers: [String],
        totalRows: Int,
        previewRows: [[String: String]],
        allData: [[String: String]] = [],
        sheets: [String] = ["Sheet1"],
        selectedSheet: String? = "Sheet1"
    ) {
        self.fileURL = fileURL
        self.name = name
        self.size = size
        self.format = format
        self.headers = headers
        self.totalRows = totalRows
        self.previewRows = previewRows
        self.allData = allData
        self.sheets = sheets
        self.selectedSheet = selectedSheet
    }

    public static func == (lhs: FileData, rhs: FileData) -> Bool {
        lhs.id == rhs.id
    }
}
