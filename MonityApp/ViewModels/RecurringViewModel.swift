import Foundation

@MainActor
final class RecurringViewModel: ObservableObject {
    @Published var rules: [RecurringRule] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadRules() async {
        isLoading = true
        errorMessage = nil

        do {
            async let rulesTask: RecurringListResponse = APIClient.shared.request(endpoint: "/recurring")
            async let catsTask: CategoryListResponse = APIClient.shared.request(endpoint: "/categories")
            let (rulesResp, catsResp) = try await (rulesTask, catsTask)
            rules = rulesResp.recurringRules
            categories = catsResp.categories
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createRule(
        amount: Double,
        currency: String,
        type: Transaction.TransactionType,
        frequency: RecurringRule.Frequency,
        startDate: Date,
        endDate: Date?,
        categoryId: Int?,
        note: String
    ) async throws {
        var body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "type": type.rawValue,
            "frequency": frequency.rawValue,
            "startDate": DateHelper.toAPIString(startDate),
            "note": note,
        ]
        if let categoryId { body["categoryId"] = categoryId }
        if let endDate { body["endDate"] = DateHelper.toAPIString(endDate) }

        let _: RecurringSingleResponse = try await APIClient.shared.request(
            endpoint: "/recurring",
            method: "POST",
            body: body
        )
        DataChangeNotifier.post()
    }

    func updateRule(
        id: String,
        amount: Double,
        currency: String,
        type: Transaction.TransactionType,
        frequency: RecurringRule.Frequency,
        startDate: Date,
        endDate: Date?,
        categoryId: Int?,
        note: String
    ) async throws {
        var body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "type": type.rawValue,
            "frequency": frequency.rawValue,
            "startDate": DateHelper.toAPIString(startDate),
            "note": note,
        ]
        if let categoryId { body["categoryId"] = categoryId }
        if let endDate {
            body["endDate"] = DateHelper.toAPIString(endDate)
        } else {
            body["endDate"] = NSNull()
        }

        let response: RecurringSingleResponse = try await APIClient.shared.request(
            endpoint: "/recurring/\(id)",
            method: "PUT",
            body: body
        )
        if let idx = rules.firstIndex(where: { $0.id == id }) {
            rules[idx] = response.recurringRule
        }
        DataChangeNotifier.post()
    }

    func toggleActive(_ rule: RecurringRule) async {
        do {
            let body: [String: Any] = ["isActive": !rule.isActive]
            let _: RecurringSingleResponse = try await APIClient.shared.request(
                endpoint: "/recurring/\(rule.id)",
                method: "PUT",
                body: body
            )
            if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
                rules[idx].isActive.toggle()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteRule(_ id: String) async {
        do {
            let _: [String: Bool] = try await APIClient.shared.request(
                endpoint: "/recurring/\(id)",
                method: "DELETE"
            )
            rules.removeAll { $0.id == id }
            DataChangeNotifier.post()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runRuleNow(_ id: String) async -> Bool {
        do {
            struct RunResponse: Codable {
                let success: Bool?
                let generatedDate: String?
            }
            let _: RunResponse = try await APIClient.shared.request(
                endpoint: "/recurring/\(id)/run-now",
                method: "POST"
            )
            DataChangeNotifier.post()
            await loadRules()
            return true
        } catch {
            if let apiError = error as? APIError, apiError.statusCode == 409 {
                errorMessage = NSLocalizedString("recurring_already_generated", comment: "")
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
}
