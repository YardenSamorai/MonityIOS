import SwiftUI

struct TransactionTrashView: View {
    @ObservedObject var transactionViewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var trashItems: [Transaction] = []
    @State private var isLoading = true
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()
                if isLoading {
                    ProgressView()
                } else if trashItems.isEmpty {
                    EmptyStateCard(
                        icon: "trash",
                        title: "trash_empty_title",
                        message: "trash_empty_message"
                    )
                    .opacity(0.95)
                } else {
                    List {
                        ForEach(trashItems) { txn in
                            TransactionRowView(
                                transaction: txn,
                                bankBalanceAfter: nil,
                                displayCurrency: AuthService.shared.currentUser?.preferredCurrency
                            )
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    Task { await restore(txn) }
                                } label: {
                                    Label("restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(BrandColor.primary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(L("transaction_trash_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            trashItems = try await transactionViewModel.loadTrashTransactions()
        } catch {
            errorText = error.localizedDescription
            trashItems = []
        }
    }

    private func restore(_ txn: Transaction) async {
        await transactionViewModel.restoreTransaction(txn.id)
        trashItems.removeAll { $0.id == txn.id }
    }
}
