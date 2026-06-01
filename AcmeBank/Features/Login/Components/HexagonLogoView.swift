import SwiftUI

// MARK: - Hexagon Shape

/// A regular hexagon `Shape` (flat-top orientation).
private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Six vertices, starting from the top-right vertex (flat-top hex)
        for i in 0..<6 {
            let angle = Angle(degrees: Double(i) * 60.0 - 30.0)
            let x = center.x + radius * cos(CGFloat(angle.radians))
            let y = center.y + radius * sin(CGFloat(angle.radians))
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - HexagonLogoView

/// A navy hexagonal logo view with a white "A" centred inside.
///
/// Used at the top of `LoginView` to present AcmeBank's brand mark.
struct HexagonLogoView: View {

    /// Side-length of the hexagon. Defaults to 80 pt.
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            Hexagon()
                .fill(Color.acmeNavy)
                .frame(width: size, height: size)

            Text("A")
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .accessibilityLabel("AcmeBank logo")
        .accessibilityIdentifier("HexagonLogoView")
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    HexagonLogoView(size: 80)
        .padding()
}
#endif
