import Foundation

struct HouseholdUser: Codable {
    let id: String
    let name: String
    let email: String
}

struct HouseholdMember: Codable, Identifiable {
    let id: String
    let householdId: String
    let userId: String?
    let role: String
    let status: String
    let invitedEmail: String?
    let joinedAt: String?
    let User: HouseholdUser?

    var displayName: String {
        User?.name ?? invitedEmail ?? ""
    }

    var isOwner: Bool { role == "owner" }
    var isActive: Bool { status == "active" }
    var isPending: Bool { status == "pending" }
}

struct Household: Codable, Identifiable {
    let id: String
    var name: String
    let createdBy: String
    var HouseholdMembers: [HouseholdMember]?

    var activeMembers: [HouseholdMember] {
        HouseholdMembers?.filter { $0.isActive } ?? []
    }

    var pendingMembers: [HouseholdMember] {
        HouseholdMembers?.filter { $0.isPending } ?? []
    }

    var partnerName: String? {
        activeMembers.first { $0.userId != createdBy }?.displayName
    }
}

struct HouseholdResponse: Codable {
    let household: Household?
}

struct HouseholdInvitation: Codable, Identifiable {
    let id: String
    let householdId: String
    let householdName: String
    let invitedByName: String
    let invitedByEmail: String
    let status: String
    let createdAt: String?
}

struct HouseholdInvitationsResponse: Codable {
    let invitations: [HouseholdInvitation]
}

struct HouseholdInviteResponse: Codable {
    let invitation: HouseholdMember
}

struct HouseholdMemberSummary: Codable {
    let userId: String
    let name: String
    let income: Double
    let expense: Double
}

struct HouseholdSummary: Codable {
    let income: Double
    let expense: Double
    let balance: Double
    let byMember: [HouseholdMemberSummary]?
}

struct HouseholdTransactionsResponse: Codable {
    let transactions: [Transaction]
    let total: Int
    let page: Int
    let pages: Int
}

struct HouseholdCreditCardsResponse: Codable {
    let creditCards: [CreditCard]
}
