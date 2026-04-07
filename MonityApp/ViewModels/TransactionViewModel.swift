import Foundation

@MainActor
final class TransactionViewModel: ObservableObject {
    @Published var transactions: [Transaction] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var filterType: Transaction.TransactionType?
    @Published var filterCategoryId: Int?
    @Published var totalPages = 1
    @Published var currentPage = 1

    var filteredTransactions: [Transaction] {
        guard !searchText.isEmpty else { return transactions }
        return transactions.filter { t in
            t.note.localizedCaseInsensitiveContains(searchText) ||
            (t.category?.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    func loadTransactions(page: Int = 1) async {
        isLoading = true
        errorMessage = nil

        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "50"),
        ]
        if let type = filterType {
            queryItems.append(URLQueryItem(name: "type", value: type.rawValue))
        }
        if let catId = filterCategoryId {
            queryItems.append(URLQueryItem(name: "categoryId", value: "\(catId)"))
        }

        do {
            let response: TransactionListResponse = try await APIClient.shared.request(
                endpoint: "/transactions",
                queryItems: queryItems
            )
            if page == 1 {
                transactions = response.transactions
            } else {
                transactions.append(contentsOf: response.transactions)
            }
            totalPages = response.pages
            currentPage = response.page
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadCategories() async {
        do {
            let response: CategoryListResponse = try await APIClient.shared.request(
                endpoint: "/categories"
            )
            categories = response.categories
        } catch {
            print("Failed to load categories: \(error)")
        }
    }

    func deleteTransaction(_ id: String) async {
        do {
            let _: [String: Bool] = try await APIClient.shared.request(
                endpoint: "/transactions/\(id)",
                method: "DELETE"
            )
            transactions.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @Published var creditCards: [CreditCard] = []

    func loadCreditCards() async {
        do {
            let response: CreditCardListResponse = try await APIClient.shared.request(endpoint: "/credit-cards")
            creditCards = response.creditCards
        } catch {
            print("Failed to load credit cards: \(error)")
        }
    }

    func createTransaction(
        amount: Double,
        currency: String,
        type: Transaction.TransactionType,
        note: String,
        date: Date,
        categoryId: Int?,
        creditCardId: String? = nil,
        installments: Int = 1
    ) async throws {
        var body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "type": type.rawValue,
            "note": note,
            "date": DateHelper.toAPIString(date),
        ]
        if let categoryId { body["categoryId"] = categoryId }
        if let creditCardId { body["creditCardId"] = creditCardId }
        if installments > 1 { body["installments"] = installments }

        let _: TransactionSingleResponse = try await APIClient.shared.request(
            endpoint: "/transactions",
            method: "POST",
            body: body
        )
    }

    func updateTransaction(
        id: String,
        amount: Double,
        currency: String,
        type: Transaction.TransactionType,
        note: String,
        date: Date,
        categoryId: Int?,
        creditCardId: String? = nil
    ) async throws {
        var body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "type": type.rawValue,
            "note": note,
            "date": DateHelper.toAPIString(date),
        ]
        if let categoryId { body["categoryId"] = categoryId }
        if let creditCardId { body["creditCardId"] = creditCardId }

        let response: TransactionSingleResponse = try await APIClient.shared.request(
            endpoint: "/transactions/\(id)",
            method: "PUT",
            body: body
        )
        if let idx = transactions.firstIndex(where: { $0.id == id }) {
            transactions[idx] = response.transaction
        }
    }
}
