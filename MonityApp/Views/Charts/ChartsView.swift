import SwiftUI
import Charts

struct ChartsView: View {
    @StateObject private var viewModel = ChartsViewModel()
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        if let summary = viewModel.currentSummary,
                           !summary.byCategory.isEmpty {
                            CategoryPieChart(categories: summary.byCategory)
                                .staggeredAppear(appeared: appeared, index: 0)
                        }

                        if !viewModel.monthlyData.isEmpty {
                            MonthlyBarChart(data: viewModel.monthlyData)
                                .staggeredAppear(appeared: appeared, index: 1)

                            TrendLineChart(data: viewModel.monthlyData)
                                .staggeredAppear(appeared: appeared, index: 2)
                        }

                        if viewModel.currentSummary == nil && viewModel.monthlyData.isEmpty {
                            EmptyStateView(
                                icon: "chart.bar.xaxis",
                                title: "no_data",
                                message: "add_transactions_for_charts"
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("charts")
            .refreshable { await viewModel.loadCharts() }
            .task {
                await viewModel.loadCharts()
                appeared = true
            }
        }
    }
}
