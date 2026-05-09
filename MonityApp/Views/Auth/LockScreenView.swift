import SwiftUI

struct LockScreenView: View {
    @ObservedObject var biometricManager: BiometricAuthManager
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Dark sophisticated gradient
            LinearGradient(
                colors: [
                    Color(hex: "#0A1F1B"),
                    Color(hex: "#0F2C26"),
                    Color(hex: "#0A1F1B"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Animated ambient blobs
            GeometryReader { geo in
                Circle()
                    .fill(BrandColor.primary.opacity(0.18))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 80)
                    .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.3)

                Circle()
                    .fill(BrandColor.accent.opacity(0.1))
                    .frame(width: geo.size.width * 0.6)
                    .blur(radius: 80)
                    .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.5)
            }
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 18) {
                    ZStack {
                        // Glow
                        Circle()
                            .fill(BrandColor.primary.opacity(0.5))
                            .frame(width: 100, height: 100)
                            .blur(radius: 30)

                        // Liquid Glass logo container
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(LinearGradient(
                                colors: [BrandColor.primary, BrandColor.primaryDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                            )

                        Image(systemName: "lock.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .scaleEffect(appeared ? 1 : 0.8)
                    .opacity(appeared ? 1 : 0)

                    VStack(spacing: 6) {
                        Text("Monity")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(L("locked_message"))
                            .font(AppFont.bodyS)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .opacity(appeared ? 1 : 0)
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await biometricManager.authenticate() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: biometricManager.biometricIcon)
                            .font(.title3)
                        Text(L("unlock_with") + " " + biometricManager.biometricName)
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.ultraThinMaterial)
                    .background(Color.white.opacity(0.05))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 44)
                .opacity(appeared ? 1 : 0)

                Button {
                    biometricManager.isEnabled = false
                    biometricManager.isLocked = false
                    AuthService.shared.logout()
                } label: {
                    Text("logout")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.top, 4)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { appeared = true }
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                _ = await biometricManager.authenticate()
            }
        }
    }
}
