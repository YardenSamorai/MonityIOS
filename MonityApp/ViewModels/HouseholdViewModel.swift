import Foundation

@MainActor
final class HouseholdViewModel: ObservableObject {
    @Published var household: Household?
    @Published var invitations: [HouseholdInvitation] = []
    @Published var summary: HouseholdSummary?
    @Published var recentTransactions: [Transaction] = []
    @Published var creditCards: [CreditCard] = []

    @Published var isLoading = false
    @Published var isCreating = false
    @Published var isInviting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    var hasHousehold: Bool { household != nil }
    var hasInvitations: Bool { !invitations.isEmpty }

    var partnerMember: HouseholdMember? {
        let myId = AuthService.shared.currentUser?.id
        return household?.activeMembers.first { $0.userId != myId }
    }

    var myMember: HouseholdMember? {
        let myId = AuthService.shared.currentUser?.id
        return household?.activeMembers.first { $0.userId == myId }
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        async let householdTask = loadHousehold()
        async let invitationsTask = checkInvitations()
        let _ = await (householdTask, invitationsTask)

        if hasHousehold {
            async let summaryTask = loadSummary()
            async let transactionsTask = loadTransactions()
            async let cardsTask = loadCreditCards()
            let _ = await (summaryTask, transactionsTask, cardsTask)
        }

        isLoading = false
    }

    func loadHousehold() async {
        do {
            let response: HouseholdResponse = try await APIClient.shared.request(
                endpoint: "/household"
            )
            household = response.household
        } catch {
            print("Load household error: \(error)")
        }
    }

    func createHousehold(name: String) async {
        isCreating = true
        errorMessage = nil
        do {
            let body: [String: Any] = ["name": name]
            let response: HouseholdResponse = try await APIClient.shared.request(
                endpoint: "/household",
                method: "POST",
                body: body
            )
            household = response.household
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }

    func invitePartner(email: String) async {
        isInviting = true
        errorMessage = nil
        successMessage = nil
        do {
            let body: [String: Any] = ["email": email]
            let _: HouseholdInviteResponse = try await APIClient.shared.request(
                endpoint: "/household/invite",
                method: "POST",
                body: body
            )
            successMessage = L("invitation_sent")
            await loadHousehold()
        } catch let error as APIError {
            if case .serverError(_, let msg) = error {
                errorMessage = msg
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isInviting = false
    }

    func checkInvitations() async {
        do {
            let response: HouseholdInvitationsResponse = try await APIClient.shared.request(
                endpoint: "/household/invitations"
            )
            invitations = response.invitations
        } catch {
            print("Check invitations error: \(error)")
        }
    }

    func acceptInvitation(_ id: String) async {
        do {
            let response: HouseholdResponse = try await APIClient.shared.request(
                endpoint: "/household/invitations/\(id)/accept",
                method: "POST"
            )
            household = response.household
            invitations.removeAll { $0.id == id }
            await loadAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineInvitation(_ id: String) async {
        do {
            struct SuccessResponse: Codable { let success: Bool }
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: "/household/invitations/\(id)/decline",
                method: "POST"
            )
            invitations.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func leaveHousehold() async {
        do {
            struct SuccessResponse: Codable { let success: Bool }
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: "/household/leave",
                method: "DELETE"
            )
            household = nil
            summary = nil
            recentTransactions = []
            creditCards = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSummary() async {
        let (from, to) = DateHelper.currentMonthRange()
        do {
            let s: HouseholdSummary = try await APIClient.shared.request(
                endpoint: "/household/summary",
                queryItems: [
                    URLQueryItem(name: "from", value: from),
                    URLQueryItem(name: "to", value: to),
                ]
            )
            summary = s
        } catch {
            print("Household summary error: \(error)")
        }
    }

    private func loadTransactions() async {
        do {
            let response: HouseholdTransactionsResponse = try await APIClient.shared.request(
                endpoint: "/household/transactions",
                queryItems: [URLQueryItem(name: "limit", value: "10")]
            )
            recentTransactions = response.transactions
        } catch {
            print("Household transactions error: \(error)")
        }
    }

    private func loadCreditCards() async {
        do {
            let response: HouseholdCreditCardsResponse = try await APIClient.shared.request(
                endpoint: "/household/credit-cards"
            )
            creditCards = response.creditCards.filter { $0.isActive }
        } catch {
            print("Household cards error: \(error)")
        }
    }
}
