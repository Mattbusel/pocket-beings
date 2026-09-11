import SwiftUI

/// The look: a desktop from about 2001. Bevelled panels, a blue title bar,
/// cream chrome, a green yard. Light, flat and a little bit silly.
enum UI {
    static let sky = Color(red: 0.62, green: 0.85, blue: 0.98)
    static let chrome = Color(red: 0.93, green: 0.91, blue: 0.85)
    static let chromeDark = Color(red: 0.55, green: 0.53, blue: 0.48)
    static let chromeLight = Color.white
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.14)
    static let barA = Color(red: 0.04, green: 0.14, blue: 0.42)
    static let barB = Color(red: 0.36, green: 0.58, blue: 0.90)
    static let grass = Color(red: 0.49, green: 0.80, blue: 0.42)
    static let grassDark = Color(red: 0.40, green: 0.70, blue: 0.35)
    static let paper = Color(red: 1.0, green: 0.99, blue: 0.95)
    static let coin = Color(red: 0.98, green: 0.76, blue: 0.20)
    static let red = Color(red: 0.85, green: 0.22, blue: 0.20)
    static let link = Color(red: 0.0, green: 0.0, blue: 0.6)

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// A raised or sunken 3D border, two pixels wide, the way every window did it.
struct Bevel: ViewModifier {
    var raised = true
    var fill: Color = UI.chrome

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(
                GeometryReader { geo in
                    let w = geo.size.width, h = geo.size.height
                    let tl = raised ? UI.chromeLight : UI.chromeDark
                    let br = raised ? UI.chromeDark : UI.chromeLight
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: w, y: 0))
                    }
                    .stroke(tl, lineWidth: 3)
                    Path { p in
                        p.move(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: 0, y: h))
                    }
                    .stroke(br, lineWidth: 3)
                }
            )
    }
}

extension View {
    func bevel(raised: Bool = true, fill: Color = UI.chrome) -> some View {
        modifier(Bevel(raised: raised, fill: fill))
    }
}

/// The blue gradient title bar with the three little buttons nobody presses.
struct TitleBar: View {
    var title: String
    var trailing: String = ""

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(UI.font(15, .black))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(UI.font(12, .bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            ForEach(["_", "□", "×"], id: \.self) { g in
                Text(g)
                    .font(UI.font(11, .black))
                    .foregroundStyle(UI.ink)
                    .frame(width: 18, height: 16)
                    .bevel()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(LinearGradient(colors: [UI.barA, UI.barB], startPoint: .leading, endPoint: .trailing))
    }
}

/// A chunky button that visibly presses in.
struct ChunkyButton: ButtonStyle {
    var fill: Color = UI.chrome
    var text: Color = UI.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(UI.font(15, .black))
            .foregroundStyle(text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .bevel(raised: !configuration.isPressed, fill: fill)
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
    }
}

/// A whole window: title bar on top, content in cream chrome.
struct WindowBox<Content: View>: View {
    var title: String
    var trailing: String = ""
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            TitleBar(title: title, trailing: trailing)
            content()
        }
        .bevel()
        .padding(3)
    }
}
