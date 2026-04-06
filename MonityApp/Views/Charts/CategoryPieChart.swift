import SwiftUI
import Charts

struct CategoryPieChart: View {
    let categories: [CategorySummary]
    @State private var selectedCategory: CategorySummary?
    @State private var chartRevealed = false

    var body: some View {
        SolidCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    GradientIcon(systemName: "chart.pie.fill", gradient: AppTheme.expenseGradient)
                    Text("expenses_by_category")
                        .font(.headline)
                }

                ZStack {
                    Chart(categories) { cat in
                        SectorMark(
                            angle: .value("Amount", chartRevealed ? cat.totalAmount : 0),
                            innerRadius: .ratio(0.65),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(hex: cat.Category?.color ?? "#6C63FF"))
                        .cornerRadius(6)
                        .opacity(selectedCategory == nil || selectedCategory?.id == cat.id ? 1 : 0.4)
                    }
                    .chartOverlay { _ in
                        if let selected = selectedCategory {
                            VStack(spacing: 2) {
                                Text(selected.Category?.icon ?? "")
                                    .font(.title2)
                                    .transition(.scale.combined(with: .opacity))
                                Text(CurrencyHelper.format(selected.totalAmount))
                                    .font(.subheadline.weight(.bold).monospacedDigit())
                                    .contentTransition(.numericText())
                            }
                        }
                    }
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) { selectedCategory = nil }
                    }
                }
                .frame(height: 200)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                        chartRevealed = true
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = selectedCategory?.id == cat.id ? nil : cat
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(hex: cat.Category?.color ?? "#6C63FF"))
                                    .frame(width: 8, height: 8)
                                Text(cat.Category?.icon ?? "")
                                    .font(.caption)
                                Text(cat.Category?.localizedName ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(selectedCategory?.id == cat.id ? AppTheme.accent.opacity(0.08) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .scaleEffect(selectedCategory?.id == cat.id ? 1.05 : 1.0)
                        }
                        .bounceIn(delay: Double(index) * 0.05 + 0.5)
                    }
                }
            }
            .padding(20)
        }
    }
}
