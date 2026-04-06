import Foundation

@MainActor
final class CreditCardViewModel: ObservableObject {
    @Published var cards: [CreditCard] = []
    @Published var selectedCard: CreditCard?
    @Published var cardTransactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var historyTransactions: [Transaction] = []
    @Published var historySummary: CreditCardHistorySummary?
    @Published var availableMonths: [String] = []
    @Published var selectedMonth: String = {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        return "\(y)-\(String(format: "%02d", m))"
    }()

    func loadCards() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: CreditCardListResponse = try await APIClient.shared.request(endpoint: "/credit-cards")
            cards = response.creditCards
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadCardDetail(_ cardId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let response: CreditCardDetailResponse = try await APIClient.shared.request(endpoint: "/credit-cards/\(cardId)")
            selectedCard = response.creditCard
            cardTransactions = response.transactions
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createCard(name: String, lastFourDigits: String, billingDay: Int, creditLimit: Double?, color: String) async throws {
        var body: [String: Any] = [
            "name": name,
            "lastFourDigits": lastFourDigits,
            "billingDay": billingDay,
            "color": color,
        ]
        if let limit = creditLimit { body["creditLimit"] = limit }

        let _: CreditCardSingleResponse = try await APIClient.shared.request(
            endpoint: "/credit-cards",
            method: "POST",
            body: body
        )
    }

    func deleteCard(_ id: String) async {
        do {
            let _: [String: Bool] = try await APIClient.shared.request(
                endpoint: "/credit-cards/\(id)",
                method: "DELETE"
            )
            cards.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCardHistory(_ cardId: String, month: String? = nil) async {
        isLoading = true
        errorMessage = nil

        let m = month ?? selectedMonth
        do {
            let response: CreditCardHistoryResponse = try await APIClient.shared.request(
                endpoint: "/credit-cards/\(cardId)/history?month=\(m)"
            )
            historyTransactions = response.transactions
            historySummary = response.summary
            availableMonths = response.availableMonths
            selectedMonth = response.month
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func navigateMonth(_ cardId: String, direction: Int) async {
        let parts = selectedMonth.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        var year = parts[0]
        var month = parts[1] + direction
        if month > 12 { month = 1; year += 1 }
        if month < 1 { month = 12; year -= 1 }
        let newMonth = "\(year)-\(String(format: "%02d", month))"
        await loadCardHistory(cardId, month: newMonth)
    }

    var canGoBack: Bool {
        guard let first = availableMonths.first else { return false }
        return selectedMonth > first
    }

    var canGoForward: Bool {
        guard let last = availableMonths.last else { return false }
        return selectedMonth < last
    }

    var selectedMonthDisplayName: String {
        let parts = selectedMonth.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return selectedMonth }
        let dateComponents = DateComponents(year: parts[0], month: parts[1], day: 1)
        guard let date = Calendar.current.date(from: dateComponents) else { return selectedMonth }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    func billCard(_ id: String) async {
        do {
            let response: CreditCardBillResponse = try await APIClient.shared.request(
                endpoint: "/credit-cards/\(id)/bill",
                method: "POST"
            )
            if let idx = cards.firstIndex(where: { $0.id == id }) {
                cards[idx].currentBalance = 0
            }
            if selectedCard?.id == id {
                selectedCard?.currentBalance = 0
                cardTransactions = []
            }
            _ = response.charged
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
