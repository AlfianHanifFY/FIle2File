import XCTest
import AppKit
import PDFKit
@testable import File2File

final class File2FileTests: XCTestCase {
    func testDDLParser() throws {
        let ddl = """
        CREATE TABLE users (
            id SERIAL PRIMARY KEY,
            full_name VARCHAR(100) NOT NULL,
            email TEXT,
            created_at TIMESTAMP WITH TIME ZONE
        );
        """

        let schema = DDLParser.parseDDL(ddl)
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.tableName, "users")
        XCTAssertEqual(schema?.columns.count, 4)

        XCTAssertEqual(schema?.columns[0].name, "id")
        XCTAssertEqual(schema?.columns[0].dataType, "INTEGER")
        
        XCTAssertEqual(schema?.columns[1].name, "full_name")
        XCTAssertEqual(schema?.columns[1].dataType, "VARCHAR")
        XCTAssertFalse(schema?.columns[1].isNullable ?? true)

        XCTAssertEqual(schema?.columns[3].dataType, "TIMESTAMPTZ")
    }

    func testFuzzyMatching() throws {
        let cols = [
            ColumnSchema(name: "created_at", dataType: "TIMESTAMP", rawType: "TIMESTAMP"),
            ColumnSchema(name: "user_email", dataType: "VARCHAR", rawType: "VARCHAR")
        ]
        let headers = ["Created At", "Email Address", "Phone"]

        let mappings = FuzzyMatch.autoMapColumns(sqlColumns: cols, excelHeaders: headers)
        XCTAssertEqual(mappings.count, 2)
        XCTAssertEqual(mappings[0].excelHeader, "Created At")
        XCTAssertGreaterThanOrEqual(mappings[0].confidence, 0.7)
    }

    func testSQLGenerator() throws {
        let mappings = [
            ColumnMapping(sqlColumn: "name", sqlType: "VARCHAR", isNullable: true, excelHeader: "Full Name"),
            ColumnMapping(sqlColumn: "age", sqlType: "INTEGER", isNullable: true, excelHeader: "Age")
        ]
        let rows = [
            ["Full Name": "Alice", "Age": "30"],
            ["Full Name": "Bob", "Age": "25"]
        ]
        let options = GeneratorOptions(batchSize: 500, includeCreateTable: false, useCopyFormat: false)

        let result = SQLGenerator.generateSQL(tableName: "people", mappings: mappings, rows: rows, options: options)
        XCTAssertEqual(result.totalRowsProcessed, 2)
        XCTAssertTrue(result.sql.contains("INSERT INTO \"people\" (\"name\", \"age\") VALUES"))
        XCTAssertTrue(result.sql.contains("('Alice', 30)"))
    }

    func testCSVStreamingAndExport() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let csvURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).csv")
        let outputURL = tempDir.appendingPathComponent("test_out_\(UUID().uuidString).sql")

        defer {
            try? FileManager.default.removeItem(at: csvURL)
            try? FileManager.default.removeItem(at: outputURL)
        }

        var csvText = "Full Name,Age\n"
        for i in 1...250 {
            csvText += "User \(i),\(20 + (i % 30))\n"
        }
        try csvText.write(to: csvURL, atomically: true, encoding: .utf8)

        let fileData = try FileParser.parseFile(at: csvURL, maxPreviewRows: 10)
        XCTAssertEqual(fileData.totalRows, 250)
        XCTAssertEqual(fileData.previewRows.count, 10)
        XCTAssertEqual(fileData.headers, ["Full Name", "Age"])

        let mappings = [
            ColumnMapping(sqlColumn: "name", sqlType: "VARCHAR", isNullable: true, excelHeader: "Full Name"),
            ColumnMapping(sqlColumn: "age", sqlType: "INTEGER", isNullable: true, excelHeader: "Age")
        ]
        let options = GeneratorOptions(batchSize: 50, includeCreateTable: false, useCopyFormat: false)

        let exportResult = try SQLGenerator.exportSQLToFile(
            tableName: "test_users",
            mappings: mappings,
            fileData: fileData,
            options: options,
            outputURL: outputURL
        )

        XCTAssertEqual(exportResult.totalRowsProcessed, 250)
        XCTAssertEqual(exportResult.totalBatches, 5)

        let savedSQL = try String(contentsOf: outputURL, encoding: .utf8)
        XCTAssertTrue(savedSQL.contains("INSERT INTO \"test_users\" (\"name\", \"age\") VALUES"))
        XCTAssertTrue(savedSQL.contains("('User 1', 21)"))
        XCTAssertTrue(savedSQL.contains("('User 250', 30)"))
    }

    func testAppSettingsAndHeaderDescription() throws {
        let settings = AppSettings.shared
        XCTAssertFalse(settings.outputDirectoryPath.isEmpty)

        let mappings = [
            ColumnMapping(sqlColumn: "name", sqlType: "VARCHAR", isNullable: true, excelHeader: "Full Name")
        ]
        let rows = [["Full Name": "Charlie"]]
        let options = GeneratorOptions(customDescription: "Custom Export Test Header")

        let result = SQLGenerator.generateSQL(tableName: "charlie_table", mappings: mappings, rows: rows, options: options)
        XCTAssertTrue(result.sql.contains("-- Description: Custom Export Test Header"))
    }

    func testPdfMergerEngine() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let pdf1URL = tempDir.appendingPathComponent("test1_\(UUID().uuidString).pdf")
        let pdf2URL = tempDir.appendingPathComponent("test2_\(UUID().uuidString).pdf")

        defer {
            try? FileManager.default.removeItem(at: pdf1URL)
            try? FileManager.default.removeItem(at: pdf2URL)
        }

        // Create PDF 1 (2 pages)
        let doc1 = PDFDocument()
        let img1 = NSImage(size: NSSize(width: 100, height: 100), flipped: false) { rect in
            NSColor.white.set()
            rect.fill()
            return true
        }
        if let p1 = PDFPage(image: img1), let p2 = PDFPage(image: img1) {
            doc1.insert(p1, at: 0)
            doc1.insert(p2, at: 1)
        }
        try doc1.dataRepresentation()?.write(to: pdf1URL)

        // Create PDF 2 (3 pages)
        let doc2 = PDFDocument()
        if let p1 = PDFPage(image: img1), let p2 = PDFPage(image: img1), let p3 = PDFPage(image: img1) {
            doc2.insert(p1, at: 0)
            doc2.insert(p2, at: 1)
            doc2.insert(p3, at: 2)
        }
        try doc2.dataRepresentation()?.write(to: pdf2URL)

        guard let item1 = PdfConverterEngine.loadMergePdfItem(from: pdf1URL),
              let item2 = PdfConverterEngine.loadMergePdfItem(from: pdf2URL) else {
            XCTFail("Failed to load test PDF items")
            return
        }

        XCTAssertEqual(item1.pageCount, 2)
        XCTAssertEqual(item2.pageCount, 3)

        let options = MergePdfOptions(outputFileName: "Merged_Result.pdf")
        let mergedResult = await PdfConverterEngine.mergePdfFiles(items: [item1, item2], options: options)

        XCTAssertNotNil(mergedResult)
        XCTAssertEqual(mergedResult?.name, "Merged_Result.pdf")
        XCTAssertEqual(mergedResult?.pageCount, 5)

        if let data = mergedResult?.data, let outputDoc = PDFDocument(data: data) {
            XCTAssertEqual(outputDoc.pageCount, 5)
        } else {
            XCTFail("Failed to create PDFDocument from merged data")
        }
    }

    func testMisnamedCSVAsXLSX() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let misnamedURL = tempDir.appendingPathComponent("test_misnamed_\(UUID().uuidString).xlsx")
        defer { try? FileManager.default.removeItem(at: misnamedURL) }

        let csvContent = "HeaderA,HeaderB\nValue1,Value2\nValue3,Value4\n"
        try csvContent.write(to: misnamedURL, atomically: true, encoding: .utf8)

        let fileData = try FileParser.parseFile(at: misnamedURL)
        XCTAssertEqual(fileData.headers, ["HeaderA", "HeaderB"])
        XCTAssertEqual(fileData.totalRows, 2)
        XCTAssertEqual(fileData.previewRows.first?["HeaderA"], "Value1")
    }

    func testColumnNameToIndex() throws {
        XCTAssertEqual(XLSXToCSVConverter.columnNameToIndex("A"), 0)
        XCTAssertEqual(XLSXToCSVConverter.columnNameToIndex("B"), 1)
        XCTAssertEqual(XLSXToCSVConverter.columnNameToIndex("Z"), 25)
        XCTAssertEqual(XLSXToCSVConverter.columnNameToIndex("AA"), 26)
        XCTAssertEqual(XLSXToCSVConverter.columnNameToIndex("AB"), 27)
    }

    func testCSV2JSONConversion() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let csvURL = tempDir.appendingPathComponent("test_json_\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: csvURL) }

        let csvContent = "name,age,city\nAlice,30,New York\nBob,25,San Francisco\n"
        try csvContent.write(to: csvURL, atomically: true, encoding: .utf8)

        let fileData = try FileParser.parseFile(at: csvURL)
        XCTAssertEqual(fileData.headers, ["name", "age", "city"])
        XCTAssertEqual(fileData.totalRows, 2)

        var allRows: [[String: String]] = []
        try FileParser.streamBatches(from: fileData, batchSize: 10) { batch, _ in
            allRows.append(contentsOf: batch)
        }
        XCTAssertEqual(allRows.count, 2)

        let jsonData = try JSONSerialization.data(withJSONObject: allRows, options: [.prettyPrinted, .sortedKeys])
        let jsonString = String(data: jsonData, encoding: .utf8)
        XCTAssertNotNil(jsonString)
        XCTAssertTrue(jsonString?.contains("\"name\" : \"Alice\"") ?? false)
        XCTAssertTrue(jsonString?.contains("\"city\" : \"San Francisco\"") ?? false)
    }

    func testExcel2CSVConversion() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let misnamedXLSX = tempDir.appendingPathComponent("test_conv_\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: misnamedXLSX) }

        let content = "Col1,Col2\nVal1,Val2\n"
        try content.write(to: misnamedXLSX, atomically: true, encoding: .utf8)

        let fileData = try FileParser.parseFile(at: misnamedXLSX)
        XCTAssertEqual(fileData.headers, ["Col1", "Col2"])
        XCTAssertEqual(fileData.previewRows.count, 1)
        XCTAssertEqual(fileData.previewRows[0]["Col1"], "Val1")
    }

    func testPdfSplitterEngine() async throws {
        // Range parsing tests
        let parsed = PdfConverterEngine.parsePageRanges("1-3, 5, 8-10", totalPages: 10)
        XCTAssertEqual(parsed, [1, 2, 3, 5, 8, 9, 10])

        let rangeStr = PdfConverterEngine.formatPageRanges(selectedPages: Set([1, 2, 3, 5, 8, 9]))
        XCTAssertEqual(rangeStr, "1-3, 5, 8-9")

        // PDF document creation & splitting test
        let pdfDoc = PDFDocument()
        for _ in 1...5 {
            let img = NSImage(size: NSSize(width: 100, height: 100), flipped: false) { rect in
                NSColor.red.set()
                rect.fill()
                return true
            }
            if let page = PDFPage(image: img) {
                pdfDoc.insert(page, at: pdfDoc.pageCount)
            }
        }

        let tempDir = FileManager.default.temporaryDirectory
        let samplePdfURL = tempDir.appendingPathComponent("test_sample_\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: samplePdfURL) }
        try pdfDoc.dataRepresentation()?.write(to: samplePdfURL)

        let splitOpts = PdfSplitOptions(mode: .customRanges, rangeString: "1-2, 4", outputPrefix: "TestSplit", combineSelectedRanges: true)
        let results = await PdfConverterEngine.splitPdfDocument(url: samplePdfURL, options: splitOpts, selectedPages: Set([1, 2, 4]))

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].pageCount, 3)
        XCTAssertTrue(results[0].name.contains("TestSplit"))
    }

    func testPdfSignerEngine() throws {
        // Create sample PDF document
        let pdfDoc = PDFDocument()
        let img = NSImage(size: NSSize(width: 200, height: 300), flipped: false) { rect in
            NSColor.white.set()
            rect.fill()
            return true
        }
        if let page = PDFPage(image: img) {
            pdfDoc.insert(page, at: 0)
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let inputPdfURL = tempDir.appendingPathComponent("test_sign_input_\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: inputPdfURL) }
        try pdfDoc.dataRepresentation()?.write(to: inputPdfURL)

        // Load item
        let item = PdfSignerEngine.loadPdfSignItem(from: inputPdfURL)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.pageCount, 1)

        // Create sample signature overlay
        let sigImg = NSImage(size: NSSize(width: 100, height: 50), flipped: false) { rect in
            NSColor.blue.set()
            rect.fill()
            return true
        }
        let overlay = VisualSignatureOverlay(
            image: sigImg,
            pageIndex: 0,
            position: CGPoint(x: 0.5, y: 0.5),
            size: CGSize(width: 0.3, height: 0.1)
        )

        // Sign PDF
        let signedData = try PdfSignerEngine.signPdf(
            pdfUrl: inputPdfURL,
            visualOverlays: [overlay],
            digitalConfig: nil
        )
        XCTAssertGreaterThan(signedData.count, 0)

        let resultDoc = PDFDocument(data: signedData)
        XCTAssertEqual(resultDoc?.pageCount, 1)
    }

    func testVideoToGifOptionsAndCatalog() throws {
        let options = VideoToGifOptions(
            startTime: 1.5,
            endTime: 8.0,
            fps: 20,
            resolution: .p480,
            speedMultiplier: 1.5,
            loopCount: 0
        )
        XCTAssertEqual(options.startTime, 1.5)
        XCTAssertEqual(options.endTime, 8.0)
        XCTAssertEqual(options.fps, 20)
        XCTAssertEqual(options.resolution.targetWidth, 854)
        XCTAssertEqual(options.speedMultiplier, 1.5)

        let videoTool = AppTool.allTools.first(where: { $0.id == "video2gif" })
        XCTAssertNotNil(videoTool)
        XCTAssertEqual(videoTool?.name, "Video to GIF")
        XCTAssertEqual(videoTool?.category, .media)
    }
}


