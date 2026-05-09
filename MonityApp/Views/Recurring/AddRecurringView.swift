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
            ZStack {
                CanvasBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        typePicker
                        amountInput
                        frequencyPicker
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
                                    Text("delete_recurring")
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
            .navigationTitle(isEditing ? "edit_recurring" : "add_recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    GlassIconButton(icon: "xmark", size: 32) { dismiss() }
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

    // MARK: - Type picker

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
            withAnimation(Motion.snappy) { type = t }
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

    // MARK: - Frequency picker

    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("frequency")
                .font(AppFont.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)

            HStack(spacing: 6) {
                ForEach(RecurringRule.Frequency.allCases, id: \.self) { freq in
                    let active = frequency == freq
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(Motion.snappy) { frequency = freq }
                    } label: {
                        Text(LocalizedStringKey(freq.rawValue))
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(active ? Color.white : Color.secondary)
                            .background(active ? BrandColor.primary : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(4)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Surface.separator.opacity(0.4), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Details card

    private var detailsCard: some View {
        GlassSurface(padding: 0) {
            VStack(spacing: 0) {
                fieldRow(icon: "pencil.line", label: "note") {
                    TextField(type == .income ? L("note_placeholder_income") : L("note_placeholder"), text: $note)
                        .font(AppFont.body)
                }

                Divider().padding(.leading, 52)

                fieldRow(icon: "calendar", label: type == .income ? "recurring_income_date" : "recurring_expense_date") {
                    VStack(alignment: .leading, spacing: 8) {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, LanguageManager.shared.locale)
                        Text("recurring_start_date_hint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider().padding(.leading, 52)

                fieldRow(icon: "calendar.badge.clock", label: "end_date") {
                    Toggle("", isOn: $hasEndDate.animation(Motion.snappy))
                        .labelsHidden()
                        .tint(BrandColor.primary)
                }

                if hasEndDate {
                    Divider().padding(.leading, 52)
                    fieldRow(icon: "flag.checkered", label: "end_date") {
                        DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .labelsHidden()
                    }
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
            Image(systemName: "exclamationmark.triangle.fill").font(.subheadline.weight(.bold))
            Text(message).font(AppFont.caption)
            Spacer()
        }
        .foregroundStyle(BrandColor.expense)
        .padding(12)
        .background(BrandColor.expense.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
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
