import Foundation

public struct DDLParser {
    public static func parseDDL(_ ddl: String) -> ParsedSchema? {
        let trimmed = ddl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Clean comments (-- and /* */)
        var cleaned = ddl
        cleaned = cleaned.replacingOccurrences(of: "--.*$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Regex pattern to extract table name and column body
        let tablePattern = "(?i)CREATE\\s+TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?(?:[a-zA-Z0-9_\"]+\\.)?[\"`']?([a-zA-Z0-9_]+)[\"`']?\\s*\\(([\\s\\S]+)\\)"
        if let regex = try? NSRegularExpression(pattern: tablePattern, options: []),
           let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count)) {
            
            let tableNameRange = match.range(at: 1)
            let bodyRange = match.range(at: 2)
            
            let tableName = (cleaned as NSString).substring(with: tableNameRange)
            let body = (cleaned as NSString).substring(with: bodyRange)
            
            let columns = parseColumnsBody(body)
            return ParsedSchema(tableName: tableName.isEmpty ? "target_table" : tableName, columns: columns)
        } else {
            // Fallback for column list only
            let cleanedBody = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            let columns = parseColumnsBody(cleanedBody)
            return ParsedSchema(tableName: "custom_table", columns: columns)
        }
    }

    private static func parseColumnsBody(_ body: String) -> [ColumnSchema] {
        var columns: [ColumnSchema] = []
        var parts: [String] = []
        var current = ""
        var parenDepth = 0

        for char in body {
            if char == "(" { parenDepth += 1 }
            else if char == ")" { parenDepth -= 1 }

            if char == "," && parenDepth == 0 {
                parts.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }
        }
        let lastPart = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !lastPart.isEmpty {
            parts.append(lastPart)
        }

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // Skip table constraints (CONSTRAINT, PRIMARY KEY (...), FOREIGN KEY (...), etc.)
            let constraintPattern = "(?i)^(CONSTRAINT|PRIMARY\\s+KEY|FOREIGN\\s+KEY|UNIQUE|CHECK)\\b"
            if let regex = try? NSRegularExpression(pattern: constraintPattern),
               regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
                continue
            }

            // Match column: "col_name DATA_TYPE [CONSTRAINTS]"
            let colPattern = "^[\"`']?([a-zA-Z0-9_]+)[\"`']?\\s+([a-zA-Z0-9_\\s\\(\\),]+?)(?:\\s+(.*))?$"
            if let regex = try? NSRegularExpression(pattern: colPattern, options: []),
               let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) {
                
                let colName = (trimmed as NSString).substring(with: match.range(at: 1))
                let rawType = (trimmed as NSString).substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                var constraints = ""
                if match.range(at: 3).location != NSNotFound {
                    constraints = (trimmed as NSString).substring(with: match.range(at: 3))
                }

                let fullTypeString = rawType + " " + constraints
                let normalizedType = normalizePostgresType(fullTypeString)
                let isNullable = constraints.range(of: "NOT\\s+NULL", options: [.regularExpression, .caseInsensitive]) == nil
                let isPrimaryKey = constraints.range(of: "PRIMARY\\s+KEY", options: [.regularExpression, .caseInsensitive]) != nil || rawType.localizedCaseInsensitiveContains("SERIAL")

                columns.append(ColumnSchema(
                    name: colName,
                    dataType: normalizedType,
                    rawType: rawType,
                    isNullable: isNullable,
                    isPrimaryKey: isPrimaryKey
                ))
            }
        }

        return columns
    }

    public static func normalizePostgresType(_ rawType: String) -> String {
        let upper = rawType.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        if upper.contains("INT") || upper.contains("SERIAL") {
            if upper.contains("BIG") || upper.contains("8") { return "BIGINT" }
            if upper.contains("SMALL") || upper.contains("2") { return "SMALLINT" }
            return "INTEGER"
        }

        if upper.contains("VARCHAR") || upper.contains("CHAR") || upper.contains("TEXT") || upper.contains("STRING") {
            return "VARCHAR"
        }

        if upper.contains("TIMESTAMP") || upper.contains("DATETIME") {
            if upper.contains("TZ") || upper.contains("WITH TIME ZONE") { return "TIMESTAMPTZ" }
            return "TIMESTAMP"
        }

        if upper.contains("DATE") { return "DATE" }
        if upper.contains("TIME") { return "TIME" }
        if upper.contains("BOOL") { return "BOOLEAN" }
        if upper.contains("NUMERIC") || upper.contains("DECIMAL") || upper.contains("MONEY") { return "NUMERIC" }
        if upper.contains("FLOAT") || upper.contains("DOUBLE") || upper.contains("REAL") { return "DOUBLE PRECISION" }
        if upper.contains("UUID") { return "UUID" }
        if upper.contains("JSON") { return "JSONB" }

        return "TEXT"
    }
}
