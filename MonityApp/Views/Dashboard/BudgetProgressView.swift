import SwiftUI

struct BudgetProgressView: View {
    let budget: BudgetStatus
    @State private var animatedProgress: CGFloat = 0

    var body: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(budget.category?.icon ?? "💰")
                        .font(.title3)
                    Text(budget.category?.localizedName ?? L("uncategorized"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(budget.percentage))%")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(progressColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(progressColor.opacity(0.12))
                        .clipShape(Capsule())
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))

                        Capsule()
                            .fill(progressGradient)
                            .frame(width: max(6, geo.size.width * animatedProgress))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(CurrencyHelper.format(budget.spent))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyHelper.format(budget.limitAmount))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedProgress = CGFloat(min(budget.percentage / 100, 1.0))
            }
        }
    }

    private var progressColor: Color {
        switch budget.status {
        case "exceeded": return .red
        case "warning": return .orange
        default: return AppTheme.income
        }
    }

    private var progressGradient: LinearGradient {
        switch budget.status {
        case "exceeded": return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        case "warning": return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        default: return AppTheme.incomeGradient
        }
    }
}
