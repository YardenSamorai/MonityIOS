import SwiftUI
import Charts

struct TrendLineChart: View {
    let data: [MonthlyData]
    let currency: String

    @State private var selectedMonth: String?

    private func pointOpacity(for label: String) -> Double {
        if selectedMonth == nil { return 1 }
        return selectedMonth == label ? 1 : 0.35
    }

    private func areaOpacity(for label: String) -> Double {
        if selectedMonth == nil { return 1 }
        return selectedMonth == label ? 0.45 : 0.12
    }

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(BrandColor.expense.opacity(0.13))
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(BrandColor.expense)
                    }
                    .frame(width: 32, height: 32)
                    Text("spending_trend").font(AppFont.titleS)
                }

                Text("chart_tap_hint")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)

                Chart {
                    ForEach(data) { item in
                        AreaMark(
                            x: .value("Month", item.label),
                            y: .value("Expense", item.expense)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    BrandColor.expense.opacity(areaOpacity(for: item.label)),
                                    BrandColor.expense.opacity(0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Month", item.label),
                            y: .value("Expense", item.expense)
                        )
                        .foregroundStyle(BrandColor.expense)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Month", item.label),
                            y: .value("Expense", item.expense)
                        )
                        .foregroundStyle(BrandColor.expense)
                        .symbolSize(selectedMonth == item.label ? 140 : 40)
                        .opacity(pointOpacity(for: item.label))
                    }
                }
                .chartXSelection(value: $selectedMonth)
                .frame(height: 180)

                if let sel = selectedMonth, let item = data.first(where: { $0.label == sel }) {
                    ChartTapExplainer(
                        title: String(format: L("chart_trend_selection_title"), sel),
                        message: String(
                            format: L("chart_trend_selection_body"),
                            CurrencyHelper.format(item.expense, currency: currency)
                        )
                    )
                }
            }
        }
    }
}
