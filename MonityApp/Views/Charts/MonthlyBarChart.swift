import SwiftUI
import Charts

struct MonthlyBarChart: View {
    let data: [MonthlyData]

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(BrandColor.primary.opacity(0.13))
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(BrandColor.primary)
                    }
                    .frame(width: 32, height: 32)
                    Text("monthly_comparison").font(AppFont.titleS)
                }

                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Month", item.label),
                            y: .value("Amount", item.income)
                        )
                        .foregroundStyle(BrandColor.income.gradient)
                        .cornerRadius(6)
                        .position(by: .value("Type", L("income")))

                        BarMark(
                            x: .value("Month", item.label),
                            y: .value("Amount", item.expense)
                        )
                        .foregroundStyle(BrandColor.expense.gradient)
                        .cornerRadius(6)
                        .position(by: .value("Type", L("expenses")))
                    }
                }
                .frame(height: 200)
                .chartForegroundStyleScale([
                    L("income"): BrandColor.income,
                    L("expenses"): BrandColor.expense,
                ])

                HStack(spacing: 20) {
                    legendItem(color: BrandColor.income, label: "income")
                    legendItem(color: BrandColor.expense, label: "expenses")
                }
            }
        }
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
    }
}
