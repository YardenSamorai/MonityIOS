import Foundation

struct User: Codable {
    let id: String
    let email: String
    var name: String
    var preferredCurrency: String
    var locale: String
    var onboardingCompleted: Bool
}

struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct UserResponse: Codable {
    let user: User
}
