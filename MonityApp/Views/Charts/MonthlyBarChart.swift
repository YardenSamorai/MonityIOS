import SwiftUI
import Charts

struct MonthlyBarChart: View {
    let data: [MonthlyData]
    let currency: String

    @State private var selectedMonth: String?

    private func opacity(for label: String) -> Double {
        if selectedMonth == nil { return 1 }
        return selectedMonth == label ? 1 : 0.32
    }

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

                Text("chart_tap_hint")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(data) { item in
                        BarMark(
                            x: .value("Month", item.label),
                            y: .value("Amount", item.income)
                        )
                        .foregroundStyle(BrandColor.income.gradient)
                        .cornerRadius(6)
                        .position(by: .value("Type", L("income")))
                        .opacity(opacity(for: item.label))

                        BarMark(
                            x: .value("Month", item.label),
                            y: .value("Amount", item.expense)
                        )
                        .foregroundStyle(BrandColor.expense.gradient)
                        .cornerRadius(6)
                        .position(by: .value("Type", L("expenses")))
                        .opacity(opacity(for: item.label))
                    }
                }
                .chartXSelection(value: $selectedMonth)
                .chartLegend(.hidden)
                .frame(height: 200)
                .chartForegroundStyleScale([
                    L("income"): BrandColor.income,
                    L("expenses"): BrandColor.expense,
                ])

                HStack(spacing: 20) {
                    legendItem(color: BrandColor.income, label: "income")
                    legendItem(color: BrandColor.expense, label: "expenses")
                }

                if let sel = selectedMonth, let item = data.first(where: { $0.label == sel }) {
                    let net = item.income - item.expense
                    ChartTapExplainer(
                        title: String(format: L("chart_bar_selection_title"), sel),
                        message: String(
                            format: L("chart_bar_selection_body"),
                            CurrencyHelper.format(item.income, currency: currency),
                            CurrencyHelper.format(item.expense, currency: currency),
                            CurrencyHelper.format(net, currency: currency)
                        )
                    )
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
