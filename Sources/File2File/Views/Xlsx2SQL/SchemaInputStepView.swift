import SwiftUI

public struct SchemaInputStepView: View {
    @Binding var ddlText: String
    let fileData: FileData?
    let onSchemaParsed: (ParsedSchema, String) -> Void
    let onNextStep: () -> Void
    let onPrevStep: () -> Void

    @State private var validationResult: Result<ParsedSchema, DDLParseError>? = nil
    @State private var isChecked: Bool = false

    private var parsedSchema: ParsedSchema? {
        if case .success(let schema) = validationResult {
            return schema
        }
        return nil
    }

    private var parseError: String? {
        if case .failure(let err) = validationResult {
            return err.errorDescription ?? err.localizedDescription
        }
        return nil
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Section
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PostgreSQL DDL Schema")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Paste your `CREATE TABLE` DDL statement or generate one directly from file columns.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    // Explicit 'Check' button requested by user
                    Button(action: {
                        performCheck()
                    }) {
                        Label("Check", systemImage: "checkmark.shield")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .help("Check and validate DDL statement")

                    if let file = fileData {
                        Button(action: {
                            let generated = SchemaGenerator.generateDDL(from: file)
                            ddlText = generated
                            performCheck()
                        }) {
                            Label("Generate", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .help("Auto-generate DDL schema from file columns")
                    }
                }
            }

            // Code Editor Box
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("DDL STATEMENT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        performCheck()
                    }) {
                        Label("Check", systemImage: "checkmark.circle")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if !ddlText.isEmpty {
                        Button("Clear") {
                            ddlText = ""
                            performCheck()
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }

                TextEditor(text: $ddlText)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                parseError != nil
                                    ? Color.orange.opacity(0.8)
                                    : (parsedSchema != nil ? Color.green.opacity(0.6) : Color(NSColor.separatorColor).opacity(0.6)),
                                lineWidth: parseError != nil ? 1.5 : 1
                            )
                    )
                    .frame(minHeight: 220)
                    .onChange(of: ddlText) {
                        performCheck()
                    }
            }

            // Validation Status Callout
            if let schema = parsedSchema {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Valid DDL Schema Detected")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Target Table: **\(schema.tableName)** • \(schema.columns.count) columns defined")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
            } else if let error = parseError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schema Parsing Attention Required")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            } else if ddlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    
                    Text("Paste your PostgreSQL DDL or click Auto-Generate DDL, then click **Check** to validate.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.06)))
            }

            // Footer Navigation Bar
            HStack {
                Button(action: onPrevStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Back to file selection")

                Spacer()

                Button(action: {
                    performCheck()
                    if let schema = parsedSchema {
                        onSchemaParsed(schema, ddlText)
                        onNextStep()
                    }
                }) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(parsedSchema == nil)
                .help("Next: Column mapping")
            }
        }
        .onAppear {
            if ddlText.isEmpty, let file = fileData {
                ddlText = SchemaGenerator.generateDDL(from: file)
            }
            performCheck()
        }
    }

    private func performCheck() {
        validationResult = DDLParser.validateAndParseDDL(ddlText)
        isChecked = true
    }
}
