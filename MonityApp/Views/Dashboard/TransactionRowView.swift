import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction
    @State private var iconAppeared = false

    var body: some View {
        HStack(spacing: 14) {
            Text(transaction.category?.icon ?? "💰")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(categoryColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .scaleEffect(iconAppeared ? 1.0 : 0.5)
                .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1), value: iconAppeared)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.category?.localizedName ?? L("uncategorized"))
                        .font(.subheadline.weight(.semibold))

                    if let count = transaction.installmentCount, let number = transaction.installmentNumber, count > 1 {
                        Text("(\(number)/\(count))")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedAmount)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(transaction.type == .income ? AppTheme.income : .primary)
                    .contentTransition(.numericText())

                Text(DateHelper.display(transaction.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .onAppear { iconAppeared = true }
    }

    private var formattedAmount: String {
        let prefix = transaction.type == .income ? "+" : "-"
        return prefix + CurrencyHelper.format(transaction.amount, currency: transaction.currency)
    }

    private var categoryColor: Color {
        guard let hex = transaction.category?.color else { return AppTheme.accent }
        return Color(hex: hex)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
