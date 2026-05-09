import SwiftUI

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var showAddTransaction = false
    @State private var editingTransaction: Transaction?
    @State private var deletingTransaction: Transaction?
    @State private var showTrash = false
    @State private var showFilters = false
    @State private var pendingUndoId: String?
    @State private var showSwipeTip = false
    @AppStorage("txn_swipe_tip_shown") private var swipeTipShown = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                CanvasBackground()

                if viewModel.filteredTransactions.isEmpty && !viewModel.isLoading {
                    EmptyStateCard(
                        icon: "tray",
                        title: "no_transactions",
                        message: emptyMessageKey,
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

                if pendingUndoId != nil {
                    undoBanner
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if showSwipeTip {
                    swipeTipOverlay
                }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("search_transactions"))
            .navigationTitle("transactions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showFilters = true
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                        Button {
                            showTrash = true
                        } label: {
                            Image(systemName: "trash.circle")
                        }
                    }
                }
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
            .sheet(isPresented: $showTrash) {
                TransactionTrashView(transactionViewModel: viewModel)
            }
            .sheet(isPresented: $showFilters) {
                TransactionFilterSheet(viewModel: viewModel)
            }
            .confirmationDialog(L("delete_transaction_confirm"), isPresented: .init(
                get: { deletingTransaction != nil },
                set: { if !$0 { deletingTransaction = nil } }
            ), titleVisibility: .visible) {
                Button(L("delete"), role: .destructive) {
                    if let txn = deletingTransaction {
                        let id = txn.id
                        Task {
                            await viewModel.deleteTransaction(id)
                            pendingUndoId = id
                            scheduleUndoClear(for: id)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                    deletingTransaction = nil
                }
            } message: {
                Text("delete_moves_to_trash")
            }
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.scheduleDebouncedReload()
            }
            .onChange(of: viewModel.filteredTransactions.count) { _, newCount in
                if newCount > 0 && !swipeTipShown && !showSwipeTip {
                    showSwipeTip = true
                }
            }
            .task {
                await viewModel.loadCategories()
                await viewModel.loadTransactions()
            }
        }
    }

    private var emptyMessageKey: LocalizedStringKey {
        if viewModel.filterCategoryId != nil
            || viewModel.filterDateFrom != nil
            || viewModel.filterDateTo != nil
            || viewModel.filterType != nil
            || !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "no_transaction_results"
        }
        return "add_first_transaction"
    }

    private func scheduleUndoClear(for id: String) {
        Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await MainActor.run {
                if pendingUndoId == id { pendingUndoId = nil }
            }
        }
    }

    private var undoBanner: some View {
        HStack(spacing: 12) {
            Text("transaction_undo_prompt")
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 8)
            Button("undo") {
                if let id = pendingUndoId {
                    Task {
                        await viewModel.restoreTransaction(id)
                        pendingUndoId = nil
                    }
                }
            }
            .font(.subheadline.weight(.bold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 96)
    }

    private var swipeTipOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    showSwipeTip = false
                    swipeTipShown = true
                }

            VStack(spacing: 16) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 44))
                    .foregroundStyle(BrandColor.primary)
                Text("swipe_tip_title")
                    .font(AppFont.titleS)
                Text("swipe_tip_body")
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("got_it") {
                    showSwipeTip = false
                    swipeTipShown = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .background(Surface.card)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 32)
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

// MARK: - Filter sheet

struct TransactionFilterSheet: View {
    @ObservedObject var viewModel: TransactionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var categories: [Category] = []
    @State private var categoryId: Int?
    @State private var useFrom = false
    @State private var useTo = false
    @State private var fromDate = Date()
    @State private var toDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Picker("filter_category_section", selection: $categoryId) {
                    Text("all_categories").tag(Optional<Int>.none)
                    ForEach(categories) { c in
                        Text(c.localizedName).tag(Optional(c.id))
                    }
                }
                Section {
                    Toggle("filter_from_date", isOn: $useFrom)
                    if useFrom {
                        DatePicker("", selection: $fromDate, displayedComponents: .date)
                    }
                    Toggle("filter_to_date", isOn: $useTo)
                    if useTo {
                        DatePicker("", selection: $toDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("transaction_filters_title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("apply") { apply() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("clear_filters", role: .destructive) {
                        viewModel.filterCategoryId = nil
                        viewModel.filterDateFrom = nil
                        viewModel.filterDateTo = nil
                        Task {
                            await viewModel.loadTransactions()
                            dismiss()
                        }
                    }
                }
            }
        }
        .task { await loadCategories() }
        .onAppear { syncFromViewModel() }
    }

    private func syncFromViewModel() {
        categoryId = viewModel.filterCategoryId
        if let f = viewModel.filterDateFrom, let d = DateHelper.fromAPIString(f) {
            useFrom = true
            fromDate = d
        } else {
            useFrom = false
        }
        if let t = viewModel.filterDateTo, let d = DateHelper.fromAPIString(t) {
            useTo = true
            toDate = d
        } else {
            useTo = false
        }
    }

    private func loadCategories() async {
        do {
            let r: CategoryListResponse = try await APIClient.shared.request(endpoint: "/categories")
            categories = r.categories
        } catch {
            categories = []
        }
    }

    private func apply() {
        viewModel.filterCategoryId = categoryId
        viewModel.filterDateFrom = useFrom ? DateHelper.toAPIString(fromDate) : nil
        viewModel.filterDateTo = useTo ? DateHelper.toAPIString(toDate) : nil
        Task {
            await viewModel.loadTransactions()
            dismiss()
        }
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
