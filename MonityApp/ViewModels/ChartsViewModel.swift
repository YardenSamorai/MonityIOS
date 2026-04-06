import Foundation

struct MonthlyData: Identifiable {
    let id = UUID()
    let month: String
    let income: Double
    let expense: Double
    let label: String
}

@MainActor
final class ChartsViewModel: ObservableObject {
    @Published var currentSummary: TransactionSummary?
    @Published var monthlyData: [MonthlyData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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
}
