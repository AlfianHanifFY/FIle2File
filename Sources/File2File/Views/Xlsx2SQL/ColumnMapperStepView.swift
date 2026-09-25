import SwiftUI

public struct ColumnMapperStepView: View {
    @Binding var mappings: [ColumnMapping]
    let fileData: FileData
    let onNextStep: () -> Void
    let onPrevStep: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header Section
            VStack(alignment: .leading, spacing: 4) {
                Text("Column Mapping & Transformations")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Verify and map PostgreSQL schema columns to your source data headers.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Helper Hint Banner
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text("If your source file has fewer columns than your DDL schema, you can map missing fields to **Fixed / Custom Value** and type a custom literal, or leave as **Do Not Map**.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.08)))

            // Table Header Bar
            HStack {
                Text("SQL COLUMN & TYPE")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 150, idealWidth: 170, alignment: .leading)

                Spacer()

                Text("SOURCE / FIXED VALUE")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 200, idealWidth: 240, alignment: .leading)

                Spacer()

                Text("STATUS / MATCH")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 90, idealWidth: 110, alignment: .center)

                Spacer()

                Text("NULL HANDLING")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(minWidth: 150, idealWidth: 180, alignment: .leading)
            }
            .padding(.horizontal, 14)

            // Mappings List Container
            VStack(spacing: 8) {
                ForEach(Array(mappings.enumerated()), id: \.element.sqlColumn) { index, mapping in
                    HStack(alignment: .center, spacing: 12) {
                        // SQL Column & Data Type
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mapping.sqlColumn)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)

                            HStack(spacing: 4) {
                                Text(mapping.sqlType)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                    .foregroundColor(.accentColor)

                                if !mapping.isNullable {
                                    Text("NOT NULL")
                                        .font(.caption2.bold())
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.red.opacity(0.12)))
                                }
                            }
                        }
                        .frame(minWidth: 150, idealWidth: 170, alignment: .leading)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)

                        // Source Header or Custom Value Picker & Input
                        VStack(alignment: .leading, spacing: 6) {
                            Picker("", selection: Binding(
                                get: { mapping.excelHeader },
                                set: { newHeader in
                                    mappings[index].excelHeader = newHeader
                                    if newHeader == ColumnMapping.customValueIdentifier {
                                        mappings[index].confidence = 1.0
                                        mappings[index].nullHandling = .setNull
                                        mappings[index].defaultValue = ""
                                    }
                                }
                            )) {
                                Text("-- Do Not Map --").tag("")
                                Text("✏️ Fixed / Custom Value").tag(ColumnMapping.customValueIdentifier)
                                Divider()
                                ForEach(fileData.headers, id: \.self) { header in
                                    Text(header).tag(header)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)

                            if mapping.isCustomValue {
                                TextField("Type fixed value (e.g. 'active', 0, NOW())...", text: $mappings[index].customValue)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                        .frame(minWidth: 200, idealWidth: 240, alignment: .leading)

                        Spacer()

                        // Confidence / Status Indicator Badge
                        Group {
                            if mapping.isCustomValue {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil.line")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Custom Value")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.purple.opacity(0.12)))
                            } else if !mapping.excelHeader.isEmpty {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(mapping.confidence >= 0.8 ? Color.green : (mapping.confidence >= 0.5 ? Color.orange : Color.yellow))
                                        .frame(width: 7, height: 7)
                                    Text("\(Int(mapping.confidence * 100))% match")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.secondary.opacity(0.12)))
                            } else {
                                Text("Unmapped")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.secondary.opacity(0.08)))
                            }
                        }
                        .frame(minWidth: 90, idealWidth: 110, alignment: .center)

                        Spacer()

                        // Null Handling Strategy Picker & Input
                        Group {
                            if mapping.isCustomValue {
                                Text("Not Applicable")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .padding(.vertical, 6)
                                    .frame(minWidth: 150, idealWidth: 180, alignment: .leading)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Picker("", selection: Binding(
                                        get: { mapping.nullHandling },
                                        set: { newStrategy in
                                            mappings[index].nullHandling = newStrategy
                                        }
                                    )) {
                                        ForEach(NullHandlingStrategy.allCases) { strategy in
                                            Text(strategy.rawValue).tag(strategy)
                                        }
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)

                                    if mapping.nullHandling == .defaultValue {
                                        TextField("Type default value (e.g. 0, N/A)...", text: $mappings[index].defaultValue)
                                            .textFieldStyle(.roundedBorder)
                                            .font(.system(.caption, design: .monospaced))
                                    }
                                }
                                .frame(minWidth: 150, idealWidth: 180, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: Color.black.opacity(0.02), radius: 2, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
                    )
                }
            }

            // Navigation Bar
            HStack {
                Button(action: onPrevStep) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Back to DDL schema step")

                Spacer()

                Button(action: onNextStep) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .help("Proceed to SQL preview and export")
            }
        }
    }
}
