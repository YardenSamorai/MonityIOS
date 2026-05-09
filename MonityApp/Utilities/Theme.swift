import SwiftUI

// MARK: - Appearance Manager

@MainActor
final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @AppStorage("app_appearance") var appearanceMode: AppearanceMode = .system {
        didSet { applyAppearance() }
    }

    enum AppearanceMode: String, CaseIterable {
        case light, dark, system

        var displayName: String {
            switch self {
            case .light: return L("appearance_light")
            case .dark: return L("appearance_dark")
            case .system: return L("appearance_system")
            }
        }

        var icon: String {
            switch self {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .system: return "circle.lefthalf.filled"
            }
        }
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    private init() {
        applyAppearance()
    }

    func applyAppearance() {
        objectWillChange.send()
    }
}

// MARK: - Brand Colors

/// Monity brand identity. Trust + sophistication + warmth.
/// Primary: Deep teal (financial, trustworthy)
/// Accent: Warm gold/coral (premium, growth)
/// Income: Soft mint (gentle success)
/// Expense: Warm coral (firm but not aggressive)
enum BrandColor {
    static let primary    = Color(light: "0A6B5F", dark: "14A18C")
    static let primaryDeep = Color(light: "044238", dark: "0E5F50")
    static let primarySoft = Color(light: "E6F7F4", dark: "0F2620")

    static let accent      = Color(light: "C8924A", dark: "E5B070")
    static let accentSoft  = Color(light: "FCF5EA", dark: "2A1F0F")

    static let income      = Color(light: "1A8F73", dark: "3FBF9A")
    static let incomeSoft  = Color(light: "E5F5F0", dark: "0E2620")

    static let expense     = Color(light: "C84A4A", dark: "E27070")
    static let expenseSoft = Color(light: "FCEAEA", dark: "2A0F0F")

    static let warning     = Color(light: "C8854A", dark: "E5A370")
    static let info        = Color(light: "4A88C8", dark: "70A8E5")
}

// MARK: - Surface (Liquid Glass) Colors

enum Surface {
    /// App background base - subtle and warm
    static let canvas = Color("CanvasBackground", bundle: nil, fallback: Color(light: "F7F4EE", dark: "0B0F12"))

    /// Card backgrounds with very slight tint
    static let card = Color(light: "FFFFFF", dark: "1A1F23")

    /// Elevated card (above another card)
    static let cardElevated = Color(light: "FFFFFF", dark: "242A2F")

    /// Subtle highlight for hover/active state
    static let highlight = Color(light: "F2EEE6", dark: "2D343A")

    /// Subtle separator
    static let separator = Color(light: "E5E0D6", dark: "2D343A")

    /// Glass tint overlay
    static let glassTint = Color(light: "FFFFFF", dark: "FFFFFF")
}

extension Color {
    init(light: String, dark: String) {
        self = Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }

    init(_ name: String, bundle: Bundle?, fallback: Color) {
        if let _ = UIColor(named: name, in: bundle, compatibleWith: nil) {
            self = Color(name, bundle: bundle)
        } else {
            self = fallback
        }
    }
}

extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Spacing & Sizing

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 28
    static let xxxl: CGFloat = 40

    static let cardPadding: CGFloat = 18
    static let screenHorizontal: CGFloat = 20
}

enum Radius {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
    static let xl: CGFloat = 22
    static let xxl: CGFloat = 28
    static let pill: CGFloat = 999
}

// MARK: - Typography

enum AppFont {
    // Display - hero numbers, large amounts
    static let displayLarge = Font.system(size: 44, weight: .bold, design: .rounded).monospacedDigit()
    static let display      = Font.system(size: 36, weight: .bold, design: .rounded).monospacedDigit()
    static let displaySmall = Font.system(size: 28, weight: .bold, design: .rounded).monospacedDigit()

    // Titles
    static let titleXL  = Font.system(size: 30, weight: .bold, design: .rounded)
    static let titleL   = Font.system(size: 24, weight: .bold, design: .rounded)
    static let titleM   = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let titleS   = Font.system(size: 17, weight: .semibold, design: .default)

    // Body
    static let bodyL    = Font.system(size: 17, weight: .regular)
    static let body     = Font.system(size: 15, weight: .regular)
    static let bodyM    = Font.system(size: 15, weight: .medium)
    static let bodyS    = Font.system(size: 14, weight: .regular)

    // Captions / Labels
    static let label    = Font.system(size: 13, weight: .semibold)
    static let caption  = Font.system(size: 12, weight: .medium)
    static let captionS = Font.system(size: 11, weight: .semibold)

    // Numerals (always monospaced for numbers)
    static let amountDisplay = Font.system(size: 38, weight: .bold, design: .rounded).monospacedDigit()
    static let amountLarge   = Font.system(size: 24, weight: .bold, design: .rounded).monospacedDigit()
    static let amount        = Font.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()
    static let amountSmall   = Font.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit()
}

