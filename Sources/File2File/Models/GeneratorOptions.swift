import Foundation

public struct GeneratorOptions: Equatable {
    public var batchSize: Int
    public var includeCreateTable: Bool
    public var useCopyFormat: Bool
    public var onConflictDoNothing: Bool
    public var customDescription: String?
    
    public init(
        batchSize: Int = 500,
        includeCreateTable: Bool = false,
        useCopyFormat: Bool = false,
        onConflictDoNothing: Bool = false,
        customDescription: String? = nil
    ) {
        self.batchSize = batchSize
        self.includeCreateTable = includeCreateTable
        self.useCopyFormat = useCopyFormat
        self.onConflictDoNothing = onConflictDoNothing
        self.customDescription = customDescription
    }
}
