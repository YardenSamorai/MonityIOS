import SwiftUI

struct LoadingView: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            CanvasBackground()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(BrandColor.primary.opacity(0.12), lineWidth: 3)
                        .frame(width: 60, height: 60)
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [BrandColor.primary, BrandColor.primaryDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotation))

                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(BrandColor.primary)
                }

                Text("loading")
                    .font(AppFont.label)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
