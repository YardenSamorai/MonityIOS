import SwiftUI
import Charts

struct TrendLineChart: View {
    let data: [MonthlyData]
    @State private var lineRevealed = false

    var body: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    GradientIcon(systemName: "waveform.path.ecg", gradient: AppTheme.expenseGradient)
                    Text("spending_trend")
                        .font(.headline)
                }

                Chart {
                    ForEach(data) { item in
                        AreaMark(
                            x: .value("Month", item.label),
                            y: .value("Expense", lineRevealed ? item.expense : 0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.expense.opacity(0.3), AppTheme.expense.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Month", item.label),
                            y: .value("Expense", lineRevealed ? item.expense : 0)
                        )
                        .foregroundStyle(AppTheme.expense)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)

                        if lineRevealed {
                            PointMark(
                                x: .value("Month", item.label),
                                y: .value("Expense", item.expense)
                            )
                            .foregroundStyle(AppTheme.expense)
                            .symbolSize(40)
                        }
                    }
                }
                .frame(height: 180)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                        lineRevealed = true
                    }
                }
            }
            .padding(20)
        }
    }
}
