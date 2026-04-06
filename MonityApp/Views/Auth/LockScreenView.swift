import SwiftUI

struct LockScreenView: View {
    @ObservedObject var biometricManager: BiometricAuthManager
    @State private var appeared = false

    private let accentTeal = Color(hex: "0D8B7D")

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [accentTeal, Color(hex: "0FA68B")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .shadow(color: accentTeal.opacity(0.4), radius: 20, y: 6)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.85)

                    Text("Monity")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(appeared ? 1 : 0)

                    Text(L("locked_message"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .opacity(appeared ? 1 : 0)
                }

                Spacer()

                Button {
                    Task { await biometricManager.authenticate() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: biometricManager.biometricIcon)
                            .font(.title3)
                        Text(L("unlock_with") + " " + biometricManager.biometricName)
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white.opacity(0.12))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 44)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await biometricManager.authenticate()
            }
        }
    }
}
