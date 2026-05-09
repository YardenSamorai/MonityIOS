import SwiftUI
import Charts

struct ChartsView: View {
    @StateObject private var viewModel = ChartsViewModel()
    @Environment(\.scenePhase) private var scenePhase

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
                            if let summary = viewModel.currentSummary, !summary.byCategory.isEmpty {
                                CategoryPieChart(categories: summary.byCategory)
                            }

                            if !viewModel.monthlyData.isEmpty {
                                MonthlyBarChart(data: viewModel.monthlyData)
                                TrendLineChart(data: viewModel.monthlyData)
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
