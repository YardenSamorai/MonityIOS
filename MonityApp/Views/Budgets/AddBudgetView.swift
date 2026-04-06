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
            Form {
                Section("category") {
                    if categories.isEmpty {
                        Text("all_categories_have_budgets")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(categories) { cat in
                            Button {
                                selectedCategoryId = cat.id
                            } label: {
                                HStack {
                                    Text(cat.icon)
                                    Text(cat.localizedName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedCategoryId == cat.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("budget_limit") {
                    CurrencyTextField(title: "amount", value: $amountText)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section("period") {
                    Picker("period", selection: $period) {
                        ForEach(Budget.BudgetPeriod.allCases, id: \.self) { p in
                            Text(LocalizedStringKey(p.rawValue)).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("add_budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        Task { await save() }
                    }
                    .disabled(isSubmitting || amountText.isEmpty || selectedCategoryId == nil)
                    .fontWeight(.semibold)
                }
            }
        }
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
            onSave?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}
