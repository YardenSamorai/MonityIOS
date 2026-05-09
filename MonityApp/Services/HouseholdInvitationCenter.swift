import Foundation

@MainActor
final class HouseholdInvitationCenter: ObservableObject {
    @Published private(set) var invitations: [HouseholdInvitation] = []

    func clear() {
        invitations = []
    }

    func refresh() async {
        guard AuthService.shared.isAuthenticated, AuthService.shared.token != nil else {
            invitations = []
            return
        }
        do {
            let response: HouseholdInvitationsResponse = try await APIClient.shared.request(
                endpoint: "/household/invitations"
            )
            invitations = response.invitations
        } catch {
            print("HouseholdInvitationCenter refresh: \(error)")
        }
    }

    func acceptInvitation(_ id: String) async {
        do {
            let _: HouseholdResponse = try await APIClient.shared.request(
                endpoint: "/household/invitations/\(id)/accept",
                method: "POST"
            )
            invitations.removeAll { $0.id == id }
            DataChangeNotifier.post()
        } catch {
            print("acceptInvitation: \(error)")
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
            print("declineInvitation: \(error)")
        }
    }
}
