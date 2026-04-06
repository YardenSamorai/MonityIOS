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
    @State private var formAppeared = false
    @State private var showSuccess = false
    @State private var saveButtonScale: CGFloat = 1.0

    var editingTransaction: Transaction?
    var onSave: (() -> Void)?

    private var isEditing: Bool { editingTransaction != nil }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    typePicker
                        .staggeredAppear(appeared: formAppeared, index: 0)

                    CurrencyTextField(title: "amount", value: $amountText, currency: currency)
                        .staggeredAppear(appeared: formAppeared, index: 1)

                    SolidCard {
                        VStack(spacing: 0) {
                            fieldRow(icon: "pencil.line", label: "note_placeholder") {
                                TextField(type == .income ? L("note_placeholder_income") : L("note_placeholder"), text: $note)
                                    .font(.subheadline)
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
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Text("select_category")
                                            .font(.subheadline)
                                            .foregroundStyle(.tertiary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }

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
                        }
                    }

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                        }
                        .foregroundStyle(.red)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.4), value: errorMessage)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.2)) { saveButtonScale = 0.95 }
                        Task {
                            await save()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { saveButtonScale = 1.0 }
                        }
                    } label: {
                        ZStack {
                            if showSuccess {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.body.weight(.semibold))
                                    Text(isEditing ? "update" : "save")
                                        .font(.headline)
                                }
                                .transition(.scale.combined(with: .opacity))
                            } else if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text(isEditing ? "update" : "save")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(amountText.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(AppTheme.primaryGradient))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: amountText.isEmpty ? .clear : AppTheme.accent.opacity(0.3), radius: 12, y: 6)
                        .scaleEffect(saveButtonScale)
                    }
                    .disabled(isSubmitting || amountText.isEmpty)
                    .staggeredAppear(appeared: formAppeared, index: 3)

                    if isEditing {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.medium))
                                Text("delete_transaction")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.red)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "edit_transaction" : "add_transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
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
                formAppeared = true
            }
        }
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

    private var typePicker: some View {
        HStack(spacing: 0) {
            typeButton(.expense, label: "expense", icon: "arrow.up.right")
            typeButton(.income, label: "income", icon: "arrow.down.left")
        }
        .padding(4)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func typeButton(_ t: Transaction.TransactionType, label: LocalizedStringKey, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { type = t }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(label)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(type == t ? (t == .expense ? AppTheme.expenseGradient : AppTheme.incomeGradient) : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(type == t ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func fieldRow<Content: View>(icon: String, label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24)
            content()
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
                    creditCardId: selectedCreditCardId
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
