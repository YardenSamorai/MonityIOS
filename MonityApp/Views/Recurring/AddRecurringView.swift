import SwiftUI

struct AddRecurringView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = RecurringViewModel()

    @State private var amountText = ""
    @State private var note = ""
    @State private var type: Transaction.TransactionType = .expense
    @State private var frequency: RecurringRule.Frequency = .monthly
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()
    @State private var selectedCategoryId: Int?
    @State private var currency = AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    var editingRule: RecurringRule?
    var onSave: (() -> Void)?

    private var isEditing: Bool { editingRule != nil }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    typePicker

                    CurrencyTextField(title: "amount", value: $amountText, currency: currency)

                    frequencyPicker

                    SolidCard {
                        VStack(spacing: 0) {
                            fieldRow(icon: "pencil.line") {
                                TextField(type == .income ? L("note_placeholder_income") : L("note_placeholder"), text: $note)
                                    .font(.subheadline)
                            }

                            Divider().padding(.leading, 52)

                            fieldRow(icon: "calendar") {
                                DatePicker("start_date", selection: $startDate, displayedComponents: .date)
                                    .font(.subheadline)
                            }

                            Divider().padding(.leading, 52)

                            fieldRow(icon: "calendar.badge.clock") {
                                Toggle("end_date", isOn: $hasEndDate.animation(.spring(response: 0.3)))
                                    .font(.subheadline)
                                    .tint(AppTheme.accent)
                            }

                            if hasEndDate {
                                Divider().padding(.leading, 52)
                                fieldRow(icon: "flag.checkered") {
                                    DatePicker("end_date", selection: $endDate, in: startDate..., displayedComponents: .date)
                                        .font(.subheadline)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
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
                                fieldRow(icon: "tag.fill") {
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
                        }
                    }

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill").font(.caption)
                            Text(error).font(.caption)
                        }
                        .foregroundStyle(.red)
                        .transition(.opacity)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task { await save() }
                    } label: {
                        ZStack {
                            if isSubmitting {
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
                    }
                    .disabled(isSubmitting || amountText.isEmpty)

                    if isEditing {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.subheadline.weight(.medium))
                                Text("delete_recurring")
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
            .navigationTitle(isEditing ? "edit_recurring" : "add_recurring")
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
            .confirmationDialog(L("delete_recurring_confirm"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button(L("delete"), role: .destructive) {
                    guard let rule = editingRule else { return }
                    Task {
                        await viewModel.deleteRule(rule.id)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onSave?()
                        dismiss()
                    }
                }
            } message: {
                Text("delete_recurring_message")
            }
            .task {
                await viewModel.loadRules()
                if let rule = editingRule {
                    populateFields(from: rule)
                }
            }
        }
    }

    private func populateFields(from rule: RecurringRule) {
        amountText = rule.amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rule.amount))
            : String(rule.amount)
        note = rule.note
        type = rule.type
        currency = rule.currency
        frequency = rule.frequency
        selectedCategoryId = rule.categoryId

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let parsed = formatter.date(from: rule.startDate) {
            startDate = parsed
        }
        if let end = rule.endDate, let parsed = formatter.date(from: end) {
            hasEndDate = true
            endDate = parsed
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
                Image(systemName: icon).font(.caption.weight(.bold))
                Text(label).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(type == t ? (t == .expense ? AppTheme.expenseGradient : AppTheme.incomeGradient) : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(type == t ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("frequency")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 8) {
                ForEach(RecurringRule.Frequency.allCases, id: \.self) { freq in
                    Button {
                        withAnimation(.spring(response: 0.3)) { frequency = freq }
                    } label: {
                        Text(LocalizedStringKey(freq.rawValue))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(frequency == freq ? AppTheme.primaryGradient : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .leading, endPoint: .trailing))
                            .foregroundStyle(frequency == freq ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }

    private func fieldRow<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
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
            if let rule = editingRule {
                try await viewModel.updateRule(
                    id: rule.id,
                    amount: amount, currency: currency, type: type,
                    frequency: frequency, startDate: startDate,
                    endDate: hasEndDate ? endDate : nil,
                    categoryId: selectedCategoryId, note: note
                )
            } else {
                try await viewModel.createRule(
                    amount: amount, currency: currency, type: type,
                    frequency: frequency, startDate: startDate,
                    endDate: hasEndDate ? endDate : nil,
                    categoryId: selectedCategoryId, note: note
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
