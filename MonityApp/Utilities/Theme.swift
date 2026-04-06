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

// MARK: - Theme

enum AppTheme {
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "6C63FF"), Color(hex: "4ECDC4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let incomeGradient = LinearGradient(
        colors: [Color(hex: "00B894"), Color(hex: "55EFC4")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let expenseGradient = LinearGradient(
        colors: [Color(hex: "E17055"), Color(hex: "FDCB6E")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardBackground = Color(.secondarySystemBackground)
    static let cardCornerRadius: CGFloat = 20

    static let income = Color(hex: "00B894")
    static let expense = Color(hex: "E17055")
    static let accent = Color(hex: "6C63FF")
}

// MARK: - Cards

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

struct SolidCard<Content: View>: View {
    var cornerRadius: CGFloat = 20
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

struct GradientIcon: View {
    let systemName: String
    let gradient: LinearGradient
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

// MARK: - Animation Helpers

extension View {
    func shimmer(isActive: Bool) -> some View {
        self.redacted(reason: isActive ? .placeholder : [])
    }

    func staggeredAppear(appeared: Bool, index: Int) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08),
                value: appeared
            )
    }

    func cardPressEffect() -> some View {
        self.modifier(CardPressModifier())
    }

    func slideIn(appeared: Bool, from edge: Edge = .bottom, distance: CGFloat = 30, delay: Double = 0) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(
                x: edge == .leading ? (appeared ? 0 : -distance) : (edge == .trailing ? (appeared ? 0 : distance) : 0),
                y: edge == .bottom ? (appeared ? 0 : distance) : (edge == .top ? (appeared ? 0 : -distance) : 0)
            )
            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(delay), value: appeared)
    }

    func countingAnimation(value: Double, duration: Double = 0.8) -> some View {
        self.modifier(CountingModifier(targetValue: value, duration: duration))
    }
}

// MARK: - Press Effect

struct CardPressModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Number Counter

struct CountingModifier: ViewModifier, Animatable {
    var targetValue: Double
    let duration: Double

    var animatableData: Double {
        get { targetValue }
        set { targetValue = newValue }
    }

    func body(content: Content) -> some View {
        content
    }
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

// MARK: - Pulse Effect

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Bounce In

struct BounceIn: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(appeared ? 1.0 : 0.3)
            .opacity(appeared ? 1.0 : 0)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.6).delay(delay),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

extension View {
    func bounceIn(delay: Double = 0) -> some View {
        self.modifier(BounceIn(delay: delay))
    }

    func pulseEffect() -> some View {
        self.modifier(PulseEffect())
    }
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                circleScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                drawProgress = 1.0
            }
        }
    }
}
