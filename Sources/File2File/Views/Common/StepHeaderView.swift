import SwiftUI

public struct StepHeaderView: View {
    let currentStep: Int
    let onReset: () -> Void
    let onStepSelect: (Int) -> Void

    private struct StepInfo {
        let number: Int
        let title: String
        let icon: String
    }

    private let steps = [
        StepInfo(number: 1, title: "File Upload", icon: "doc.badge.plus"),
        StepInfo(number: 2, title: "DDL Schema", icon: "text.badge.plus"),
        StepInfo(number: 3, title: "Column Mapping", icon: "slider.horizontal.3"),
        StepInfo(number: 4, title: "SQL Export", icon: "square.and.arrow.up")
    ]

    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(steps, id: \.number) { step in
                    StepHeaderItemView(
                        stepNumber: step.number,
                        title: step.title,
                        icon: step.icon,
                        currentStep: currentStep,
                        isLastStep: step.number == steps.count,
                        onStepSelect: onStepSelect
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Spacer()

            Button(action: onReset) {
                Label("Reset Flow", systemImage: "arrow.counterclockwise")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}

private struct StepHeaderItemView: View {
    let stepNumber: Int
    let title: String
    let icon: String
    let currentStep: Int
    let isLastStep: Bool
    let onStepSelect: (Int) -> Void

    @State private var isHovered: Bool = false

    private var isCurrent: Bool { stepNumber == currentStep }
    private var isCompleted: Bool { stepNumber < currentStep }
    private var isAvailable: Bool { stepNumber <= currentStep }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                if isAvailable {
                    onStepSelect(stepNumber)
                }
            }) {
                HStack(spacing: 8) {
                    ZStack {
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(stepNumber)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(isCurrent ? .white : .secondary)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(
                            isCompleted
                            ? Color.green
                            : (isCurrent ? Color.accentColor : (isHovered && isAvailable ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.18)))
                        )
                    )
                    .scaleEffect(isHovered && isAvailable ? 1.08 : 1.0)

                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 12))
                            .foregroundColor(
                                isCurrent
                                ? .accentColor
                                : (isCompleted ? .primary : (isHovered && isAvailable ? .accentColor : .secondary))
                            )
                            .scaleEffect(isHovered && isAvailable ? 1.08 : 1.0)

                        Text(title)
                            .font(.system(size: 13, weight: isCurrent ? .semibold : .regular))
                            .foregroundColor(
                                isCurrent
                                ? .primary
                                : (isCompleted ? .primary : (isHovered && isAvailable ? .primary : .secondary))
                            )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isCurrent
                            ? Color.accentColor.opacity(0.12)
                            : (isHovered && isAvailable ? Color.accentColor.opacity(0.08) : Color.clear)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHovered = hovering
                }
            }

            if !isLastStep {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.secondary.opacity(0.4))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentStep)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}
