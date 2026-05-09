import SwiftUI

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TransactionViewModel()

    @State private var amountText = ""
    @State private var note = ""
    @State private var date = Date()
    @State private var type: Transaction.TransactionType = .expense
    @State private var selectedCategoryId: Int?
    @State private var selectedCreditCardId: String?
    @State private var currency = AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var installments: Int = 1

    var editingTransaction: Transaction?
    var onSave: (() -> Void)?

    private var isEditing: Bool { editingTransaction != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        typePicker

                        amountInput

                        detailsCard

                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        PrimaryButton(
                            title: isEditing ? "update" : "save",
                            icon: isEditing ? "pencil" : "checkmark",
                            isLoading: isSubmitting,
                            isDisabled: amountText.isEmpty
                        ) {
                            Task { await save() }
                        }

                        if isEditing {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash")
                                    Text("delete_transaction")
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .foregroundStyle(BrandColor.expense)
                                .background(BrandColor.expense.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? "edit_transaction" : "add_transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    GlassIconButton(icon: "xmark", size: 32) { dismiss() }
                }
            }
            .confirmationDialog(L("delete_confirm_title"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button(L("delete"), role: .destructive) {
                    guard let txn = editingTransaction else { return }
                    Task {
                        await viewModel.deleteTransaction(txn.id)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onSave?()
                        dismiss()
                    }
                }
            } message: {
                Text("delete_confirm_message")
            }
            .task {
                await viewModel.loadCategories()
                await viewModel.loadCreditCards()
                if let txn = editingTransaction {
                    populateFields(from: txn)
                }
            }
        }
    }

    // MARK: - Type Picker (Segmented)

    private var typePicker: some View {
        HStack(spacing: 4) {
            typeButton(.expense, label: "expense", icon: "arrow.up.right", color: BrandColor.expense)
            typeButton(.income, label: "income", icon: "arrow.down.left", color: BrandColor.income)
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Surface.separator.opacity(0.4), lineWidth: 0.5)
        )
    }

    private func typeButton(_ t: Transaction.TransactionType, label: LocalizedStringKey, icon: String, color: Color) -> some View {
        let active = type == t
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(Motion.snappy) {
                type = t
                if t == .income { installments = 1 }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .bold))
                Text(label).font(.subheadline.weight(.bold))
            }
            .foregroundStyle(active ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(active ? color : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .shadow(color: active ? color.opacity(0.3) : .clear, radius: 6, y: 3)
        }
    }

    // MARK: - Amount Input (hero)

    private var amountInput: some View {
        FeatureGlassCard(
            cornerRadius: Radius.xxl,
            padding: 24,
            gradient: LinearGradient(
                colors: type == .expense
                    ? [BrandColor.expense, BrandColor.expense.opacity(0.7)]
                    : [BrandColor.income, BrandColor.income.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            glowColor: type == .expense ? BrandColor.expense : BrandColor.income
        ) {
            VStack(spacing: 8) {
                Text("amount")
                    .font(AppFont.label)
                    .foregroundStyle(.white.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.5)

                CurrencyTextField(title: "", value: $amountText, currency: currency)
            }
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        GlassSurface(padding: 0) {
            VStack(spacing: 0) {
                fieldRow(icon: "pencil.line", label: "note") {
                    TextField(type == .income ? L("note_placeholder_income") : L("note_placeholder"), text: $note)
                        .font(AppFont.body)
                }

                Divider().padding(.leading, 52)

                fieldRow(icon: "calendar", label: "date") {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }

                Divider().padding(.leading, 52)

                NavigationLink {
                    CategoryPickerView(
                        categories: viewModel.categories.filter {
                            $0.type.rawValue == type.rawValue || $0.type == .both
                        },
                        selectedId: $selectedCategoryId
                    )
                } label: {
                    fieldRow(icon: "tag.fill", label: "category") {
                        if let cat = viewModel.categories.first(where: { $0.id == selectedCategoryId }) {
                            HStack(spacing: 6) {
                                Text(cat.icon)
                                Text(cat.localizedName)
                                    .font(AppFont.body)
                                    .foregroundStyle(.primary)
                            }
                        } else {
                            Text("select_category")
                                .font(AppFont.body)
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                            .environment(\.layoutDirection, .leftToRight)
                    }
                }
                .buttonStyle(.plain)

                if !viewModel.creditCards.isEmpty {
                    Divider().padding(.leading, 52)
                    fieldRow(icon: "creditcard.fill", label: "payment_method") {
                        Picker("", selection: $selectedCreditCardId) {
                            Text("bank_account").tag(nil as String?)
                            ForEach(viewModel.creditCards) { card in
                                Text("\(card.name) •\(card.lastFourDigits)").tag(card.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                    }
                }

                if selectedCreditCardId != nil && type == .expense && !isEditing {
                    Divider().padding(.leading, 52)
                    fieldRow(icon: "repeat", label: "installments_count") {
                        Stepper(value: $installments, in: 1...36) {
                            Text(installments == 1 ? L("single_payment") : "\(installments) \(L("installments"))")
                                .font(AppFont.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if installments > 1, let amount = Double(amountText), amount > 0 {
                        let perInstallment = (amount / Double(installments) * 100).rounded() / 100
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle").font(.caption2)
                            Text("\(installments) × \(CurrencyHelper.format(perInstallment, currency: currency))")
                                .font(AppFont.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 54)
                        .padding(.bottom, 10)
                    }
                }
            }
        }
    }

    private func fieldRow<Content: View>(icon: String, label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(BrandColor.primary.opacity(0.12))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BrandColor.primary)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
            Text(message)
                .font(AppFont.caption)
            Spacer()
        }
        .foregroundStyle(BrandColor.expense)
        .padding(12)
        .background(BrandColor.expense.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func populateFields(from txn: Transaction) {
        amountText = txn.amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(txn.amount))
            : String(txn.amount)
        note = txn.note
        type = txn.type
        currency = txn.currency
        selectedCategoryId = txn.categoryId
        selectedCreditCardId = txn.creditCardId

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsed = formatter.date(from: txn.date) {
            date = parsed
        }
    }

    private func save() async {
        guard let amount = Double(amountText), amount > 0 else {
            errorMessage = L("invalid_amount")
            return
        }

        isSubmitting = true
        errorMessage = nil

        do {
            if let txn = editingTransaction {
                try await viewModel.updateTransaction(
                    id: txn.id,
                    amount: amount, currency: currency, type: type,
                    note: note, date: date, categoryId: selectedCategoryId,
                    creditCardId: selectedCreditCardId
                )
            } else {
                try await viewModel.createTransaction(
                    amount: amount, currency: currency, type: type,
                    note: note, date: date, categoryId: selectedCategoryId,
                    creditCardId: selectedCreditCardId,
                    installments: installments
                )
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSave?()
            dismiss()
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
