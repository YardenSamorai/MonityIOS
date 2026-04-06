import SwiftUI

struct CurrencyTextField: View {
    let title: LocalizedStringKey
    @Binding var value: String
    var currency: String = "ILS"
    @FocusState private var isFocused: Bool
    @State private var symbolScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .center, spacing: 4) {
                Text(CurrencyHelper.symbol(for: currency))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
                    .scaleEffect(symbolScale)

                TextField("0", text: $value)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isFocused ? AppTheme.accent.opacity(0.5) : .clear, lineWidth: 2)
                )
        )
        .scaleEffect(isFocused ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .onChange(of: isFocused) { _, focused in
            if focused {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    symbolScale = 1.2
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.15)) {
                    symbolScale = 1.0
                }
            }
        }
        .onTapGesture { isFocused = true }
    }
}
