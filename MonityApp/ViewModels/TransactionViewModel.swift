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
    /// API `YYYY-MM-DD` or nil
    @Published var filterDateFrom: String?
    @Published var filterDateTo: String?
    @Published var totalPages = 1
    @Published var currentPage = 1
    /// Checking (bank) running balance after each transaction id; from `/transactions/bank-running-balances`.
    @Published private(set) var bankBalanceByTransactionId: [String: Double] = [:]

    private var reloadTask: Task<Void, Never>?

    var filteredTransactions: [Transaction] { transactions }

    func scheduleDebouncedReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await loadTransactions(page: 1)
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
        if let from = filterDateFrom, !from.isEmpty {
            queryItems.append(URLQueryItem(name: "from", value: from))
        }
        if let to = filterDateTo, !to.isEmpty {
            queryItems.append(URLQueryItem(name: "to", value: to))
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !q.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: q))
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
            await loadBankRunningBalances()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadBankRunningBalances() async {
        do {
            let response: BankRunningBalancesResponse = try await APIClient.shared.request(
                endpoint: "/transactions/bank-running-balances"
            )
            bankBalanceByTransactionId = response.balances
        } catch let error as APIError {
            if error.statusCode == 404 {
                // Older deployed API without this route — compute on device.
                await computeBankRunningBalancesLocally()
            } else {
                print("Bank running balances error: \(error)")
            }
        } catch {
            print("Bank running balances error: \(error)")
        }
    }

    /// Same rules as backend: bank-only rows, exclude billing double-count lines. Used when `/bank-running-balances` is missing (e.g. not deployed yet).
    private func computeBankRunningBalancesLocally() async {
        var collected: [Transaction] = []
        var page = 1
        let limit = 200

        while page <= 50 {
            do {
                let r: TransactionListResponse = try await APIClient.shared.request(
                    endpoint: "/transactions",
                    queryItems: [
                        URLQueryItem(name: "page", value: "\(page)"),
                        URLQueryItem(name: "limit", value: "\(limit)"),
                    ]
                )
                collected.append(contentsOf: r.transactions)
                if page >= r.pages || r.transactions.isEmpty { break }
                page += 1
            } catch {
                print("Local bank running balances: fetch error \(error)")
                return
            }
        }

        let bankLedger = collected.filter { tx in
            tx.creditCardId == nil && !(tx.isBillingCharge == true)
        }
        let sorted = bankLedger.sorted { a, b in
            if a.date != b.date { return a.date < b.date }
            let ac = a.createdAt ?? ""
            let bc = b.createdAt ?? ""
            if ac != bc { return ac < bc }
            return a.id < b.id
        }

        var running = 0.0
        var map: [String: Double] = [:]
        for t in sorted {
            let delta = t.type == .income ? t.amount : -t.amount
            running += delta
            map[t.id] = running
        }
        bankBalanceByTransactionId = map
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
            struct DelOK: Codable { let success: Bool }
            let _: DelOK = try await APIClient.shared.request(
                endpoint: "/transactions/\(id)",
                method: "DELETE"
            )
            transactions.removeAll { $0.id == id }
            DataChangeNotifier.post()
            await loadBankRunningBalances()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTrashTransactions() async throws -> [Transaction] {
        let r: TrashListResponse = try await APIClient.shared.request(endpoint: "/transactions/trash")
        return r.transactions
    }

    func restoreTransaction(_ id: String) async {
        do {
            let r: TransactionSingleResponse = try await APIClient.shared.request(
                endpoint: "/transactions/\(id)/restore",
                method: "POST"
            )
            if r.transaction != nil {
                await loadTransactions(page: 1)
                DataChangeNotifier.post()
                await loadBankRunningBalances()
            }
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
        DataChangeNotifier.post()
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
        DataChangeNotifier.post()
    }
}
