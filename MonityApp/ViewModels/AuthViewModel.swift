import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLoginMode = true

    private let authService = AuthService.shared

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = L("fill_all_fields")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func register() async {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            errorMessage = L("fill_all_fields")
            return
        }
        guard password.count >= 6 else {
            errorMessage = L("password_min_length")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.register(name: name, email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func toggleMode() {
        isLoginMode.toggle()
        errorMessage = nil
    }
}
