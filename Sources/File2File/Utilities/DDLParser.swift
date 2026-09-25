import Foundation

public enum DDLParseError: LocalizedError, Equatable {
    case empty
    case noCreateTable
    case unclosedParenthesis
    case invalidColumn(String)
    case noColumnsFound

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "DDL statement is empty. Paste a CREATE TABLE statement or click Auto-Generate DDL."
        case .noCreateTable:
            return "Could not find a valid CREATE TABLE statement. Ensure it begins with `CREATE TABLE <table_name> (`."
        case .unclosedParenthesis:
            return "Unclosed parenthesis in CREATE TABLE statement. Ensure all opening '(' have a matching ')'."
        case .invalidColumn(let detail):
            return "Invalid syntax near '\(detail)'. Each column must specify a name and data type (e.g. \"col_name\" VARCHAR(255))."
        case .noColumnsFound:
            return "No valid column definitions found inside the table schema."
        }
    }
}

public struct DDLParser {

    /// Detailed validation returning specific syntax errors or the parsed schema
    public static func validateAndParseDDL(_ ddl: String) -> Result<ParsedSchema, DDLParseError> {
        let trimmed = ddl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }

        // Normalize smart / curly typography quotes automatically inserted by macOS TextEditor
        var cleaned = ddl
        cleaned = cleaned.replacingOccurrences(of: "[“”]", with: "\"", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "[‘’]", with: "'", options: .regularExpression)

        // Strip single line comments (-- ...) and multi-line comments (/* ... */)
        cleaned = cleaned.replacingOccurrences(of: "(?m)--.*$", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "/\\*[\\s\\S]*?\\*/", with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return .failure(.empty) }

