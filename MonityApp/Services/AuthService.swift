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
        } catch let apiError as APIError {
            if apiError.isUnauthorized {
                logout()
            } else {
                isAuthenticated = true
            }
        } catch {
            isAuthenticated = true
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
        keychain.save(response.token, for: "monity_biometric_token")
        keychain.delete(for: "monity_biometric_password")
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
        keychain.save(email, for: "monity_biometric_email")
        keychain.save(response.token, for: "monity_biometric_token")
        UserDefaults.standard.set(response.user.name, forKey: "last_login_name")
        currentUser = response.user
        isAuthenticated = true
    }

    func loginWithBiometricToken() async throws {
        guard let savedToken = keychain.read(for: "monity_biometric_token"), !savedToken.isEmpty else {
            throw APIError.serverError(401, L("biometric_no_credentials"))
        }
        keychain.save(savedToken, for: Constants.keychainTokenKey)

        do {
            let response: UserResponse = try await APIClient.shared.request(
                endpoint: "/auth/me",
                method: "GET"
            )
            currentUser = response.user
            isAuthenticated = true
        } catch let apiError as APIError {
            if apiError.isUnauthorized {
                keychain.delete(for: Constants.keychainTokenKey)
                keychain.delete(for: "monity_biometric_token")
                keychain.delete(for: "monity_biometric_password")
                throw apiError
            }
            throw apiError
        }
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
        keychain.delete(for: "monity_biometric_token")
        keychain.delete(for: "monity_biometric_password")
        keychain.delete(for: "monity_biometric_email")
        currentUser = nil
        isAuthenticated = false
    }
}
