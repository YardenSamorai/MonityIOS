import SwiftUI

struct AddBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    var onSave: (() -> Void)?

    @State private var amountText = ""
    @State private var period: Budget.BudgetPeriod = .monthly
    @State private var selectedCategoryId: Int?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        amountInput

                        periodPicker

                        VStack(alignment: .leading, spacing: 8) {
                            Text("category")
                                .font(AppFont.label)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .padding(.leading, 4)

                            if categories.isEmpty {
                                GlassSurface {
                                    Text("all_categories_have_budgets")
                                        .font(AppFont.body)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                }
                            } else {
                                GlassSurface(padding: 0) {
                                    VStack(spacing: 0) {
                                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, cat in
                                            Button {
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                withAnimation(Motion.snappy) { selectedCategoryId = cat.id }
                                            } label: {
                                                HStack(spacing: 12) {
                                                    Text(cat.icon).font(.title3)
                                                    Text(cat.localizedName)
                                                        .font(AppFont.body)
                                                        .foregroundStyle(.primary)
                                                    Spacer()
                                                    if selectedCategoryId == cat.id {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .font(.system(size: 18, weight: .bold))
                                                            .foregroundStyle(BrandColor.primary)
                                                    } else {
                                                        Circle()
                                                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                                                            .frame(width: 18, height: 18)
                                                    }
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 12)
                                            }
                                            .buttonStyle(.plain)
                                            if index < categories.count - 1 {
                                                Divider().padding(.leading, 50)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        PrimaryButton(
                            title: "save",
                            icon: "checkmark",
                            isLoading: isSubmitting,
                            isDisabled: amountText.isEmpty || selectedCategoryId == nil
                        ) {
                            Task { await save() }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("add_budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    GlassIconButton(icon: "xmark", size: 32) { dismiss() }
                }
            }
        }
    }

    private var amountInput: some View {
        FeatureGlassCard(
            cornerRadius: Radius.xxl,
            padding: 24,
            gradient: LinearGradient(
                colors: [BrandColor.primary, BrandColor.primaryDeep],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            glowColor: BrandColor.primary
        ) {
            VStack(spacing: 8) {
                Text("budget_limit")
                    .font(AppFont.label)
                    .foregroundStyle(.white.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.5)
                CurrencyTextField(title: "", value: $amountText)
            }
        }
    }

    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("period")
                .font(AppFont.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)

            HStack(spacing: 4) {
                ForEach(Budget.BudgetPeriod.allCases, id: \.self) { p in
                    let active = period == p
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(Motion.snappy) { period = p }
                    } label: {
                        Text(LocalizedStringKey(p.rawValue))
                            .font(.subheadline.weight(.bold))
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

    private func save() async {
        guard let amount = Double(amountText), amount > 0 else {
            errorMessage = L("invalid_amount")
            return
        }
        guard let categoryId = selectedCategoryId else {
            errorMessage = L("select_category")
            return
        }
        isSubmitting = true
        errorMessage = nil
        do {
            let vm = BudgetViewModel()
            try await vm.createBudget(limitAmount: amount, period: period, categoryId: categoryId)
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