        // Match CREATE TABLE [IF NOT EXISTS] [schema.]table_name (
        let createTablePattern = "(?i)^[\\s\\S]*?CREATE\\s+TABLE\\s+(?:IF\\s+NOT\\s+EXISTS\\s+)?(?:[a-zA-Z0-9_\"]+\\.)?[\"`']?([a-zA-Z0-9_]+)[\"`']?\\s*\\("
        guard let regex = try? NSRegularExpression(pattern: createTablePattern, options: []),
              let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count)) else {
            // Check fallback for bare column list
            return parseBareColumns(cleaned)
        }

        let tableName = (cleaned as NSString).substring(with: match.range(at: 1))
        let openParenEnd = match.range.location + match.range.length

        // Extract body between outermost parentheses safely by matching depth
        let restOfCleaned = (cleaned as NSString).substring(from: openParenEnd)
        var parenDepth = 1
        var bodyEndIndex = -1

        for (idx, char) in restOfCleaned.enumerated() {
            if char == "(" {
                parenDepth += 1
            } else if char == ")" {
                parenDepth -= 1
                if parenDepth == 0 {
                    bodyEndIndex = idx
                    break
                }
            }
        }

        guard parenDepth == 0, bodyEndIndex >= 0 else {
            return .failure(.unclosedParenthesis)
        }

        let body = (restOfCleaned as NSString).substring(to: bodyEndIndex)
        
        switch parseColumnsBody(body) {
        case .success(let columns):
            guard !columns.isEmpty else { return .failure(.noColumnsFound) }
            return .success(ParsedSchema(tableName: tableName.isEmpty ? "target_table" : tableName, columns: columns))
        case .failure(let err):
            return .failure(err)
        }
    }

    /// Convenience wrapper for backwards compatibility
    public static func parseDDL(_ ddl: String) -> ParsedSchema? {
        switch validateAndParseDDL(ddl) {
        case .success(let schema):
            return schema
        case .failure:
            return nil
        }
    }

    private static func parseBareColumns(_ cleaned: String) -> Result<ParsedSchema, DDLParseError> {
        let stripped = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "();"))
        switch parseColumnsBody(stripped) {
        case .success(let columns):
            guard !columns.isEmpty else { return .failure(.noColumnsFound) }
            return .success(ParsedSchema(tableName: "custom_table", columns: columns))
        case .failure(let err):
            return .failure(err)
        }
    }

    private static func parseColumnsBody(_ body: String) -> Result<[ColumnSchema], DDLParseError> {
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

        var columns: [ColumnSchema] = []

        for (partIndex, part) in parts.enumerated() {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                // Allow trailing comma on the very last column
                if partIndex == parts.count - 1 {
                    continue
                } else {
                    return .failure(.invalidColumn("empty comma entry"))
                }
            }

            // Skip table constraints (CONSTRAINT, PRIMARY KEY (...), FOREIGN KEY (...), etc.)
            let constraintPattern = "(?i)^(CONSTRAINT|PRIMARY\\s+KEY|FOREIGN\\s+KEY|UNIQUE|CHECK)\\b"
            if let regex = try? NSRegularExpression(pattern: constraintPattern),
               regex.firstMatch(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count)) != nil {
                continue
            }

            // Match column name: quoted or unquoted identifier
            let quotedPattern = "^[\"`']([^\"`']+)[\"`']\\s+(\\S.*)$"
            let unquotedPattern = "^([a-zA-Z_][a-zA-Z0-9_]*)\\s+(\\S.*)$"

            var colName: String?
            var remainder: String?

            if let regex = try? NSRegularExpression(pattern: quotedPattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
                colName = (trimmed as NSString).substring(with: match.range(at: 1))
                remainder = (trimmed as NSString).substring(with: match.range(at: 2))
            } else if let regex = try? NSRegularExpression(pattern: unquotedPattern),
                      let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
                colName = (trimmed as NSString).substring(with: match.range(at: 1))
                remainder = (trimmed as NSString).substring(with: match.range(at: 2))
            } else {
                // If the line is not a recognized column pattern and not a constraint, it is an invalid line
                return .failure(.invalidColumn(trimmed))
            }

            guard let name = colName, let rem = remainder?.trimmingCharacters(in: .whitespacesAndNewlines), !rem.isEmpty else {
                return .failure(.invalidColumn(trimmed))
            }

            // Extract data type (including parenthesized params like NUMERIC(12, 2) or multi-word types like TIMESTAMP WITH TIME ZONE)
            let typePattern = "^((?:DOUBLE\\s+PRECISION|TIMESTAMP(?:TZ)?(?:\\s+WITH(?:OUT)?\\s+TIME\\s+ZONE)?|TIME(?:TZ)?(?:\\s+WITH(?:OUT)?\\s+TIME\\s+ZONE)?|CHARACTER\\s+VARYING(?:\\s*\\([0-9,\\s]+\\))?|BIT\\s+VARYING(?:\\s*\\([0-9,\\s]+\\))?|[a-zA-Z0-9_]+(?:\\s*\\([0-9,\\s]+\\))?))(?:\\s+(.*))?$"
            let rawType: String
            let constraints: String

            if let typeRegex = try? NSRegularExpression(pattern: typePattern, options: [.caseInsensitive]),
               let typeMatch = typeRegex.firstMatch(in: rem, range: NSRange(location: 0, length: rem.utf16.count)) {
                rawType = (rem as NSString).substring(with: typeMatch.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                if typeMatch.range(at: 2).location != NSNotFound {
                    constraints = (rem as NSString).substring(with: typeMatch.range(at: 2))
                } else {
                    constraints = ""
                }
            } else {
                rawType = rem
                constraints = ""
            }

            let fullTypeString = rawType + " " + constraints
            let normalizedType = normalizePostgresType(fullTypeString)
            let isNullable = constraints.range(of: "NOT\\s+NULL", options: [.regularExpression, .caseInsensitive]) == nil
            let isPrimaryKey = constraints.range(of: "PRIMARY\\s+KEY", options: [.regularExpression, .caseInsensitive]) != nil || rawType.localizedCaseInsensitiveContains("SERIAL")

            columns.append(ColumnSchema(
                name: name,
                dataType: normalizedType,
                rawType: rawType,
                isNullable: isNullable,
                isPrimaryKey: isPrimaryKey
            ))
        }

        return .success(columns)
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
