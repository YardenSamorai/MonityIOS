import SwiftUI

struct CurrencyTextField: View {
    let title: LocalizedStringKey
    @Binding var value: String
    var currency: String = "ILS"
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(CurrencyHelper.symbol(for: currency))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            TextField("", text: $value, prompt: Text("0").foregroundColor(.white.opacity(0.4)))
                .keyboardType(.decimalPad)
                .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
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
