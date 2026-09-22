import Foundation
import CoreXLSX
import ZIPFoundation

public struct FileParser {
    public static func parseFile(at url: URL, maxPreviewRows: Int = 100) throws -> FileData {
        let pathExtension = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        if pathExtension == "csv" || pathExtension == "tsv" || pathExtension == "txt" {
            return try parseCSVPreview(at: url, fileName: fileName, fileSize: fileSize, isTSV: pathExtension == "tsv", maxPreviewRows: maxPreviewRows)
        } else if pathExtension == "xlsx" {
            if !isZipFile(at: url) {
                if let csvData = try? parseCSVPreview(at: url, fileName: fileName, fileSize: fileSize, isTSV: false, maxPreviewRows: maxPreviewRows) {
                    return csvData
                }
            }
            if let convertedCSVURL = try? XLSXToCSVConverter.convertToCSV(xlsxURL: url),
               let csvData = try? parseCSVPreview(at: convertedCSVURL, fileName: fileName, fileSize: fileSize, isTSV: false, maxPreviewRows: maxPreviewRows) {
                return FileData(
                    fileURL: url,
                    name: fileName,
                    size: fileSize,
                    format: .xlsx,
                    headers: csvData.headers,
                    totalRows: csvData.totalRows,
                    previewRows: csvData.previewRows,
                    allData: [],
                    sheets: csvData.sheets,
                    selectedSheet: csvData.selectedSheet
                )
            }
            return try parseXLSXPreview(at: url, fileName: fileName, fileSize: fileSize, maxPreviewRows: maxPreviewRows)
        } else {
            throw NSError(domain: "FileParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: .\(pathExtension)"])
        }
    }

    private static func parseCSVPreview(at url: URL, fileName: String, fileSize: Int64, isTSV: Bool, maxPreviewRows: Int) throws -> FileData {
        let delimiter: Character = isTSV ? "\t" : ","
        var headers: [String] = []
        var previewRows: [[String: String]] = []
        var totalRowsCount = 0

        var isFirstLine = true

        try streamLines(from: url) { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return }

            if isFirstLine {
                headers = parseCSVLine(line, delimiter: delimiter)
                isFirstLine = false
            } else {
                totalRowsCount += 1
                if previewRows.count < maxPreviewRows {
                    let fields = parseCSVLine(line, delimiter: delimiter)
                    var rowDict: [String: String] = [:]
                    for (index, header) in headers.enumerated() {
                        let value = index < fields.count ? fields[index] : ""
                        rowDict[header] = value
                    }
                    previewRows.append(rowDict)
                }
            }
        }

        guard !headers.isEmpty else {
            throw NSError(domain: "FileParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "File is empty"])
        }

        return FileData(
            fileURL: url,
            name: fileName,
            size: fileSize,
            format: .csv,
            headers: headers,
            totalRows: totalRowsCount,
            previewRows: previewRows,
            allData: [],
            sheets: ["Sheet1"],
            selectedSheet: "Sheet1"
        )
    }

    public static func parseCSVLine(_ line: String, delimiter: Character = ",") -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == delimiter && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        return fields
    }

    private static func parseXLSXPreview(at url: URL, fileName: String, fileSize: Int64, maxPreviewRows: Int) throws -> FileData {
        guard let file = XLSXFile(filepath: url.path) else {
            throw NSError(domain: "FileParser", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not open Excel file"])
        }

        let workbook = try? file.parseWorkbooks()
        let sharedStrings = try? file.parseSharedStrings()
        let sheetNames = workbook?.flatMap { $0.sheets.items.compactMap { $0.name } } ?? []
        let selectedSheet = sheetNames.first ?? "Sheet1"

        let worksheetPaths = findWorksheetPaths(from: file, url: url)
        guard let worksheetPath = worksheetPaths.first else {
            if let csvData = try? parseCSVPreview(at: url, fileName: fileName, fileSize: fileSize, isTSV: false, maxPreviewRows: maxPreviewRows) {
                return csvData
            }
            throw NSError(domain: "FileParser", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to parse file: No valid worksheets found in Excel file. Please ensure it is a valid .xlsx file or try re-saving as standard XLSX/CSV in OnlyOffice."])
        }

        let worksheet = try file.parseWorksheet(at: worksheetPath)
        let rows = worksheet.data?.rows ?? []
        guard let firstRow = rows.first else {
            throw NSError(domain: "FileParser", code: 5, userInfo: [NSLocalizedDescriptionKey: "Worksheet is empty"])
        }

        var headers: [String] = []
        var colRefToHeader: [String: String] = [:]

        for cell in firstRow.cells {
            let colRef = cell.reference.column.value
            let headerVal = getCellValue(cell, sharedStrings: sharedStrings).trimmingCharacters(in: .whitespacesAndNewlines)
            let finalHeader = headerVal.isEmpty ? "col_\(colRef)" : headerVal
            headers.append(finalHeader)
            colRefToHeader[colRef] = finalHeader
        }

        let totalDataRows = max(0, rows.count - 1)
        let previewCount = min(maxPreviewRows, totalDataRows)
        var previewRows: [[String: String]] = []

        for row in rows.dropFirst().prefix(previewCount) {
            var rowDict: [String: String] = [:]
            for header in headers {
                rowDict[header] = ""
            }
            for cell in row.cells {
                let colRef = cell.reference.column.value
                if let headerName = colRefToHeader[colRef] {
                    rowDict[headerName] = getCellValue(cell, sharedStrings: sharedStrings)
                }
            }
            previewRows.append(rowDict)
        }

        return FileData(
            fileURL: url,
            name: fileName,
            size: fileSize,
            format: .xlsx,
            headers: headers,
            totalRows: totalDataRows,
            previewRows: previewRows,
            allData: [],
            sheets: sheetNames.isEmpty ? ["Sheet1"] : sheetNames,
            selectedSheet: selectedSheet
        )
    }

    public static func streamBatches(
        from fileData: FileData,
        batchSize: Int,
        processBatch: (_ batch: [[String: String]], _ batchIndex: Int) throws -> Void
    ) throws {
        let size = max(1, batchSize)

        if !fileData.allData.isEmpty {
            var i = 0
            var batchIndex = 0
            while i < fileData.allData.count {
                let end = min(i + size, fileData.allData.count)
                let chunk = Array(fileData.allData[i..<end])
                batchIndex += 1
                try processBatch(chunk, batchIndex)
                i += size
            }
            return
        }

        guard let url = fileData.fileURL else {
            if !fileData.previewRows.isEmpty {
                try processBatch(fileData.previewRows, 1)
            }
            return
        }

        if fileData.format == .csv {
            try streamCSVBatches(url: url, isTSV: url.pathExtension.lowercased() == "tsv", headers: fileData.headers, batchSize: size, processBatch: processBatch)
        } else if fileData.format == .xlsx {
            if let convertedCSVURL = try? XLSXToCSVConverter.convertToCSV(xlsxURL: url) {
                try streamCSVBatches(url: convertedCSVURL, isTSV: false, headers: fileData.headers, batchSize: size, processBatch: processBatch)
            } else {
                try streamXLSXBatches(url: url, headers: fileData.headers, batchSize: size, processBatch: processBatch)
            }
        }
    }

    private static func streamCSVBatches(
        url: URL,
        isTSV: Bool,
        headers: [String],
        batchSize: Int,
        processBatch: (_ batch: [[String: String]], _ batchIndex: Int) throws -> Void
    ) throws {
        let delimiter: Character = isTSV ? "\t" : ","
        var currentBatch: [[String: String]] = []
        var isFirstLine = true
        var batchIndex = 0

        try streamLines(from: url) { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return }

            if isFirstLine {
                isFirstLine = false
            } else {
                let fields = parseCSVLine(line, delimiter: delimiter)
                var rowDict: [String: String] = [:]
                for (index, header) in headers.enumerated() {
                    let value = index < fields.count ? fields[index] : ""
                    rowDict[header] = value
                }
                currentBatch.append(rowDict)

                if currentBatch.count >= batchSize {
                    batchIndex += 1
                    try processBatch(currentBatch, batchIndex)
                    currentBatch.removeAll(keepingCapacity: true)
                }
            }
        }

        if !currentBatch.isEmpty {
            batchIndex += 1
            try processBatch(currentBatch, batchIndex)
        }
    }

    private static func streamXLSXBatches(
        url: URL,
        headers: [String],
        batchSize: Int,
        processBatch: (_ batch: [[String: String]], _ batchIndex: Int) throws -> Void
    ) throws {
        guard let file = XLSXFile(filepath: url.path) else {
            throw NSError(domain: "FileParser", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not open Excel file"])
        }

        let sharedStrings = try? file.parseSharedStrings()
        let worksheetPaths = findWorksheetPaths(from: file, url: url)
        guard let worksheetPath = worksheetPaths.first else {
            throw NSError(domain: "FileParser", code: 4, userInfo: [NSLocalizedDescriptionKey: "No worksheets found in Excel file."])
        }

        let worksheet = try file.parseWorksheet(at: worksheetPath)
        let rows = worksheet.data?.rows ?? []
        guard let firstRow = rows.first else { return }

        var colRefToHeader: [String: String] = [:]
        for cell in firstRow.cells {
            let colRef = cell.reference.column.value
            let headerVal = getCellValue(cell, sharedStrings: sharedStrings).trimmingCharacters(in: .whitespacesAndNewlines)
            let finalHeader = headerVal.isEmpty ? "col_\(colRef)" : headerVal
            colRefToHeader[colRef] = finalHeader
        }

        var currentBatch: [[String: String]] = []
        var batchIndex = 0

        for row in rows.dropFirst() {
            var rowDict: [String: String] = [:]
            for header in headers {
                rowDict[header] = ""
            }
            for cell in row.cells {
                let colRef = cell.reference.column.value
                if let headerName = colRefToHeader[colRef] {
                    rowDict[headerName] = getCellValue(cell, sharedStrings: sharedStrings)
                }
            }
            currentBatch.append(rowDict)

            if currentBatch.count >= batchSize {
                batchIndex += 1
                try processBatch(currentBatch, batchIndex)
                currentBatch.removeAll(keepingCapacity: true)
            }
        }

        if !currentBatch.isEmpty {
            batchIndex += 1
            try processBatch(currentBatch, batchIndex)
        }
    }

    private static func streamLines(from url: URL, block: (String) throws -> Void) throws {
        guard let stream = InputStream(url: url) else { return }
        stream.open()
        defer { stream.close() }

        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        var currentLine = ""
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead <= 0 { break }

            let chunk = String(decoding: Data(bytes: buffer, count: bytesRead), as: UTF8.self)
            for char in chunk {
                if char == "\n" {
                    if !currentLine.isEmpty && currentLine.last == "\r" {
                        currentLine.removeLast()
                    }
                    try block(currentLine)
                    currentLine = ""
                } else {
                    currentLine.append(char)
                }
            }
        }
        if !currentLine.isEmpty {
            if currentLine.last == "\r" { currentLine.removeLast() }
            try block(currentLine)
        }
    }

    private static func getCellValue(_ cell: Cell, sharedStrings: SharedStrings?) -> String {
        if let sharedStrings = sharedStrings, let str = cell.stringValue(sharedStrings) {
            return str
        }
        return cell.value ?? ""
    }

    private static func isZipFile(at url: URL) -> Bool {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? fileHandle.close() }
        let data = fileHandle.readData(ofLength: 4)
        return data.count == 4 && data[0] == 0x50 && data[1] == 0x4B && data[2] == 0x03 && data[3] == 0x04
    }

    private static func findWorksheetPaths(from file: XLSXFile, url: URL) -> [String] {
        if let paths = try? file.parseWorksheetPaths(), !paths.isEmpty {
            return paths
        }

        var candidatePaths: [String] = []
        var testedPaths = Set<String>()

        // Fallback 1: Use ZIPFoundation Archive to scan all XML entries under worksheets/ or sheets/
        if let archive = try? Archive(url: url, accessMode: .read) {
            for entry in archive {
                let pathString = entry.path
                let lower = pathString.lowercased()
                if (lower.contains("worksheets/") || lower.contains("sheets/")) && lower.hasSuffix(".xml") {
                    let cleanPath = pathString.hasPrefix("/") ? String(pathString.dropFirst()) : pathString
                    if !testedPaths.contains(cleanPath) {
                        testedPaths.insert(cleanPath)
                        if (try? file.parseWorksheet(at: cleanPath)) != nil {
                            candidatePaths.append(cleanPath)
                        }
                    }
                }
            }
        }

        if !candidatePaths.isEmpty {
            return candidatePaths
        }

        // Fallback 2: Common default worksheet path conventions in OOXML
        let defaultPathStrings = [
            "xl/worksheets/sheet1.xml",
            "xl/worksheets/Sheet1.xml",
            "worksheets/sheet1.xml",
            "worksheets/Sheet1.xml",
            "xl/worksheets/sheet0.xml",
            "xl/worksheets/sheet.xml"
        ]

        for pathString in defaultPathStrings {
            if !testedPaths.contains(pathString) {
                testedPaths.insert(pathString)
                if (try? file.parseWorksheet(at: pathString)) != nil {
                    candidatePaths.append(pathString)
                }
            }
        }

        return candidatePaths
    }
}
