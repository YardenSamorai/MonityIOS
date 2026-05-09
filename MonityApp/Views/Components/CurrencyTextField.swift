import SwiftUI

/// Foreground colors for the amount field. Use ``onTintedCard`` on colored gradients; ``onCanvas`` on light/canvas backgrounds.
enum CurrencyTextFieldStyle {
    case onTintedCard
    case onCanvas
}

struct CurrencyTextField: View {
    let title: LocalizedStringKey
    @Binding var value: String
    var currency: String = "ILS"
    var style: CurrencyTextFieldStyle = .onTintedCard
    @FocusState private var isFocused: Bool

    private var symbolColor: Color {
        switch style {
        case .onTintedCard: return Color.white.opacity(0.9)
        case .onCanvas: return Color.primary.opacity(0.9)
        }
    }

    private var amountColor: Color {
        switch style {
        case .onTintedCard: return .white
        case .onCanvas: return .primary
        }
    }

    private var promptColor: Color {
        switch style {
        case .onTintedCard: return Color.white.opacity(0.4)
        case .onCanvas: return Color.secondary.opacity(0.45)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(CurrencyHelper.symbol(for: currency))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(symbolColor)

            TextField("", text: $value, prompt: Text("0").foregroundColor(promptColor))
                .keyboardType(.decimalPad)
                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(amountColor)
                .tint(style == .onCanvas ? AppTheme.accent : .white)
                .multilineTextAlignment(.leading)
                .focused($isFocused)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
    }
}
