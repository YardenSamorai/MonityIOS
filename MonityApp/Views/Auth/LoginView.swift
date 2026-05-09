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
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, email, password
    }

    private var shouldShowFaceIDFirst: Bool {
        isFaceIDAvailable && hasBiometricCredentials && !showManualLogin
    }

    var body: some View {
        ZStack {
            AnimatedAuthBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    brandHeader
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : -20)
                        .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1), value: appeared)

                    Spacer().frame(height: 32)

                    Group {
                        if shouldShowFaceIDFirst {
                            faceIDPrimaryView
                        } else {
                            formCard
                        }
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 30)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.25), value: appeared)

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(prefilledEmail: viewModel.email)
        }
        .onAppear {
            checkBiometricCredentials()
            appeared = true
            if isFaceIDAvailable && hasBiometricCredentials {
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    await loginWithFaceID()
                }
            }
        }
    }

    // MARK: - Brand Header

    private var brandHeader: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(AuthGradients.brandGlow)
                        .frame(width: 100 + CGFloat(i) * 24, height: 100 + CGFloat(i) * 24)
                        .opacity(0.18 - Double(i) * 0.05)
                        .blur(radius: 12)
                }

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AuthGradients.logoTile)
                    .frame(width: 78, height: 78)
                    .shadow(color: AuthColors.brandTeal.opacity(0.4), radius: 20, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    )

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }

            VStack(spacing: 6) {
                Text("Monity")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.3)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)

                Text("smart_expense_tracking")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Face ID Primary View

    private var faceIDPrimaryView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                if let name = biometricUserName, !name.isEmpty {
                    Text(L("welcome_back") + ", " + name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                } else {
                    Text("welcome_back")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Text("login_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await loginWithFaceID() }
            } label: {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AuthGradients.faceIDCircle)
                            .frame(width: 100, height: 100)
                            .shadow(color: AuthColors.brandTeal.opacity(0.35), radius: 18, y: 8)

                        Circle()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1.5)
                            .frame(width: 100, height: 100)

                        Image(systemName: biometricIcon)
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.white)
                    }

                    Text("login_with_faceid")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("tap_to_authenticate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            if viewModel.isLoading {
                ProgressView()
                    .tint(AuthColors.brandTeal)
                    .scaleEffect(1.1)
            }

            Divider()
                .padding(.horizontal, 40)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    showManualLogin = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                        .font(.caption.weight(.semibold))
                    Text("use_password_instead")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AuthColors.brandTeal)
                .padding(.vertical, 8)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.7))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 30, y: 15)
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.isLoginMode ? "login" : "register")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text(viewModel.isLoginMode ? "login_subtitle" : "register_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                if !viewModel.isLoginMode {
                    AuthInputField(
                        icon: "person.fill",
                        label: L("name"),
                        text: $viewModel.name,
                        contentType: .name,
                        keyboard: .default,
                        isFocused: focusedField == .name
                    )
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                AuthInputField(
                    icon: "envelope.fill",
                    label: L("email"),
                    text: $viewModel.email,
                    contentType: .emailAddress,
                    keyboard: .emailAddress,
                    isFocused: focusedField == .email
                )
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

                AuthPasswordField(
                    label: L("password"),
                    text: $viewModel.password,
                    showPassword: $showPassword,
                    isFocused: focusedField == .password
                )
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit {
                    focusedField = nil
                    Task {
                        if viewModel.isLoginMode { await viewModel.login() }
                        else { await viewModel.register() }
                    }
                }
            }

            if viewModel.isLoginMode {
                HStack {
                    Spacer()
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showForgotPassword = true
                    } label: {
                        Text("forgot_password")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AuthColors.brandTeal)
                    }
                }
                .padding(.top, -4)
            }

            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            primaryButton

            if viewModel.isLoginMode && isFaceIDAvailable && hasBiometricCredentials {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        showManualLogin = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: biometricIcon)
                            .font(.subheadline.weight(.semibold))
                        Text("use_faceid_instead")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AuthColors.brandTeal)
                }
            }

            dividerSection

            toggleModeButton
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.92))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 30, y: 15)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.isLoginMode)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            focusedField = nil
            Task {
                if viewModel.isLoginMode { await viewModel.login() }
                else { await viewModel.register() }
            }
        } label: {
            ZStack {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.95)
                } else {
                    HStack(spacing: 8) {
                        Text(viewModel.isLoginMode ? "login" : "register")
                            .font(.headline.weight(.bold))
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(AuthGradients.primaryButton)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: AuthColors.brandDark.opacity(0.35), radius: 14, y: 8)
        }
        .disabled(viewModel.isLoading)
        .scaleEffect(viewModel.isLoading ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isLoading)
    }

    private var dividerSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 1)
            Text("or")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1)
            Rectangle()
                .fill(Color(.separator).opacity(0.4))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    private var toggleModeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                viewModel.toggleMode()
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.isLoginMode ? "no_account" : "have_account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(viewModel.isLoginMode ? "register" : "login")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AuthColors.brandTeal)
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text(text)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(hex: "D63031"))
        .padding(14)
        .background(Color(hex: "D63031").opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: "D63031").opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
           !email.isEmpty,
           (KeychainHelper.shared.read(for: "monity_biometric_token") != nil ||
            KeychainHelper.shared.read(for: "monity_biometric_password") != nil) {
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

            do {
                try await AuthService.shared.loginWithBiometricToken()
            } catch let apiError as APIError where apiError.isUnauthorized {
                viewModel.errorMessage = L("biometric_session_expired")
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        } catch {
            if (error as NSError).code == LAError.userCancel.rawValue {
                return
            }
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Auth Colors & Gradients

enum AuthColors {
    static let brandTeal = BrandColor.primary
    static let brandTealLight = Color(hex: "#14A18C")
    static let brandDark = Color(hex: "#0A1F1B")
    static let brandMid = Color(hex: "#0F2C26")
    static let brandLight = Color(hex: "#143C32")
    static let accent = BrandColor.accent
}

enum AuthGradients {
    static let primaryButton = LinearGradient(
        colors: [AuthColors.brandDark, AuthColors.brandLight],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let logoTile = LinearGradient(
        colors: [AuthColors.brandTeal, AuthColors.brandTealLight, AuthColors.accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let faceIDCircle = LinearGradient(
        colors: [AuthColors.brandDark, AuthColors.brandLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let brandGlow = RadialGradient(
        colors: [AuthColors.brandTeal.opacity(0.6), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 80
    )
}

// MARK: - Animated Background

struct AnimatedAuthBackground: View {
    @State private var animateBlobs = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AuthColors.brandDark,
                    AuthColors.brandMid,
                    AuthColors.brandLight,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AuthColors.brandTeal.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: animateBlobs ? -120 : -180, y: animateBlobs ? -250 : -200)
                .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateBlobs)

            Circle()
                .fill(AuthColors.accent.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 70)
                .offset(x: animateBlobs ? 140 : 100, y: animateBlobs ? 200 : 280)
                .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: animateBlobs)

            Circle()
                .fill(Color(hex: "0FA68B").opacity(0.18))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: animateBlobs ? 100 : 60, y: animateBlobs ? -100 : -50)
                .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: animateBlobs)
        }
        .onAppear { animateBlobs = true }
    }
}

// MARK: - Floating Label Input Field

struct AuthInputField: View {
    let icon: String
    let label: String
    @Binding var text: String
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isFocused ? AuthColors.brandTeal : Color.secondary)
                .frame(width: 22)
                .animation(.easeOut(duration: 0.2), value: isFocused)

            ZStack(alignment: .leading) {
                if !text.isEmpty {
                    EmptyView()
                } else {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                TextField("", text: $text)
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isFocused ? AuthColors.brandTeal.opacity(0.6) : Color(.separator).opacity(0.3),
                    lineWidth: isFocused ? 1.5 : 1
                )
                .animation(.easeOut(duration: 0.2), value: isFocused)
        )
    }
}

