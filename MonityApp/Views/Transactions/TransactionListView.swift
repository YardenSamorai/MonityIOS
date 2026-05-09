import SwiftUI

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction?
    @State private var deletingTransaction: Transaction?

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                if viewModel.filteredTransactions.isEmpty && !viewModel.isLoading {
                    EmptyStateCard(
                        icon: "tray",
                        title: "no_transactions",
                        message: "add_first_transaction",
                        actionTitle: "add_transaction",
                        action: { showAddTransaction = true }
                    )
                } else {
                    VStack(spacing: 0) {
                        FilterPills(filterType: $viewModel.filterType) {
                            Task { await viewModel.loadTransactions() }
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                        List {
                            ForEach(groupedByDate, id: \.0) { dateString, transactions in
                                Section {
                                    ForEach(transactions) { txn in
                                        GlassSurface(cornerRadius: Radius.md, padding: 0, elevation: .flat) {
                                            TransactionRowView(
                                                transaction: txn,
                                                bankBalanceAfter: viewModel.bankBalanceByTransactionId[txn.id],
                                                displayCurrency: AuthService.shared.currentUser?.preferredCurrency
                                            )
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 12)
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            editingTransaction = txn
                                        }
                                        .listRowInsets(EdgeInsets(top: 4, leading: Spacing.screenHorizontal, bottom: 4, trailing: Spacing.screenHorizontal))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) {
                                                deletingTransaction = txn
                                            } label: {
                                                Label("delete", systemImage: "trash")
                                            }
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                editingTransaction = txn
                                            } label: {
                                                Label("edit", systemImage: "pencil")
                                            }
                                            .tint(BrandColor.primary)
                                        }
                                    }
                                } header: {
                                    Text(formatGroupDate(dateString))
                                        .font(AppFont.label)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                        .tracking(0.5)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            if viewModel.currentPage < viewModel.totalPages {
                                Section {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .listRowBackground(Color.clear)
                                        .onAppear {
                                            Task { await viewModel.loadTransactions(page: viewModel.currentPage + 1) }
                                        }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await viewModel.loadTransactions() }
                        .padding(.bottom, 100)
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("search_transactions"))
            .navigationTitle("transactions")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    FloatingPlusButton { showAddTransaction = true }
                }
            }
            .sheet(isPresented: $showAddTransaction) {
                AddTransactionView { Task { await viewModel.loadTransactions() } }
            }
            .sheet(item: $editingTransaction) { txn in
                AddTransactionView(editingTransaction: txn) {
                    Task { await viewModel.loadTransactions() }
                }
            }
            .confirmationDialog(L("delete_transaction_confirm"), isPresented: .init(
                get: { deletingTransaction != nil },
                set: { if !$0 { deletingTransaction = nil } }
            ), titleVisibility: .visible) {
                Button(L("delete"), role: .destructive) {
                    if let txn = deletingTransaction {
                        Task {
                            await viewModel.deleteTransaction(txn.id)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                    deletingTransaction = nil
                }
            }
            .task { await viewModel.loadTransactions() }
        }
    }

    private var groupedByDate: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: viewModel.filteredTransactions) { $0.date }
        return grouped.sorted { $0.key > $1.key }
    }

    private func formatGroupDate(_ date: String) -> String {
        let today = DateHelper.toAPIString(Date())
        if date == today { return L("today") }

        if let cal = Calendar.current.date(byAdding: .day, value: -1, to: Date()),
           date == DateHelper.toAPIString(cal) {
            return L("yesterday")
        }
        return DateHelper.display(date)
    }
}

// MARK: - Filter Pills

struct FilterPills: View {
    @Binding var filterType: Transaction.TransactionType?
    let onChange: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(label: "all", icon: "list.bullet", isActive: filterType == nil) {
                    filterType = nil
                    onChange()
                }
                pill(label: "income", icon: "arrow.down.left", isActive: filterType == .income, color: BrandColor.income) {
                    filterType = .income
                    onChange()
                }
                pill(label: "expenses", icon: "arrow.up.right", isActive: filterType == .expense, color: BrandColor.expense) {
                    filterType = .expense
                    onChange()
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func pill(label: LocalizedStringKey, icon: String, isActive: Bool, color: Color = BrandColor.primary, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(Motion.snappy) { action() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isActive ? Color.white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? color : color.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}
