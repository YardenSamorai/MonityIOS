import SwiftUI

struct TransactionRowView: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(categoryColor.opacity(0.13))
                Text(transaction.category?.icon ?? "💰")
                    .font(.system(size: 18))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(transaction.category?.localizedName ?? L("uncategorized"))
                        .font(AppFont.label)
                        .foregroundStyle(.primary)

                    if let count = transaction.installmentCount, let number = transaction.installmentNumber, count > 1 {
                        Text("\(number)/\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(BrandColor.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(BrandColor.accent.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(DateHelper.display(transaction.date))
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedAmount)
                    .font(AppFont.amountSmall)
                    .foregroundStyle(transaction.type == .income ? BrandColor.income : Color.primary)
                    .contentTransition(.numericText())

                if !transaction.note.isEmpty {
                    Text(DateHelper.display(transaction.date))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var formattedAmount: String {
        let prefix = transaction.type == .income ? "+" : "−"
        return prefix + CurrencyHelper.format(transaction.amount, currency: transaction.currency)
    }

    private var categoryColor: Color {
        guard let hex = transaction.category?.color else { return BrandColor.primary }
        return Color(hex: hex)
    }
}
