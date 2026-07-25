import SwiftUI

/// Основной стиль CTA-кнопок в духе Кинопоиска — оранжевый с лёгким градиентом,
/// вместо плоской заливки system tint.
struct PrimaryGradientButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppTheme.Typography.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(AppTheme.Colors.accentGradient)
            .clipShape(Capsule())
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.85 : 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension ButtonStyle where Self == PrimaryGradientButtonStyle {
    static var primaryGradient: PrimaryGradientButtonStyle { PrimaryGradientButtonStyle() }
}
