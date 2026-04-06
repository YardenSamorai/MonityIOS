import Foundation

@MainActor
final class BudgetViewModel: ObservableObject {
    @Published var budgets: [Budget] = []
    @Published var budgetStatuses: [BudgetStatus] = []
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadBudgets() async {
        isLoading = true
        errorMessage = nil

        do {
            async let statusTask: BudgetStatusResponse = APIClient.shared.request(
                endpoint: "/budgets/status"
            )
            async let categoriesTask: CategoryListResponse = APIClient.shared.request(
                endpoint: "/categories",
                queryItems: [URLQueryItem(name: "type", value: "expense")]
            )

            let (statusResponse, categoriesResponse) = try await (statusTask, categoriesTask)
            budgetStatuses = statusResponse.budgets
            categories = categoriesResponse.categories
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createBudget(limitAmount: Double, period: Budget.BudgetPeriod, categoryId: Int) async throws {
        let body: [String: Any] = [
            "limitAmount": limitAmount,
            "period": period.rawValue,
            "categoryId": categoryId,
        ]
        let _: BudgetSingleResponse = try await APIClient.shared.request(
            endpoint: "/budgets",
            method: "POST",
            body: body
        )
    }

    func deleteBudget(_ id: String) async {
        do {
            let _: [String: Bool] = try await APIClient.shared.request(
                endpoint: "/budgets/\(id)",
                method: "DELETE"
            )
            budgetStatuses.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var categoriesWithoutBudget: [Category] {
        let budgetCategoryIds = Set(budgetStatuses.compactMap { $0.category?.id })
        return categories.filter { !budgetCategoryIds.contains($0.id) }
    }
}
