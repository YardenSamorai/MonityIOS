import SwiftUI

// MARK: - Liquid Glass Surfaces

/// A premium glass card with subtle border, blur, and elevation.
/// This is the primary surface used for content blocks across the app.
enum GlassElevation {
    case flat, regular, raised
}

struct GlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = Radius.lg
    var padding: CGFloat = Spacing.cardPadding
    var tint: Color? = nil
    var elevation: GlassElevation = .regular
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Surface.card)

                    if let tint {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.04))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Surface.separator.opacity(0.5), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .modifier(ElevationShadow(level: elevation))
    }
}

private struct ElevationShadow: ViewModifier {
    let level: GlassElevation

    func body(content: Content) -> some View {
        switch level {
        case .flat:
            content
        case .regular:
            content.shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        case .raised:
            content
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }
}

/// A featured glass card with a vibrant gradient background.
/// Used for hero / featured / highlighted content.
struct FeatureGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Radius.xxl
    var padding: CGFloat = 24
    let gradient: LinearGradient
    var glowColor: Color?
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(gradient)

                    // Glass highlight on top
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.plusLighter)

                    // Subtle highlight
                    GeometryReader { geo in
                        Ellipse()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.6)
                            .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.5)
                            .blur(radius: 30)
                            .blendMode(.plusLighter)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: (glowColor ?? .black).opacity(0.25), radius: 20, x: 0, y: 12)
            .shadow(color: (glowColor ?? .black).opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Section Headers

struct SectionHeader: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFont.titleM)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing
        }
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: LocalizedStringKey
    var icon: String? = nil
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white).scaleEffect(0.95)
                } else {
                    HStack(spacing: 8) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.subheadline.weight(.bold))
                        }
                        Text(title)
                            .font(.headline.weight(.bold))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [BrandColor.primaryDeep, BrandColor.primary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .opacity(isDisabled ? 0.5 : 1)
            .shadow(color: BrandColor.primary.opacity(isDisabled ? 0 : 0.3), radius: 14, y: 6)
        }
        .disabled(isLoading || isDisabled)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringKey
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(BrandColor.primary)
            .background(BrandColor.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
    }
}

struct GlassIconButton: View {
    let icon: String
    var size: CGFloat = 38
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        Circle().fill(.ultraThinMaterial)
                        Circle().fill(Surface.card.opacity(0.55))
                    }
                )
                .overlay(
                    Circle().strokeBorder(Surface.separator.opacity(0.45), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Chips & Badges

struct StatusBadge: View {
    let text: LocalizedStringKey
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.18), lineWidth: 0.5))
    }
}

struct CategoryChip: View {
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text(icon).font(.caption)
            Text(label).font(AppFont.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Form Fields

struct FormField<Trailing: View>: View {
    let label: LocalizedStringKey
    let icon: String
    @Binding var text: String
    var placeholder: LocalizedStringKey = ""
    var contentType: UITextContentType? = nil
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false
    @ViewBuilder var trailing: () -> Trailing

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.label)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(focused ? BrandColor.primary : Color.secondary)
                    .frame(width: 22)

                if isSecure {
                    SecureField("", text: $text, prompt: Text(placeholder))
                        .focused($focused)
                        .font(AppFont.body)
                } else {
                    TextField("", text: $text, prompt: Text(placeholder))
                        .focused($focused)
                        .textContentType(contentType)
                        .keyboardType(keyboard)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(AppFont.body)
                }

                trailing()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Surface.card)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .strokeBorder(focused ? BrandColor.primary.opacity(0.6) : Surface.separator.opacity(0.6),
                                  lineWidth: focused ? 1.5 : 0.5)
            )
            .animation(Motion.easeQuick, value: focused)
        }
    }
}

extension FormField where Trailing == EmptyView {
    init(label: LocalizedStringKey, icon: String, text: Binding<String>,
         placeholder: LocalizedStringKey = "",
         contentType: UITextContentType? = nil, keyboard: UIKeyboardType = .default,
         isSecure: Bool = false) {
        self.label = label
        self.icon = icon
        self._text = text
        self.placeholder = placeholder
        self.contentType = contentType
        self.keyboard = keyboard
        self.isSecure = isSecure
        self.trailing = { EmptyView() }
    }
}

// MARK: - Stat Pill (small KPI)

struct StatPill: View {
    let icon: String
    let label: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(color.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(AppFont.amountSmall)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Empty State

struct EmptyStateCard: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(BrandColor.primary.opacity(0.08))
                    .frame(width: 78, height: 78)
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(BrandColor.primary)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(AppFont.titleS)
                Text(message)
                    .font(AppFont.bodyS)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BrandColor.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(BrandColor.primarySoft)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(28)
    }
}

// MARK: - Page Background

/// Soft adaptive canvas for the app's screens. Provides a subtle warm tint
/// that lets glass surfaces stand out gracefully.
struct CanvasBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark
                ? Color(hex: "#0B0F12")
                : Color(hex: "#F7F4EE"))
                .ignoresSafeArea()

            // Subtle ambient gradient
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(hex: "#0F1418"), Color(hex: "#0A0D10")]
                    : [Color(hex: "#FBFAF6"), Color(hex: "#F4F0E6")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Floating Toolbar Button (replaces the standard nav bar plus button)

struct FloatingPlusButton: View {
    let action: () -> Void
    @State private var rotation: Double = 0

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { rotation += 90 }
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [BrandColor.primary, BrandColor.primaryDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: BrandColor.primary.opacity(0.35), radius: 10, y: 4)
                .rotationEffect(.degrees(rotation))
        }
    }
}

// MARK: - Liquid Glass List Row

struct GlassRow<Leading: View, Content: View, Trailing: View>: View {
    @ViewBuilder var leading: Leading
    @ViewBuilder var content: Content
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            leading
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Surface.card)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Surface.separator.opacity(0.45), lineWidth: 0.5)
        )
    }
}

// MARK: - Money Text (with sign + symbol)

struct MoneyText: View {
    let amount: Double
    let currency: String?
    var font: Font = AppFont.amount
    var color: Color? = nil
    var showSign: Bool = false

    var body: some View {
        let abs = Swift.abs(amount)
        let signPrefix: String = {
            if !showSign { return "" }
            return amount >= 0 ? "+" : "−"
        }()

        return Text(signPrefix + CurrencyHelper.format(abs, currency: currency))
            .font(font)
            .foregroundStyle(color ?? Color.primary)
    }
}

// MARK: - Backwards-compat shims

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = Radius.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassSurface(cornerRadius: cornerRadius, padding: 0) { content() }
    }
}

struct SolidCard<Content: View>: View {
    var cornerRadius: CGFloat = Radius.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        GlassSurface(cornerRadius: cornerRadius, padding: 0) { content() }
    }
}

struct GradientIcon: View {
    let systemName: String
    let gradient: LinearGradient
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(gradient)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
