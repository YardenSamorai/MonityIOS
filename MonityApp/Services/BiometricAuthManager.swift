import Foundation
import LocalAuthentication

@MainActor
final class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()

    @Published var isLocked = false
    @Published var isAvailable = false

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "biometric_lock_enabled") }
        set {
            UserDefaults.standard.set(newValue, forKey: "biometric_lock_enabled")
            if newValue {
                isLocked = true
            }
        }
    }

    var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    var biometricName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Biometric"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        default: return "lock.fill"
        }
    }

    private init() {
        checkAvailability()
        if isEnabled {
            isLocked = true
        }
    }

    func checkAvailability() {
        let context = LAContext()
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate() async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = L("use_passcode")

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isLocked = false
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: L("biometric_reason")
            )
            if success {
                isLocked = false
            }
            return success
        } catch {
            return false
        }
    }

    func lockIfEnabled() {
        if isEnabled {
            isLocked = true
        }
    }
}
