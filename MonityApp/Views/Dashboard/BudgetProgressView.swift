import SwiftUI

struct BudgetProgressView: View {
    let budget: BudgetStatus

    var body: some View {
        GlassSurface(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(progressColor.opacity(0.12))
                        Text(budget.category?.icon ?? "💰")
                            .font(.system(size: 16))
                    }
                    .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(budget.category?.localizedName ?? L("uncategorized"))
                            .font(AppFont.label)
                        Text("\(Int(budget.percentage))% \(L("used"))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(Int(budget.percentage))%")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(progressColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(progressColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.12))
                        Capsule()
                            .fill(progressGradient)
                            .frame(width: max(6, geo.size.width * CGFloat(min(budget.percentage / 100, 1.0))))
                    }
                }
                .frame(height: 6)

                HStack {
                    Text(CurrencyHelper.format(budget.spent))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(progressColor)
                    Spacer()
                    Text("\(L("of")) \(CurrencyHelper.format(budget.limitAmount))")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var progressColor: Color {
        switch budget.status {
        case "exceeded": return BrandColor.expense
        case "warning":  return BrandColor.warning
        default:         return BrandColor.income
        }
    }

    private var progressGradient: LinearGradient {
        switch budget.status {
        case "exceeded": return LinearGradient(colors: [BrandColor.expense, BrandColor.expense.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        case "warning":  return LinearGradient(colors: [BrandColor.warning, BrandColor.warning.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        default:         return LinearGradient(colors: [BrandColor.income, BrandColor.income.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        }
    }
}
