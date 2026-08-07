import SwiftUI

enum RefTraceTheme {
    static let navy = Color(red: 0.05, green: 0.10, blue: 0.18)
    static let royalBlue = Color(red: 0.04, green: 0.31, blue: 0.78)
    static let gold = Color(red: 0.90, green: 0.66, blue: 0.20)
    static let success = Color(red: 0.10, green: 0.55, blue: 0.32)
    static let warning = Color(red: 0.78, green: 0.18, blue: 0.18)
    static let cardRadius: CGFloat = 8
}

struct RefTracePrimaryActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .opacity(0.86)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .opacity(0.72)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, minHeight: 86)
            .background(RefTraceTheme.royalBlue, in: RoundedRectangle(cornerRadius: RefTraceTheme.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

struct RefTraceCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: RefTraceTheme.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: RefTraceTheme.cardRadius)
                    .stroke(.separator.opacity(0.35), lineWidth: 1)
            )
    }
}