struct AuthPasswordField: View {
    let label: String
    @Binding var text: String
    @Binding var showPassword: Bool
    var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isFocused ? AuthColors.brandTeal : Color.secondary)
                .frame(width: 22)
                .animation(.easeOut(duration: 0.2), value: isFocused)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if showPassword {
                    TextField("", text: $text)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .font(.subheadline.weight(.medium))
                } else {
                    SecureField("", text: $text)
                        .textContentType(.password)
                        .font(.subheadline.weight(.medium))
                }
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isFocused ? AuthColors.brandTeal.opacity(0.6) : Color(.separator).opacity(0.3),
                    lineWidth: isFocused ? 1.5 : 1
                )
                .animation(.easeOut(duration: 0.2), value: isFocused)
        )
    }
}

// MARK: - Forgot Password (3-step OTP flow)

struct ForgotPasswordView: View {
    let prefilledEmail: String

    @Environment(\.dismiss) private var dismiss

    enum Step: Int, CaseIterable {
        case email = 0
        case code = 1
        case password = 2
    }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var otpCode = ""
    @State private var resetToken = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var showSuccess = false

    init(prefilledEmail: String = "") {
        self.prefilledEmail = prefilledEmail
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        AuthColors.brandDark.opacity(0.05),
                        AuthColors.brandTeal.opacity(0.03),
                        Color(.systemBackground),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        progressIndicator
                            .padding(.top, 12)

                        headerSection
                            .padding(.top, 4)

                        Group {
                            switch step {
                            case .email: emailStep
                            case .code: codeStep
                            case .password: passwordStep
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                        if showSuccess {
                            successView
                                .transition(.scale.combined(with: .opacity))
                        }

                        if let error = errorMessage {
                            errorBanner(error)
                                .padding(.horizontal, 24)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }

                        if let info = infoMessage {
                            infoBanner(info)
                                .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 34, height: 34)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                }
                if step == .code && !showSuccess {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                errorMessage = nil
                                infoMessage = nil
                                otpCode = ""
                                step = .email
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.subheadline.weight(.bold))
                                    .environment(\.layoutDirection, .leftToRight)
                                Text("back")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(AuthColors.brandTeal)
                        }
                    }
                }
            }
            .onAppear {
                if !prefilledEmail.isEmpty {
                    email = prefilledEmail
                }
            }
            .onChange(of: step) { _, _ in
                errorMessage = nil
                infoMessage = nil
            }
        }
    }

    // MARK: - Progress

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? AuthColors.brandTeal : Color(.separator).opacity(0.5))
                    .frame(height: 4)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
            }
        }
        .padding(.horizontal, 80)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AuthColors.brandTeal.opacity(0.12))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(AuthColors.brandTeal.opacity(0.18))
                    .frame(width: 60, height: 60)

                Image(systemName: stepIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AuthColors.brandTeal)
            }

            VStack(spacing: 6) {
                Text(stepTitle)
                    .font(.title2.weight(.bold))

                Text(stepSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(3)
            }
        }
    }

    private var stepIcon: String {
        switch step {
        case .email: return "envelope.fill"
        case .code: return "lock.shield.fill"
        case .password: return "key.fill"
        }
    }

    private var stepTitle: String {
        switch step {
        case .email: return L("forgot_step_email_title")
        case .code: return L("forgot_step_code_title")
        case .password: return L("forgot_step_password_title")
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .email: return L("forgot_step_email_subtitle")
        case .code: return String(format: L("forgot_step_code_subtitle"), email)
        case .password: return L("forgot_step_password_subtitle")
        }
    }

    // MARK: - Email Step

    private var emailStep: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                AuthInputField(
                    icon: "envelope.fill",
                    label: L("email"),
                    text: $email,
                    contentType: .emailAddress,
                    keyboard: .emailAddress,
                    isFocused: false
                )
            }

            Button {
                Task { await requestOtp() }
            } label: {
                primaryButtonLabel(title: L("forgot_send_code"))
            }
            .disabled(isLoading || email.isEmpty)
            .opacity(email.isEmpty ? 0.55 : 1)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Code Step

    private var codeStep: some View {
        VStack(spacing: 22) {
            OTPInputView(code: $otpCode) {
                Task { await verifyOtp() }
            }
            .padding(.horizontal, 8)

            Button {
                Task { await verifyOtp() }
            } label: {
                primaryButtonLabel(title: L("forgot_verify_code"))
            }
            .disabled(isLoading || otpCode.count < 6)
            .opacity(otpCode.count < 6 ? 0.55 : 1)

            Button {
                Task { await requestOtp(resend: true) }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                    Text("forgot_resend_code")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AuthColors.brandTeal)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Password Step

    private var passwordStep: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                AuthPasswordField(
                    label: L("new_password"),
                    text: $newPassword,
                    showPassword: $showNewPassword,
                    isFocused: false
                )

                AuthPasswordField(
                    label: L("confirm_password"),
                    text: $confirmPassword,
                    showPassword: .constant(false),
                    isFocused: false
                )

                if !newPassword.isEmpty {
                    PasswordStrengthIndicator(password: newPassword)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Button {
                Task { await resetPassword() }
            } label: {
                primaryButtonLabel(title: L("change_password_button"))
            }
            .disabled(isLoading || newPassword.isEmpty || confirmPassword.isEmpty)
            .opacity((newPassword.isEmpty || confirmPassword.isEmpty) ? 0.55 : 1)
        }
        .padding(.horizontal, 24)
        .animation(.easeOut(duration: 0.25), value: newPassword.isEmpty)
    }

    // MARK: - Success

    private var successView: some View {
        VStack(spacing: 20) {
            SuccessCheckmark(color: AuthColors.brandTeal)

            Text("password_reset_success")
                .font(.headline.weight(.bold))
                .foregroundStyle(AuthColors.brandTeal)

            Text("forgot_success_message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Buttons

    private func primaryButtonLabel(title: String) -> some View {
        ZStack {
            if isLoading {
                ProgressView().tint(.white)
            } else {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline.weight(.bold))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.bold))
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(AuthGradients.primaryButton)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AuthColors.brandDark.opacity(0.3), radius: 12, y: 6)
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)
            Text(text)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(hex: "D63031"))
        .padding(14)
        .background(Color(hex: "D63031").opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: "D63031").opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func infoBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.subheadline)
            Text(text)
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(AuthColors.brandTeal)
        .padding(14)
        .background(AuthColors.brandTeal.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AuthColors.brandTeal.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - API actions

    private func requestOtp(resend: Bool = false) async {
        guard !isLoading else { return }
        errorMessage = nil
        infoMessage = nil

        let trimmed = email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            errorMessage = L("invalid_email")
            return
        }

        isLoading = true
        resetToken = ""
        do {
            struct Resp: Codable { let message: String }
            let lang = UserDefaults.standard.string(forKey: "app_language") ?? "he"
            let _: Resp = try await APIClient.shared.request(
                endpoint: "/auth/forgot-password",
                method: "POST",
                body: ["email": trimmed, "locale": lang]
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                if resend {
                    infoMessage = L("forgot_code_resent")
                } else {
                    step = .code
                    otpCode = ""
                }
            }
        } catch let apiError as APIError where apiError.statusCode == 429 {
            errorMessage = L("forgot_rate_limited")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func verifyOtp() async {
        guard !isLoading else { return }
        guard step == .code else { return }
        errorMessage = nil
        infoMessage = nil

        let cleaned = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count == 6, Int(cleaned) != nil else {
            errorMessage = L("forgot_invalid_code")
            return
        }

        if !resetToken.isEmpty {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                step = .password
            }
            return
        }

        isLoading = true
        do {
            struct Resp: Codable { let resetToken: String }
            let resp: Resp = try await APIClient.shared.request(
                endpoint: "/auth/verify-otp",
                method: "POST",
                body: ["email": email.lowercased(), "code": cleaned]
            )
            resetToken = resp.resetToken
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                step = .password
            }
        } catch {
            if step == .code {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func resetPassword() async {
        guard !isLoading else { return }
        errorMessage = nil
        infoMessage = nil

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
            struct Resp: Codable { let message: String }
            let _: Resp = try await APIClient.shared.request(
                endpoint: "/auth/reset-password",
                method: "POST",
                body: [
                    "email": email.lowercased(),
                    "resetToken": resetToken,
                    "newPassword": newPassword,
                ]
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                showSuccess = true
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        isLoading = false
    }
}

// MARK: - OTP Input View

struct OTPInputView: View {
    @Binding var code: String
    var onComplete: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: Binding(
                get: { code },
                set: { newValue in
                    let digits = newValue.filter { $0.isNumber }
                    code = String(digits.prefix(6))
                    if code.count == 6 {
                        focused = false
                        onComplete()
                    }
                }
            ))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focused)
            .opacity(0.001)
            .frame(width: 1, height: 1)

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { idx in
                    OTPDigitBox(
                        digit: digitAt(idx),
                        isFocused: focused && idx == code.count
                    )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focused = true
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focused = true
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func digitAt(_ index: Int) -> String {
        guard index < code.count else { return "" }
        let i = code.index(code.startIndex, offsetBy: index)
        return String(code[i])
    }
}

struct OTPDigitBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.tertiarySystemBackground))

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isFocused ? AuthColors.brandTeal : (digit.isEmpty ? Color(.separator).opacity(0.3) : AuthColors.brandTeal.opacity(0.4)),
                    lineWidth: isFocused ? 2 : 1.5
                )

            Text(digit)
                .font(.title.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .frame(width: 48, height: 56)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: digit)
    }
}

// MARK: - Password Strength Indicator

struct PasswordStrengthIndicator: View {
    let password: String

    private var strength: Int {
        var score = 0
        if password.count >= 6 { score += 1 }
        if password.count >= 10 { score += 1 }
        if password.contains(where: { $0.isLetter }) && password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { !$0.isLetter && !$0.isNumber }) { score += 1 }
        return min(score, 4)
    }

    private var label: String {
        switch strength {
        case 0, 1: return L("password_weak")
        case 2: return L("password_fair")
        case 3: return L("password_good")
        default: return L("password_strong")
        }
    }

    private var color: Color {
        switch strength {
        case 0, 1: return Color(hex: "E17055")
        case 2: return Color(hex: "FDCB6E")
        case 3: return AuthColors.brandTealLight
        default: return AuthColors.brandTeal
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<4) { i in
                    Capsule()
                        .fill(i < strength ? color : Color(.separator).opacity(0.3))
                        .frame(height: 4)
                }
            }

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: strength)
    }
}
