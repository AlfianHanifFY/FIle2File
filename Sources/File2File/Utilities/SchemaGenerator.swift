import Foundation

public struct SchemaGenerator {
    public static func sanitizeIdentifier(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "column" }

        var clean = trimmed.replacingOccurrences(of: "[^a-z0-9_]", with: "_", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        guard !clean.isEmpty else { return "column" }
        if clean.first?.isNumber == true {
            clean = "col_\(clean)"
        }
        return clean
    }

    public static func sanitizeTableName(fileName: String, sheetName: String? = nil) -> String {
        let baseName = sheetName ?? (fileName as NSString).deletingPathExtension
        let clean = sanitizeIdentifier(baseName)
        return clean.isEmpty ? "target_table" : clean
    }

    public static func inferColumnType(values: [String]) -> String {
        let nonNullValues = values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.lowercased() != "null" }

        guard !nonNullValues.isEmpty else { return "VARCHAR(255)" }

        // UUID check
        let uuidPattern = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        if nonNullValues.allSatisfy({ $0.range(of: uuidPattern, options: .regularExpression) != nil }) {
            return "UUID"
        }

        // Boolean check
        if nonNullValues.allSatisfy({ ["true", "false", "t", "f", "yes", "no"].contains($0.lowercased()) }) {
            return "BOOLEAN"
        }

        // Numbers check
        let isNumbers = nonNullValues.allSatisfy { val in
            let cleanVal = val.replacingOccurrences(of: ",", with: "")
            return Double(cleanVal) != nil
        }

        if isNumbers {
            let isIntegers = nonNullValues.allSatisfy { val in
                let cleanVal = val.replacingOccurrences(of: ",", with: "")
                return Int64(cleanVal) != nil
            }
            if isIntegers {
                let maxVal = nonNullValues.compactMap { val -> Int64? in
                    let cleanVal = val.replacingOccurrences(of: ",", with: "")
                    return Int64(cleanVal).map { abs($0) }
                }.max() ?? 0
                
                if maxVal > 2147483647 { return "BIGINT" }
                return "INTEGER"
            }
            return "NUMERIC(12, 2)"
        }

        // Date check
        let isDates = nonNullValues.allSatisfy { val in
            let dateFormats = ["yyyy-MM-dd", "yyyy/MM/dd", "MM/dd/yyyy", "dd-MM-yyyy"]
            let formatter = DateFormatter()
            return dateFormats.contains { fmt in
                formatter.dateFormat = fmt
                return formatter.date(from: val) != nil
            }
        }
        if isDates { return "DATE" }

        let maxLen = nonNullValues.map { $0.count }.max() ?? 0
        if maxLen > 255 { return "TEXT" }
        return "VARCHAR(255)"
    }

    public static func generateDDL(from fileData: FileData) -> String {
        let tableName = sanitizeTableName(fileName: fileData.name, sheetName: fileData.selectedSheet)
        let headers = fileData.headers
        let rows = fileData.allData.isEmpty ? fileData.previewRows : fileData.allData

        var usedNames = Set<String>()
        var columnDefs: [String] = []

        for header in headers {
            let rawColName = sanitizeIdentifier(header)
            var colName = rawColName
            var count = 1

            while usedNames.contains(colName) {
                colName = "\(rawColName)_\(count)"
                count += 1
            }
            usedNames.insert(colName)

            let values = rows.compactMap { $0[header] }
            let inferredType = inferColumnType(values: values)

            columnDefs.append("    \"\(colName)\" \(inferredType)")
        }

        return "CREATE TABLE \(tableName) (\n\(columnDefs.joined(separator: ",\n"))\n);"
    }
}
