import SwiftUI
import Charts

struct MonthlyBarChart: View {
    let data: [MonthlyData]
    @State private var barsRevealed = false

    var body: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    GradientIcon(systemName: "chart.bar.fill", gradient: AppTheme.primaryGradient)
                    Text("monthly_comparison")
                        .font(.headline)
                }

                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Month", item.label),
                            y: .value("Amount", barsRevealed ? item.income : 0)
                        )
                        .foregroundStyle(AppTheme.income.gradient)
                        .cornerRadius(6)
                        .position(by: .value("Type", L("income")))

                        BarMark(
                            x: .value("Month", item.label),
                            y: .value("Amount", barsRevealed ? item.expense : 0)
                        )
                        .foregroundStyle(AppTheme.expense.gradient)
                        .cornerRadius(6)
                        .position(by: .value("Type", L("expenses")))
                    }
                }
                .frame(height: 200)
                .chartForegroundStyleScale([
                    L("income"): AppTheme.income,
                    L("expenses"): AppTheme.expense,
                ])
                .onAppear {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                        barsRevealed = true
                    }
                }

                HStack(spacing: 20) {
                    legendItem(color: AppTheme.income, label: "income")
                        .bounceIn(delay: 0.6)
                    legendItem(color: AppTheme.expense, label: "expenses")
                        .bounceIn(delay: 0.7)
                }
            }
            .padding(20)
        }
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}
