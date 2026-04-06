import Foundation

@MainActor
final class CreditCardViewModel: ObservableObject {
    @Published var cards: [CreditCard] = []
    @Published var selectedCard: CreditCard?
    @Published var cardTransactions: [Transaction] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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
