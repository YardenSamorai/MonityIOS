import SwiftUI

@main
struct MonityApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var appearanceManager = AppearanceManager.shared
    @StateObject private var biometricManager = BiometricAuthManager.shared
    @StateObject private var invitationCenter = HouseholdInvitationCenter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isLoading {
                    LoadingView()
                } else if authService.isAuthenticated {
                    if biometricManager.isLocked {
                        LockScreenView(biometricManager: biometricManager)
                    } else if let user = authService.currentUser, !user.onboardingCompleted {
                        OnboardingView()
                            .environmentObject(authService)
                    } else {
                        ContentView()
                            .environmentObject(authService)
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(languageManager)
            .environmentObject(appearanceManager)
            .environmentObject(biometricManager)
            .environmentObject(invitationCenter)
            .environment(\.locale, languageManager.locale)
            .environment(\.layoutDirection, languageManager.layoutDirection)
            .preferredColorScheme(appearanceManager.colorScheme)
            .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authService.currentUser?.onboardingCompleted)
            .animation(.easeInOut(duration: 0.3), value: biometricManager.isLocked)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    biometricManager.lockIfEnabled()
                }
                if newPhase == .active {
                    Task { await invitationCenter.refresh() }
                }
            }
            .onChange(of: authService.isAuthenticated) { _, authenticated in
                if authenticated {
                    Task { await invitationCenter.refresh() }
                } else {
                    invitationCenter.clear()
                }
            }
        }
    }
}
