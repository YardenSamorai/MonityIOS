import Foundation

@MainActor
final class GoalsViewModel: ObservableObject {
    @Published var goals: [SavingsGoal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let r: GoalsListResponse = try await APIClient.shared.request(endpoint: "/goals")
            goals = r.goals
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(name: String, target: Double, current: Double, currency: String, targetDate: String?) async {
        errorMessage = nil
        var body: [String: Any] = [
            "name": name,
            "targetAmount": target,
            "currentAmount": current,
            "currency": currency,
        ]
        if let targetDate { body["targetDate"] = targetDate }
        do {
            let r: GoalSingleResponse = try await APIClient.shared.request(
                endpoint: "/goals",
                method: "POST",
                body: body
            )
            goals.append(r.goal)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func update(_ goal: SavingsGoal, name: String, target: Double, current: Double, targetDate: String?) async {
        errorMessage = nil
        var body: [String: Any] = [
            "name": name,
            "targetAmount": target,
            "currentAmount": current,
        ]
        body["currency"] = goal.currency
        if let targetDate { body["targetDate"] = targetDate }
        do {
            let r: GoalSingleResponse = try await APIClient.shared.request(
                endpoint: "/goals/\(goal.id)",
                method: "PUT",
                body: body
            )
            if let i = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[i] = r.goal
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ id: String) async {
        struct OK: Codable { let success: Bool }
        do {
            let _: OK = try await APIClient.shared.request(
                endpoint: "/goals/\(id)",
                method: "DELETE"
            )
            goals.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
final class CategoryRulesViewModel: ObservableObject {
    @Published var rules: [CategoryRuleModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let r: CategoryRulesListResponse = try await APIClient.shared.request(endpoint: "/category-rules")
            rules = r.rules
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(pattern: String, categoryId: Int, priority: Int) async {
        errorMessage = nil
        let body: [String: Any] = [
            "pattern": pattern,
            "categoryId": categoryId,
            "priority": priority,
        ]
        do {
            let r: CategoryRuleSingleResponse = try await APIClient.shared.request(
                endpoint: "/category-rules",
                method: "POST",
                body: body
            )
            rules.append(r.rule)
            rules.sort { $0.priority > $1.priority }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ id: String) async {
        struct OK: Codable { let success: Bool }
        do {
            let _: OK = try await APIClient.shared.request(
                endpoint: "/category-rules/\(id)",
                method: "DELETE"
            )
            rules.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
