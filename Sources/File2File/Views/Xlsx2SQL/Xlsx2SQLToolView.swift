import SwiftUI

public struct Xlsx2SQLToolView: View {
    @State private var currentStep: Int = 1
    @State private var fileData: FileData? = nil
    @State private var ddlText: String = ""
    @State private var parsedSchema: ParsedSchema? = nil
    @State private var columnMappings: [ColumnMapping] = []

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            StepHeaderView(
                currentStep: currentStep,
                onReset: resetFlow,
                onStepSelect: { selectedStep in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentStep = selectedStep
                    }
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.6)

            ScrollView {
                VStack(spacing: 0) {
                    switch currentStep {
                    case 1:
                        FileSelectionStepView(
                            fileData: $fileData,
                            onFileLoaded: { data in
                                fileData = data
                                if let schema = parsedSchema {
                                    columnMappings = FuzzyMatch.autoMapColumns(sqlColumns: schema.columns, excelHeaders: data.headers)
                                }
                            },
                            onNextStep: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentStep = 2
                                }
                            }
                        )

                    case 2:
                        SchemaInputStepView(
                            ddlText: $ddlText,
                            fileData: fileData,
                            onSchemaParsed: { schema, ddl in
                                parsedSchema = schema
                                ddlText = ddl
                                if let file = fileData {
                                    syncMappings(schema: schema, headers: file.headers)
                                }
                            },
                            onNextStep: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentStep = 3
                                }
                            },
                            onPrevStep: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentStep = 1
                                }
                            }
                        )

                    case 3:
                        if let file = fileData, parsedSchema != nil {
                            ColumnMapperStepView(
                                mappings: $columnMappings,
                                fileData: file,
                                onNextStep: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentStep = 4
                                    }
                                },
                                onPrevStep: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentStep = 2
                                    }
                                }
                            )
                            .onAppear {
                                // Re-parse DDL and sync mappings every time we enter Step 3
                                if let schema = DDLParser.parseDDL(ddlText), !schema.columns.isEmpty {
                                    parsedSchema = schema
                                    syncMappings(schema: schema, headers: file.headers)
                                }
                            }
                        }

                    case 4:
                        if let file = fileData, let schema = parsedSchema {
                            SqlPreviewStepView(
                                tableName: schema.tableName,
                                mappings: columnMappings,
                                fileData: file,
                                ddlText: ddlText,
                                onPrevStep: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentStep = 3
                                    }
                                }
                            )
                        }

                    default:
                        EmptyView()
                    }
                }
                .padding(20)
            }
        }
    }

    private func syncMappings(schema: ParsedSchema, headers: [String]) {
        let existingMap = Dictionary(uniqueKeysWithValues: columnMappings.map { ($0.sqlColumn, $0) })
        var result: [ColumnMapping] = []
        for col in schema.columns {
            if let existing = existingMap[col.name] {
                var updated = existing
                updated.sqlType = col.dataType
                updated.isNullable = col.isNullable
                result.append(updated)
            } else {
                let auto = FuzzyMatch.autoMapColumns(sqlColumns: [col], excelHeaders: headers)
                if let mapped = auto.first {
                    result.append(mapped)
                }
            }
        }
        columnMappings = result
    }

    private func resetFlow() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep = 1
            fileData = nil
            ddlText = ""
            parsedSchema = nil
            columnMappings = []
        }
    }
}
