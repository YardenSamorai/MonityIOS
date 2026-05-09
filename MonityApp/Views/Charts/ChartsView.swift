import SwiftUI
import Charts

struct ChartsView: View {
    @StateObject private var viewModel = ChartsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    private var chartCurrency: String {
        AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 300)
                        } else if viewModel.currentSummary == nil && viewModel.monthlyData.isEmpty {
                            EmptyStateCard(
                                icon: "chart.bar.xaxis",
                                title: "no_data",
                                message: "add_transactions_for_charts"
                            )
                            .padding(.top, 40)
                        } else {
                            if !viewModel.insights.isEmpty {
                                GlassSurface(padding: 0) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle().fill(BrandColor.accent.opacity(0.15))
                                                Image(systemName: "sparkles")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(BrandColor.accent)
                                            }
                                            .frame(width: 32, height: 32)
                                            Text("smart_insights")
                                                .font(AppFont.titleS)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.top, 14)
                                        .padding(.bottom, 8)

                                        ForEach(Array(viewModel.insights.enumerated()), id: \.element.id) { idx, insight in
                                            ChartInsightCard(insight: insight)
                                                .padding(.horizontal, 14)
                                            if idx < viewModel.insights.count - 1 {
                                                Divider()
                                                    .padding(.leading, 64)
                                            }
                                        }
                                        .padding(.bottom, 10)
                                    }
                                }
                            }

                            if let summary = viewModel.currentSummary, !summary.byCategory.isEmpty {
                                CategoryPieChart(categories: summary.byCategory)
                            }

                            if !viewModel.monthlyData.isEmpty {
                                MonthlyBarChart(data: viewModel.monthlyData, currency: chartCurrency)
                                TrendLineChart(data: viewModel.monthlyData, currency: chartCurrency)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
                }
                .refreshable { await viewModel.loadCharts() }
            }
            .navigationTitle("tab_insights")
            .task { await viewModel.loadCharts() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.loadCharts() }
                }
            }
        }
    }
}

// MARK: - Shared chart UI (kept here so all chart files in the target see these types)

/// Shown under a chart when the user selects a month or category.
struct ChartTapExplainer: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BrandColor.primary)
                .frame(width: 28, height: 28)
                .background(BrandColor.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(message)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Surface.card.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .strokeBorder(Surface.separator.opacity(0.45), lineWidth: 0.5)
        )
    }
}

struct ChartInsightCard: View {
    let insight: ChartInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BrandColor.accent.opacity(0.14))
                Image(systemName: insight.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(BrandColor.accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                Text(insight.detail)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }
}
