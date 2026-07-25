import SwiftUI

enum AppTheme {
    enum Colors {
        static let background = Color(hex: "000000")
        static let surface = Color(hex: "141414")
        static let surfaceElevated = Color(hex: "1E1E1E")
        static let accent = Color(hex: "FF6B00")
        static let accentGradientEnd = Color(hex: "FF4500")
        static let accentSecondary = Color(hex: "E74C3C")
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: "9A9AA5")
        static let divider = Color(hex: "2A2A2A")
        static let success = Color(hex: "2ED573")
        static let warning = Color(hex: "FFA502")

        static let accentGradient = LinearGradient(
            colors: [accent, accentGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let posterGradients: [[Color]] = [
            [Color(hex: "FF6B00"), Color(hex: "B33939")],
            [Color(hex: "E17055"), Color(hex: "833471")],
            [Color(hex: "00B894"), Color(hex: "0B8457")],
            [Color(hex: "0984E3"), Color(hex: "1E3799")],
            [Color(hex: "FDCB6E"), Color(hex: "E58E26")],
            [Color(hex: "636E72"), Color(hex: "2D3436")]
        ]

        static func posterGradient(for seed: Int) -> [Color] {
            posterGradients[abs(seed) % posterGradients.count]
        }

        /// Единый порог цвета рейтинга, используется везде, где показывается оценка фильма.
        static func ratingColor(for rating: Double) -> Color {
            switch rating {
            case 7...: success
            case 5..<7: warning
            default: accentSecondary
            }
        }
    }

    enum Typography {
        static let largeTitle = Font.system(size: 28, weight: .black)
        static let brandTitle = Font.system(size: 22, weight: .black)
        static let title = Font.system(size: 20, weight: .semibold)
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 15, weight: .regular)
        static let subheadline = Font.system(size: 13, weight: .medium)
        static let caption = Font.system(size: 12, weight: .medium)
    }

    enum Layout {
        static let cornerRadius: CGFloat = 16
        static let cornerRadiusSmall: CGFloat = 10
        static let spacing: CGFloat = 12
        static let padding: CGFloat = 16
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255
        let b = Double(rgbValue & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
