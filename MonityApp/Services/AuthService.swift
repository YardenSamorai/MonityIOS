import Foundation

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = true

    private let keychain = KeychainHelper.shared

    var token: String? {
        keychain.read(for: Constants.keychainTokenKey)
    }

    private init() {
        Task { await checkAuth() }
    }

    func checkAuth() async {
        guard let token = self.token, !token.isEmpty else {
            isAuthenticated = false
            isLoading = false
            return
        }

        do {
            let response: UserResponse = try await APIClient.shared.request(
                endpoint: "/auth/me",
                method: "GET"
            )
            currentUser = response.user
            isAuthenticated = true
        } catch {
            logout()
        }
        isLoading = false
    }

    func login(email: String, password: String) async throws {
        let body: [String: Any] = ["email": email, "password": password]
        let response: AuthResponse = try await APIClient.shared.request(
            endpoint: "/auth/login",
            method: "POST",
            body: body
        )
        keychain.save(response.token, for: Constants.keychainTokenKey)
        keychain.save(email, for: "monity_biometric_email")
        keychain.save(password, for: "monity_biometric_password")
        UserDefaults.standard.set(response.user.name, forKey: "last_login_name")
        currentUser = response.user
        isAuthenticated = true
    }

    func register(name: String, email: String, password: String) async throws {
        let body: [String: Any] = [
            "name": name,
            "email": email,
            "password": password,
            "preferredCurrency": "ILS",
            "locale": Locale.current.language.languageCode?.identifier ?? "he",
        ]
        let response: AuthResponse = try await APIClient.shared.request(
            endpoint: "/auth/register",
            method: "POST",
            body: body
        )
        keychain.save(response.token, for: Constants.keychainTokenKey)
        currentUser = response.user
        isAuthenticated = true
    }

    func updateProfile(name: String? = nil, currency: String? = nil, locale: String? = nil) async throws {
        var body: [String: Any] = [:]
        if let name { body["name"] = name }
        if let currency { body["preferredCurrency"] = currency }
        if let locale { body["locale"] = locale }

        let response: UserResponse = try await APIClient.shared.request(
            endpoint: "/auth/me",
            method: "PUT",
            body: body
        )
        currentUser = response.user
    }

    func completeOnboarding() async throws {
        let body: [String: Any] = ["onboardingCompleted": true]
        let response: UserResponse = try await APIClient.shared.request(
            endpoint: "/auth/me",
            method: "PUT",
            body: body
        )
        currentUser = response.user
    }

    func logout() {
        keychain.delete(for: Constants.keychainTokenKey)
        currentUser = nil
        isAuthenticated = false
    }
}
