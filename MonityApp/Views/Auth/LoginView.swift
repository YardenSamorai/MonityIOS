import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showPassword = false
    @State private var showForgotPassword = false
    @State private var appeared = false
    @State private var hasBiometricCredentials = false
    @State private var isFaceIDAvailable = false
    @State private var showManualLogin = false
    @State private var biometricUserName: String? = nil

    private let accentTeal = Color(hex: "0D8B7D")

    private var shouldShowFaceIDFirst: Bool {
        isFaceIDAvailable && hasBiometricCredentials && !showManualLogin
    }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    header
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -15)

                    Spacer().frame(height: 48)

                    if shouldShowFaceIDFirst {
                        faceIDPrimaryView
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                    } else {
                        formSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                    }

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 28)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .onAppear {
            checkBiometricCredentials()
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                appeared = true
            }
            if isFaceIDAvailable && hasBiometricCredentials {
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    await loginWithFaceID()
                }
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack {
                ZStack {
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 420)
                        .scaleEffect(x: 1.5)
                        .offset(y: -120)

                    Ellipse()
                        .fill(accentTeal.opacity(0.12))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: 100, y: -60)
                }
                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accentTeal, Color(hex: "0FA68B")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: accentTeal.opacity(0.4), radius: 16, y: 6)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text("Monity")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .tracking(0.5)

            Text("smart_expense_tracking")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Face ID Primary View

    private var faceIDPrimaryView: some View {
        VStack(spacing: 28) {
            if let name = biometricUserName {
                Text(L("welcome_back") + ", " + name)
                    .font(.title3.weight(.bold))
            }

            VStack(spacing: 16) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { await loginWithFaceID() }
                } label: {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "0F2027"), Color(hex: "2C5364")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)

                            Image(systemName: biometricIcon)
                                .font(.system(size: 34))
                                .foregroundStyle(.white)
                        }

                        Text("login_with_faceid")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
                }
            }

            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.subheadline)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity)
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(accentTeal)
            }

            Button {
                withAnimation(.spring(response: 0.4)) {
                    showManualLogin = true
                }
            } label: {
                Text("use_password_instead")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(accentTeal)
            }
        }
        .padding(28)
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    // MARK: - Manual Login Form

    private var formSection: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.isLoginMode ? "login" : "register")
                    .font(.title3.weight(.bold))

                Text(viewModel.isLoginMode ? "login_subtitle" : "register_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                if !viewModel.isLoginMode {
                    fieldRow(icon: "person", label: "name", text: $viewModel.name, contentType: .name)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                fieldRow(icon: "envelope", label: "email", text: $viewModel.email, contentType: .emailAddress, keyboard: .emailAddress)

                passwordRow
            }

            if viewModel.isLoginMode {
                HStack {
                    Spacer()
                    Button { showForgotPassword = true } label: {
                        Text("forgot_password")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(accentTeal)
                    }
                }
                .padding(.top, -12)
            }

            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.subheadline)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity)
            }

            primaryButton

            if viewModel.isLoginMode && isFaceIDAvailable && hasBiometricCredentials {
                Button {
                    withAnimation(.spring(response: 0.4)) {
                        showManualLogin = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: biometricIcon)
                            .font(.subheadline)
                        Text("use_faceid_instead")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(accentTeal)
                }
            }

            dividerSection

            toggleModeButton
        }
        .padding(28)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 20, y: 8)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Fields

    private func fieldRow(icon: String, label: LocalizedStringKey, text: Binding<String>, contentType: UITextContentType? = nil, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 18)

                TextField("", text: text)
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
            )
        }
    }

    private var passwordRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("password")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 18)

                if showPassword {
                    TextField("", text: $viewModel.password)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    SecureField("", text: $viewModel.password)
                        .textContentType(.password)
                }

                Button { showPassword.toggle() } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 1)
            )
        }
    }

    // MARK: - Buttons

    private var primaryButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task {
                if viewModel.isLoginMode {
                    await viewModel.login()
                } else {
                    await viewModel.register()
                }
            }
        } label: {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(viewModel.isLoginMode ? "login" : "register")
                        .font(.subheadline.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [Color(hex: "0F2027"), Color(hex: "2C5364")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(viewModel.isLoading)
    }

    private var dividerSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 1)
            Text("or")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    private var toggleModeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.4)) {
                viewModel.toggleMode()
            }
        } label: {
            Text(viewModel.isLoginMode ? "no_account_register" : "have_account_login")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(accentTeal)
        }
    }

    // MARK: - Biometric

    private var biometricIcon: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    private func checkBiometricCredentials() {
        let context = LAContext()
        var error: NSError?
        isFaceIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if let email = KeychainHelper.shared.read(for: "monity_biometric_email"),
           let password = KeychainHelper.shared.read(for: "monity_biometric_password"),
           !email.isEmpty, !password.isEmpty {
            hasBiometricCredentials = true
            viewModel.email = email
            biometricUserName = UserDefaults.standard.string(forKey: "last_login_name")
        }
    }

    private func loginWithFaceID() async {
        let context = LAContext()
        context.localizedFallbackTitle = L("use_passcode")

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: L("biometric_login_reason")
            )
            guard success else { return }

            guard let email = KeychainHelper.shared.read(for: "monity_biometric_email"),
                  let password = KeychainHelper.shared.read(for: "monity_biometric_password")
            else {
                viewModel.errorMessage = L("biometric_no_credentials")
                return
            }

            viewModel.email = email
            viewModel.password = password
            await viewModel.login()
        } catch {
            if (error as NSError).code == LAError.userCancel.rawValue {
                return
            }
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Forgot Password

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private let accentTeal = Color(hex: "0D8B7D")

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(accentTeal.opacity(0.1))
                            .frame(width: 56, height: 56)
                        Image(systemName: "key.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(accentTeal)
                    }

                    Text("reset_password")
                        .font(.title3.weight(.bold))

                    Text("reset_password_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 24)

                VStack(spacing: 14) {
                    resetField(icon: "envelope", placeholder: "email", text: $email, keyboard: .emailAddress)

                    HStack(spacing: 12) {
                        Image(systemName: "lock")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: 18)
                        if showNewPassword {
                            TextField("new_password", text: $newPassword)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("new_password", text: $newPassword)
                        }
                        Button { showNewPassword.toggle() } label: {
                            Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    resetField(icon: "lock.badge.checkmark", placeholder: "confirm_password", text: $confirmPassword, isSecure: true)
                }
                .padding(.horizontal, 24)

                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill").font(.caption)
                        Text(error).font(.caption)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 24)
                }

                if let success = successMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.caption)
                        Text(success).font(.caption)
                    }
                    .foregroundStyle(accentTeal)
                    .padding(.horizontal, 24)
                }

                Button {
                    Task { await resetPassword() }
                } label: {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("reset_password_button")
                                .font(.subheadline.weight(.bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        (email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                            ? AnyShapeStyle(Color.gray.opacity(0.15))
                            : AnyShapeStyle(LinearGradient(colors: [Color(hex: "0F2027"), Color(hex: "2C5364")], startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isLoading || email.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty)
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }

    private func resetField(icon: String, placeholder: LocalizedStringKey, text: Binding<String>, keyboard: UIKeyboardType = .default, isSecure: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
            if isSecure {
                SecureField(placeholder, text: text)
            } else {
                TextField(placeholder, text: text)
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func resetPassword() async {
        errorMessage = nil
        successMessage = nil

        guard newPassword.count >= 6 else {
            errorMessage = L("password_min_length")
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = L("passwords_dont_match")
            return
        }

        isLoading = true

        do {
            struct ResetResponse: Codable { let message: String }
            let body: [String: Any] = [
                "email": email.lowercased(),
                "newPassword": newPassword,
            ]
            let _: ResetResponse = try await APIClient.shared.request(
                endpoint: "/auth/reset-password",
                method: "POST",
                body: body
            )
            successMessage = L("password_reset_success")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
