import Foundation
import ZIPFoundation

public struct XLSXToCSVConverter {
    public static func convertToCSV(xlsxURL: URL, outputCSVURL: URL? = nil) throws -> URL {
        let destinationURL = outputCSVURL ?? FileManager.default.temporaryDirectory.appendingPathComponent("xlsx_conv_\(UUID().uuidString).csv")

        guard let archive = try? Archive(url: xlsxURL, accessMode: .read) else {
            throw NSError(domain: "XLSXToCSVConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open Excel zip archive"])
        }

        // 1. Extract sharedStrings.xml if present
        var sharedStrings: [String] = []
        if let sharedStringsEntry = archive["xl/sharedStrings.xml"] ?? archive["xl/SharedStrings.xml"] {
            sharedStrings = try parseSharedStrings(archive: archive, entry: sharedStringsEntry)
        }

        // 2. Find worksheet entry
        var worksheetEntry: Entry? = nil
        for entry in archive {
            let path = entry.path.lowercased()
            if (path.contains("worksheets/") || path.contains("sheets/")) && path.hasSuffix(".xml") {
                worksheetEntry = entry
                break
            }
        }

        guard let sheetEntry = worksheetEntry else {
            throw NSError(domain: "XLSXToCSVConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "No worksheet XML entry found in Excel archive"])
        }

        // 3. Extract worksheet XML data
        var sheetData = Data()
        _ = try archive.extract(sheetEntry) { data in
            sheetData.append(data)
        }

        // 4. Open destination output stream
        guard let outputStream = OutputStream(url: destinationURL, append: false) else {
            throw NSError(domain: "XLSXToCSVConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not create destination CSV file"])
        }
        outputStream.open()
        defer { outputStream.close() }

        // 5. Parse worksheet XML and stream rows to destination CSV file
        let parser = WorksheetXMLParser(data: sheetData, sharedStrings: sharedStrings, outputStream: outputStream)
        parser.parse()

        return destinationURL
    }

    private static func parseSharedStrings(archive: Archive, entry: Entry) throws -> [String] {
        var xmlData = Data()
        _ = try archive.extract(entry) { data in
            xmlData.append(data)
        }

        let parser = SharedStringsXMLParser(data: xmlData)
        return parser.parse()
    }

    public static func columnNameToIndex(_ colName: String) -> Int {
        var result = 0
        for char in colName.unicodeScalars {
            if char.value >= 65 && char.value <= 90 {
                result = result * 26 + Int(char.value - 64)
            } else if char.value >= 97 && char.value <= 122 {
                result = result * 26 + Int(char.value - 96)
            }
        }
        return max(0, result - 1)
    }
}

// MARK: - SharedStrings XML Parser
private class SharedStringsXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    var strings: [String] = []
    private var currentText = ""
    private var inTTag = false
    private var currentStringAccumulator = ""
    private var inSi = false

    init(data: Data) {
        self.parser = XMLParser(data: data)
        super.init()
        self.parser.delegate = self
    }

    func parse() -> [String] {
        parser.parse()
        return strings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "si" {
            inSi = true
            currentStringAccumulator = ""
        } else if elementName == "t" {
            inTTag = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTTag {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            currentStringAccumulator += currentText
            inTTag = false
        } else if elementName == "si" {
            strings.append(currentStringAccumulator)
            inSi = false
        }
    }
}

// MARK: - Worksheet XML SAX Parser
private class WorksheetXMLParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private let sharedStrings: [String]
    private let outputStream: OutputStream

    private var currentRow: [Int: String] = [:]
    private var currentCellRef = ""
    private var currentCellType = ""
    private var currentText = ""
    private var inVTag = false
    private var inTTag = false

    init(data: Data, sharedStrings: [String], outputStream: OutputStream) {
        self.parser = XMLParser(data: data)
        self.sharedStrings = sharedStrings
        self.outputStream = outputStream
        super.init()
        self.parser.delegate = self
    }

    func parse() {
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "row" {
            currentRow = [:]
        } else if elementName == "c" {
            currentCellRef = attributeDict["r"] ?? ""
            currentCellType = attributeDict["t"] ?? ""
            currentText = ""
        } else if elementName == "v" {
            inVTag = true
            currentText = ""
        } else if elementName == "t" {
            inTTag = true
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inVTag || inTTag {
            currentText += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "v" || elementName == "t" {
            inVTag = false
            inTTag = false

            let val = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            var cellValue = val

            if currentCellType == "s", let idx = Int(val), idx >= 0 && idx < sharedStrings.count {
                cellValue = sharedStrings[idx]
            } else if currentCellType == "b" {
                cellValue = (val == "1" || val.lowercased() == "true") ? "TRUE" : "FALSE"
            }

            let colName = String(currentCellRef.prefix(while: { $0.isLetter }))
            let colIndex = XLSXToCSVConverter.columnNameToIndex(colName.isEmpty ? "A" : colName)
            currentRow[colIndex] = cellValue
        } else if elementName == "c" {
            currentCellRef = ""
            currentCellType = ""
        } else if elementName == "row" {
            writeRowToCSV(currentRow)
        }
    }

    private func writeRowToCSV(_ row: [Int: String]) {
        guard !row.isEmpty else { return }
        let maxCol = (row.keys.max() ?? 0)
        var lineFields: [String] = []
        for col in 0...maxCol {
            let rawValue = row[col] ?? ""
            lineFields.append(escapeCSVField(rawValue))
        }
        let line = lineFields.joined(separator: ",") + "\n"
        if let data = line.data(using: .utf8) {
            data.withUnsafeBytes { ptr in
                if let baseAddress = ptr.bindMemory(to: UInt8.self).baseAddress {
                    outputStream.write(baseAddress, maxLength: data.count)
                }
            }
        }
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
