import SwiftUI

public struct SchemaInputStepView: View {
    @Binding var ddlText: String
    let fileData: FileData?
    let onSchemaParsed: (ParsedSchema, String) -> Void
    let onNextStep: () -> Void
    let onPrevStep: () -> Void

    @State private var parsedSchema: ParsedSchema? = nil
    @State private var parseError: String? = nil

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

                if let file = fileData {
                    Button(action: {
                        let generated = SchemaGenerator.generateDDL(from: file)
                        ddlText = generated
                        validateDDL(generated)
                    }) {
                        Label("Auto-Generate DDL", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
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

                    if !ddlText.isEmpty {
                        Button("Clear") {
                            ddlText = ""
                            validateDDL("")
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
                            .stroke(Color(NSColor.separatorColor).opacity(0.6), lineWidth: 1)
                    )
                    .frame(minHeight: 220)
                    .onChange(of: ddlText) { newValue in
                        validateDDL(newValue)
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
            }

            // Footer Navigation Bar
            HStack {
                Button(action: onPrevStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back to File Selection")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button(action: {
                    if let schema = parsedSchema {
                        onSchemaParsed(schema, ddlText)
                        onNextStep()
                    }
                }) {
                    HStack {
                        Text("Next: Column Mapping")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(parsedSchema == nil)
            }
        }
        .onAppear {
            if ddlText.isEmpty, let file = fileData {
                let generated = SchemaGenerator.generateDDL(from: file)
                ddlText = generated
                validateDDL(generated)
            } else if !ddlText.isEmpty {
                validateDDL(ddlText)
            }
        }
    }

    private func validateDDL(_ text: String) {
        if let schema = DDLParser.parseDDL(text), !schema.columns.isEmpty {
            parsedSchema = schema
            parseError = nil
        } else {
            parsedSchema = nil
            parseError = "Could not parse valid DDL. Ensure it contains a `CREATE TABLE` statement with column specifications."
        }
    }
}
