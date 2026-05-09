import SwiftUI
import Charts

struct TrendLineChart: View {
    let data: [MonthlyData]

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

                Chart {
                    ForEach(data) { item in
                        AreaMark(
                            x: .value("Month", item.label),
                            y: .value("Expense", item.expense)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [BrandColor.expense.opacity(0.3), BrandColor.expense.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
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
                        .symbolSize(35)
                    }
                }
                .frame(height: 180)
            }
        }
    }
}
