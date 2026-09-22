import Foundation

public struct ColumnSchema: Identifiable, Equatable, Hashable {
    public var id: String { name }
    public var name: String
    public var dataType: String
    public var rawType: String
    public var isNullable: Bool
    public var isPrimaryKey: Bool
    
    public init(name: String, dataType: String, rawType: String, isNullable: Bool = true, isPrimaryKey: Bool = false) {
        self.name = name
        self.dataType = dataType
        self.rawType = rawType
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
    }
}

public struct ParsedSchema: Equatable {
    public var tableName: String
    public var columns: [ColumnSchema]
    
    public init(tableName: String, columns: [ColumnSchema]) {
        self.tableName = tableName
        self.columns = columns
    }
}
