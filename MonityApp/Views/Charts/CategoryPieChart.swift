import SwiftUI
import Charts

struct CategoryPieChart: View {
    let categories: [CategorySummary]
    @State private var selectedCategory: CategorySummary?

    var body: some View {
        GlassSurface {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(BrandColor.expense.opacity(0.13))
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(BrandColor.expense)
                    }
                    .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("expenses_by_category")
                            .font(AppFont.titleS)
                        Text("expenses_by_category_subtitle")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("chart_pie_hint")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)

                ZStack {
                    Chart(categories) { cat in
                        SectorMark(
                            angle: .value("Amount", cat.totalAmount),
                            innerRadius: .ratio(0.65),
                            angularInset: 2
                        )
                        .foregroundStyle(Color(hex: cat.Category?.color ?? "#0A6B5F"))
                        .cornerRadius(6)
                        .opacity(selectedCategory == nil || selectedCategory?.id == cat.id ? 1 : 0.35)
                    }
                    .chartOverlay { _ in
                        if let selected = selectedCategory {
                            VStack(spacing: 4) {
                                Text(selected.Category?.icon ?? "")
                                    .font(.title2)
                                Text(selected.Category?.localizedName ?? "")
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                                Text(CurrencyHelper.format(selected.totalAmount))
                                    .font(AppFont.amountSmall)
                            }
                        } else {
                            VStack(spacing: 2) {
                                Text("total")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.4)
                                Text(CurrencyHelper.format(totalAmount))
                                    .font(AppFont.amountSmall)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .onTapGesture {
                        withAnimation(Motion.snappy) { selectedCategory = nil }
                    }
                }
                .frame(height: 200)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(categories) { cat in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(Motion.snappy) {
                                selectedCategory = selectedCategory?.id == cat.id ? nil : cat
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: cat.Category?.color ?? "#0A6B5F"))
                                        .frame(width: 8, height: 8)
                                    Text(cat.Category?.icon ?? "")
                                        .font(.caption)
                                    Text(cat.Category?.localizedName ?? "")
                                        .font(AppFont.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    Spacer(minLength: 0)
                                }
                                Text(CurrencyHelper.format(cat.totalAmount))
                                    .font(.system(size: 11, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                selectedCategory?.id == cat.id
                                    ? Color(hex: cat.Category?.color ?? "#0A6B5F").opacity(0.1)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                if let sel = selectedCategory, totalAmount > 0.01 {
                    let pct = Int(round((sel.totalAmount / totalAmount) * 100))
                    ChartTapExplainer(
                        title: sel.Category?.localizedName ?? L("chart_pie_selection_title"),
                        message: String(
                            format: L("chart_pie_selection_body"),
                            pct,
                            sel.count,
                            CurrencyHelper.format(sel.totalAmount)
                        )
                    )
                }
            }
        }
    }

    private var totalAmount: Double {
        categories.reduce(0) { $0 + $1.totalAmount }
    }
}
