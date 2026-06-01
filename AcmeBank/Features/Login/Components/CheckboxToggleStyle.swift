import SwiftUI

/// A custom `ToggleStyle` that renders a checkbox using SF Symbols.
///
/// - Unchecked: `square` (empty square outline)
/// - Checked:   `checkmark.square.fill` (filled square with checkmark)
///
/// The tappable area is expanded to at minimum 44 × 44 pt to meet
/// Apple's Human Interface Guidelines for touch targets.
struct CheckboxToggleStyle: ToggleStyle {

    // MARK: - Colours

    var checkedColor: Color = .acmeNavy
    var uncheckedColor: Color = Color(white: 0.55)

    // MARK: - ToggleStyle

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn
                      ? "checkmark.square.fill"
                      : "square")
                    .font(.system(size: 22))
                    .foregroundStyle(configuration.isOn ? checkedColor : uncheckedColor)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())

                configuration.label
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Checked") {
    Toggle("Keep me signed in", isOn: .constant(true))
        .toggleStyle(CheckboxToggleStyle())
        .padding()
}

#Preview("Unchecked") {
    Toggle("Keep me signed in", isOn: .constant(false))
        .toggleStyle(CheckboxToggleStyle())
        .padding()
}
#endif