// MARK: - Shadows

enum Shadow {
    static func soft(_ color: Color = .black) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    static func medium(_ color: Color = .black) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.08), radius: 16, x: 0, y: 6)
    }

    static func large(_ color: Color = .black) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.12), radius: 24, x: 0, y: 12)
    }

    static func glow(_ color: Color, intensity: Double = 0.4) -> some ViewModifier {
        ShadowModifier(color: color.opacity(intensity), radius: 20, x: 0, y: 8)
    }
}

struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: color, radius: radius, x: x, y: y)
    }
}

extension View {
    func softShadow() -> some View { modifier(Shadow.soft()) }
    func mediumShadow() -> some View { modifier(Shadow.medium()) }
    func largeShadow() -> some View { modifier(Shadow.large()) }
    func glowShadow(_ color: Color, intensity: Double = 0.4) -> some View { modifier(Shadow.glow(color, intensity: intensity)) }
}

// MARK: - Animation Tokens

enum Motion {
    static let snappy: Animation = .spring(response: 0.3, dampingFraction: 0.85)
    static let smooth: Animation = .spring(response: 0.45, dampingFraction: 0.85)
    static let bouncy: Animation = .spring(response: 0.5, dampingFraction: 0.65)
    static let soft: Animation   = .spring(response: 0.6, dampingFraction: 0.9)
    static let easeQuick: Animation = .easeOut(duration: 0.2)
    static let easeStandard: Animation = .easeOut(duration: 0.3)
}

// MARK: - Legacy AppTheme (compatibility shim)
// Kept so old code referencing AppTheme continues compiling while we migrate.

enum AppTheme {
    static let primaryGradient = LinearGradient(
        colors: [BrandColor.primary, BrandColor.primaryDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let incomeGradient = LinearGradient(
        colors: [BrandColor.income, BrandColor.income.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let expenseGradient = LinearGradient(
        colors: [BrandColor.expense, BrandColor.expense.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Surface.card
    static let cardCornerRadius: CGFloat = Radius.lg

    static let income = BrandColor.income
    static let expense = BrandColor.expense
    static let accent = BrandColor.primary
}

// MARK: - Animation Helpers (compatibility)

extension View {
    func shimmer(isActive: Bool) -> some View {
        self.redacted(reason: isActive ? .placeholder : [])
    }

    func staggeredAppear(appeared: Bool, index: Int) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.05),
                value: appeared
            )
    }

    func cardPressEffect() -> some View {
        self.modifier(CardPressModifier())
    }

    func slideIn(appeared: Bool, from edge: Edge = .bottom, distance: CGFloat = 24, delay: Double = 0) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(
                x: edge == .leading ? (appeared ? 0 : -distance) : (edge == .trailing ? (appeared ? 0 : distance) : 0),
                y: edge == .bottom ? (appeared ? 0 : distance) : (edge == .top ? (appeared ? 0 : -distance) : 0)
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(delay), value: appeared)
    }

    func countingAnimation(value: Double, duration: Double = 0.8) -> some View {
        self.modifier(CountingModifier(targetValue: value, duration: duration))
    }
}

struct CardPressModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(Motion.snappy, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

struct CountingModifier: ViewModifier, Animatable {
    var targetValue: Double
    let duration: Double

    var animatableData: Double {
        get { targetValue }
        set { targetValue = newValue }
    }

    func body(content: Content) -> some View { content }
}

// MARK: - Animated Counter Text

struct AnimatedCounterText: View {
    let value: Double
    let formatter: (Double) -> String
    let font: Font
    let color: Color

    @State private var displayedValue: Double = 0

    var body: some View {
        Text(formatter(displayedValue))
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: displayedValue))
            .onChange(of: value) { _, newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    displayedValue = newValue
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                    displayedValue = value
                }
            }
    }
}

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

struct BounceIn: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1.0 : 0.85)
            .opacity(appeared ? 1.0 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: appeared)
            .onAppear { appeared = true }
    }
}

extension View {
    func bounceIn(delay: Double = 0) -> some View { modifier(BounceIn(delay: delay)) }
    func pulseEffect() -> some View { modifier(PulseEffect()) }
}

// MARK: - Success Checkmark

struct SuccessCheckmark: View {
    @State private var drawProgress: CGFloat = 0
    @State private var circleScale: CGFloat = 0
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .scaleEffect(circleScale)

            Circle()
                .trim(from: 0, to: drawProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(color)
                .scaleEffect(drawProgress >= 1.0 ? 1.0 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.3), value: drawProgress)
        }
        .frame(width: 56, height: 56)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { circleScale = 1.0 }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { drawProgress = 1.0 }
        }
    }
}
