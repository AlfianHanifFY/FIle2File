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

            // Table Header Bar
            HStack {
                Text("SQL COLUMN & TYPE")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 200, alignment: .leading)

                Spacer()

                Text("SOURCE FILE HEADER")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 220, alignment: .leading)

                Spacer()

                Text("MATCH CONFIDENCE")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .center)

                Spacer()

                Text("NULL HANDLING")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                    .frame(width: 140, alignment: .leading)
            }
            .padding(.horizontal, 14)

            // Mappings List Container
            VStack(spacing: 8) {
                ForEach(Array(mappings.enumerated()), id: \.element.sqlColumn) { index, mapping in
                    HStack(spacing: 12) {
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
                        .frame(width: 200, alignment: .leading)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)

                        // Source Header Picker
                        Picker("", selection: Binding(
                            get: { mapping.excelHeader },
                            set: { newHeader in
                                mappings[index].excelHeader = newHeader
                            }
                        )) {
                            Text("-- Do Not Map --").tag("")
                            Divider()
                            ForEach(fileData.headers, id: \.self) { header in
                                Text(header).tag(header)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200, alignment: .leading)

                        Spacer()

                        // Confidence Indicator Badge
                        Group {
                            if !mapping.excelHeader.isEmpty {
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
                        .frame(width: 120, alignment: .center)

                        Spacer()

                        // Null Handling Strategy Picker
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
                        .pickerStyle(.menu)
                        .frame(width: 140, alignment: .leading)
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
                        Text("Back to DDL Schema")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Spacer()

                Button(action: onNextStep) {
                    HStack {
                        Text("Next: SQL Export")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }
}
