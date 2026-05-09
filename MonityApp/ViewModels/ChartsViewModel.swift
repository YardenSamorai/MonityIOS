import Foundation

struct MonthlyData: Identifiable, Equatable {
    /// Stable id (API month start `yyyy-MM-dd`).
    var id: String { month }
    let month: String
    let income: Double
    let expense: Double
    let label: String
}

struct ChartInsight: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let detail: String
}

@MainActor
final class ChartsViewModel: ObservableObject {
    @Published var currentSummary: TransactionSummary?
    @Published var monthlyData: [MonthlyData] = []
    @Published var insights: [ChartInsight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var observer: NSObjectProtocol?

    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .dataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.loadCharts()
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func loadCharts() async {
        isLoading = true
        errorMessage = nil

        let (from, to) = DateHelper.currentMonthRange()

        do {
            let summary: TransactionSummary = try await APIClient.shared.request(
                endpoint: "/transactions/summary",
                queryItems: [
                    URLQueryItem(name: "from", value: from),
                    URLQueryItem(name: "to", value: to),
                ]
            )
            currentSummary = summary

            await loadMonthlyTrend()
            rebuildInsights()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadMonthlyTrend() async {
        let calendar = Calendar.current
        let now = Date()
        var data: [MonthlyData] = []

        for i in (0..<6).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!

            let fromStr = DateHelper.toAPIString(start)
            let toStr = DateHelper.toAPIString(end)

            do {
                let summary: TransactionSummary = try await APIClient.shared.request(
                    endpoint: "/transactions/summary",
                    queryItems: [
                        URLQueryItem(name: "from", value: fromStr),
                        URLQueryItem(name: "to", value: toStr),
                    ]
                )

                let formatter = DateFormatter()
                formatter.locale = LanguageManager.shared.locale
                formatter.dateFormat = "MMM"
                let label = formatter.string(from: monthDate)

                data.append(MonthlyData(
                    month: fromStr,
                    income: summary.income,
                    expense: summary.expense,
                    label: label
                ))
            } catch {
                continue
            }
        }

        monthlyData = data
    }

    private func rebuildInsights() {
        let currency = AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
        var items: [ChartInsight] = []

        guard let summary = currentSummary else {
            insights = []
            return
        }

        let income = summary.income
        let expense = summary.expense
        let balance = summary.balance

        if expense > 0 || income > 0 {
            if balance >= 0 {
                items.append(ChartInsight(
                    id: "net_pos",
                    icon: "checkmark.seal.fill",
                    title: L("insight_net_pos_title"),
                    detail: String(format: L("insight_net_pos_body"), CurrencyHelper.format(balance, currency: currency))
                ))
            } else {
                items.append(ChartInsight(
                    id: "net_neg",
                    icon: "exclamationmark.triangle.fill",
                    title: L("insight_net_neg_title"),
                    detail: String(format: L("insight_net_neg_body"), CurrencyHelper.format(abs(balance), currency: currency))
                ))
            }
        }

        if income > 0 {
            let burnPct = min(300, Int(round((expense / income) * 100)))
            if burnPct <= 100 {
                items.append(ChartInsight(
                    id: "burn",
                    icon: "gauge.with.dots.needle.67percent",
                    title: L("insight_burn_title"),
                    detail: String(format: L("insight_burn_body_ok"), burnPct)
                ))
            } else {
                items.append(ChartInsight(
                    id: "burn_over",
                    icon: "flame.fill",
                    title: L("insight_burn_over_title"),
                    detail: String(format: L("insight_burn_over_body"), burnPct)
                ))
            }
        }

        if let top = summary.byCategory.max(by: { $0.totalAmount < $1.totalAmount }), expense > 0.01 {
            let pct = Int(round((top.totalAmount / expense) * 100))
            let name = top.Category?.localizedName ?? L("uncategorized")
            let count = top.count
            items.append(ChartInsight(
                id: "top_cat",
                icon: "star.fill",
                title: L("insight_top_cat_title"),
                detail: String(format: L("insight_top_cat_body"), name, pct, count)
            ))
        }

        if monthlyData.count >= 2, let last = monthlyData.last {
            let prev = monthlyData[monthlyData.count - 2]
            if prev.expense > 0.01 {
                let change = (last.expense - prev.expense) / prev.expense * 100
                let absFmt = String(format: "%.0f", abs(change))
                if change > 2 {
                    items.append(ChartInsight(
                        id: "mom_up",
                        icon: "arrow.up.right.circle.fill",
                        title: L("insight_mom_title"),
                        detail: String(format: L("insight_mom_exp_up_body"), last.label, absFmt)
                    ))
                } else if change < -2 {
                    items.append(ChartInsight(
                        id: "mom_down",
                        icon: "arrow.down.right.circle.fill",
                        title: L("insight_mom_title"),
                        detail: String(format: L("insight_mom_exp_down_body"), last.label, absFmt)
                    ))
                } else {
                    items.append(ChartInsight(
                        id: "mom_flat",
                        icon: "equal.circle.fill",
                        title: L("insight_mom_title"),
                        detail: L("insight_mom_flat_body")
                    ))
                }
            }
        }

        if monthlyData.count >= 3, let last = monthlyData.last {
            let avg = monthlyData.map(\.expense).reduce(0, +) / Double(monthlyData.count)
            if avg > 0.01 {
                let diffPct = (last.expense - avg) / avg * 100
                let ab = Int(round(abs(diffPct)))
                if diffPct > 5 {
                    items.append(ChartInsight(
                        id: "vs_avg_high",
                        icon: "chart.line.uptrend.xyaxis",
                        title: L("insight_vs_avg_title"),
                        detail: String(format: L("insight_vs_avg_above_body"), last.label, ab)
                    ))
                } else if diffPct < -5 {
                    items.append(ChartInsight(
                        id: "vs_avg_low",
                        icon: "leaf.fill",
                        title: L("insight_vs_avg_title"),
                        detail: String(format: L("insight_vs_avg_below_body"), last.label, ab)
                    ))
                }
            }
        }

        if monthlyData.count >= 6 {
            let firstHalf = monthlyData.prefix(3).map(\.expense).reduce(0, +) / 3
            let secondHalf = monthlyData.suffix(3).map(\.expense).reduce(0, +) / 3
            if firstHalf > 0.01 {
                let trendPct = (secondHalf - firstHalf) / firstHalf * 100
                if trendPct > 8 {
                    items.append(ChartInsight(
                        id: "long_up",
                        icon: "waveform.path",
                        title: L("insight_long_trend_title"),
                        detail: L("insight_long_trend_up_body")
                    ))
                } else if trendPct < -8 {
                    items.append(ChartInsight(
                        id: "long_down",
                        icon: "waveform.path",
                        title: L("insight_long_trend_title"),
                        detail: L("insight_long_trend_down_body")
                    ))
                }
            }
        }

        if let peak = monthlyData.max(by: { $0.expense < $1.expense }), monthlyData.count >= 2, peak.expense > 0 {
            items.append(ChartInsight(
                id: "peak",
                icon: "crown.fill",
                title: L("insight_peak_month_title"),
                detail: String(format: L("insight_peak_month_body"), peak.label, CurrencyHelper.format(peak.expense, currency: currency))
            ))
        }

        // Cap to avoid overwhelming UI
        insights = Array(items.prefix(8))
    }
}
