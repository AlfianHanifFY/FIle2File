import Foundation

public enum NullHandlingStrategy: String, CaseIterable, Identifiable {
    case setNull = "NULL"
    case emptyString = "EMPTY_STRING"
    case defaultValue = "DEFAULT_VALUE"
    
    public var id: String { rawValue }
}

public struct ColumnMapping: Identifiable, Equatable {
    public var id: String { sqlColumn }
    public var sqlColumn: String
    public var sqlType: String
    public var isNullable: Bool
    public var excelHeader: String // Empty string if unmapped
    public var confidence: Double // 0.0 to 1.0
    public var dateFormat: String
    public var nullHandling: NullHandlingStrategy
    public var defaultValue: String
    
    public init(
        sqlColumn: String,
        sqlType: String,
        isNullable: Bool,
        excelHeader: String = "",
        confidence: Double = 0.0,
        dateFormat: String = "",
        nullHandling: NullHandlingStrategy = .setNull,
        defaultValue: String = ""
    ) {
        self.sqlColumn = sqlColumn
        self.sqlType = sqlType
        self.isNullable = isNullable
        self.excelHeader = excelHeader
        self.confidence = confidence
        self.dateFormat = dateFormat
        self.nullHandling = nullHandling
        self.defaultValue = defaultValue
    }
}
