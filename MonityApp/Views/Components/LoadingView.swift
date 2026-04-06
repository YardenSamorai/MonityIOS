import SwiftUI

struct LoadingView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(AppTheme.accent.opacity(0.15), lineWidth: 4)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(AppTheme.primaryGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(rotation))

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .scaleEffect(scale)

            Text("loading")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever()) {
                scale = 1.0
            }
        }
    }
}
