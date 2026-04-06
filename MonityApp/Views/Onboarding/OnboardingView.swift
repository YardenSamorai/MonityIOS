import SwiftUI

// MARK: - Onboarding Flow (Post-Registration)

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager

    @State private var step = 0

    private let totalSteps = 4

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                if step > 0 && step < totalSteps - 1 {
                    progressBar
                        .padding(.top, 8)
                }

                switch step {
                case 0:
                    OnboardingWelcome(
                        userName: authService.currentUser?.name ?? "",
                        onNext: nextStep
                    )
                    .transition(pageTransition)
                case 1:
                    OnboardingLanguageStep(
                        languageManager: languageManager,
                        onNext: nextStep
                    )
                    .transition(pageTransition)
                case 2:
                    OnboardingBalanceStep(onNext: nextStep)
                        .transition(pageTransition)
                case 3:
                    OnboardingRecurringStep(onComplete: completeOnboarding)
                        .transition(pageTransition)
                default:
                    EmptyView()
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: step)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(1..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AppTheme.accent : Color(.systemGray4))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 8)
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private func nextStep() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        step += 1
    }

    private func completeOnboarding() {
        Task {
            try? await authService.completeOnboarding()
        }
    }
}

// MARK: - Step 0: Welcome

struct OnboardingWelcome: View {
    let userName: String
    let onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 100, height: 100)
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 20, y: 5)

                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)

            Spacer().frame(height: 32)

            VStack(spacing: 12) {
                Text(L("onb_welcome_title") + ", \(userName)!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)

                Text(L("onb_welcome_subtitle"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }

            Spacer()

            OnboardingButton(title: L("onb_lets_setup"), action: onNext)
                .padding(.horizontal, 40)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

            Spacer().frame(height: 60)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Step 1: Language

struct OnboardingLanguageStep: View {
    let languageManager: LanguageManager
    let onNext: () -> Void
    @State private var appeared = false
    @State private var selectedLang: String = "he"

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppTheme.primaryGradient)

                Text(L("onb_choose_language"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(L("onb_language_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer().frame(height: 40)

            VStack(spacing: 14) {
                languageOption(code: "he", flag: "🇮🇱", name: "עברית", subtitle: "Hebrew")
                languageOption(code: "en", flag: "🇺🇸", name: "English", subtitle: "אנגלית")
            }
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 15)

            Spacer()

            OnboardingButton(title: L("onboarding_next")) {
                languageManager.setLanguage(selectedLang)
                onNext()
            }
            .padding(.horizontal, 40)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 60)
        }
        .onAppear {
            selectedLang = languageManager.currentLanguage
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func languageOption(code: String, flag: String, name: String, subtitle: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3)) {
                selectedLang = code
            }
        } label: {
            HStack(spacing: 16) {
                Text(flag).font(.system(size: 36))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)

                Spacer()

                ZStack {
                    Circle()
                        .stroke(selectedLang == code ? AppTheme.accent : Color(.systemGray4), lineWidth: 2.5)
                        .frame(width: 24, height: 24)
                    if selectedLang == code {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 14, height: 14)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selectedLang == code ? AppTheme.accent.opacity(0.08) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(selectedLang == code ? AppTheme.accent.opacity(0.3) : .clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Step 2: Initial Balance

struct OnboardingBalanceStep: View {
    let onNext: () -> Void
    @State private var appeared = false
    @State private var balanceText = ""
    @State private var isSubmitting = false

    private var currency: String {
        AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppTheme.incomeGradient)

                Text(L("onb_balance_title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(L("onb_balance_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer().frame(height: 40)

            CurrencyTextField(title: "onb_current_balance", value: $balanceText, currency: currency)
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

            Spacer()

            VStack(spacing: 12) {
                OnboardingButton(title: L("onboarding_next")) {
                    Task { await saveBalance() }
                }

                Button(action: onNext) {
                    Text(L("onb_skip"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 60)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func saveBalance() async {
        guard let amount = Double(balanceText), amount > 0 else {
            onNext()
            return
        }

        isSubmitting = true
        let body: [String: Any] = [
            "amount": amount,
            "currency": currency,
            "type": "income",
            "note": L("onb_initial_balance_note"),
            "date": DateHelper.toAPIString(Date()),
        ]

        do {
            struct Resp: Codable { let transaction: Transaction }
            let _: Resp = try await APIClient.shared.request(
                endpoint: "/transactions",
                method: "POST",
                body: body
            )
        } catch {
            print("Balance save error: \(error)")
        }
        isSubmitting = false
        onNext()
    }
}

// MARK: - Step 3: Recurring Setup

struct OnboardingRecurringStep: View {
    let onComplete: () -> Void
    @State private var appeared = false
    @State private var recurringItems: [OnboardingRecurringItem] = []
    @State private var showAddSheet = false
    @State private var isSubmitting = false
    @StateObject private var viewModel = RecurringViewModel()

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 20)

            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppTheme.primaryGradient)

                Text(L("onb_recurring_title"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text(L("onb_recurring_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            Spacer().frame(height: 24)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if recurringItems.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "plus.circle.dashed")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text(L("onb_no_recurring_yet"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(recurringItems) { item in
                            recurringRow(item)
                        }
                    }

                    Button(action: { showAddSheet = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.accent)
                            Text(L("onb_add_recurring"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        )
                    }
                }
                .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)

            Spacer()

            VStack(spacing: 12) {
                OnboardingButton(
                    title: L("onb_finish"),
                    gradient: AppTheme.incomeGradient,
                    shadowColor: AppTheme.income
                ) {
                    Task { await submitAndComplete() }
                }
                .disabled(isSubmitting)

                if recurringItems.isEmpty {
                    Button(action: {
                        onComplete()
                    }) {
                        Text(L("onb_skip"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 40)
            .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 60)
        }
        .sheet(isPresented: $showAddSheet) {
            OnboardingAddRecurringSheet { item in
                recurringItems.append(item)
            }
        }
        .task {
            await viewModel.loadRules()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
    }

    private func recurringRow(_ item: OnboardingRecurringItem) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(item.type == .income ? AppTheme.income.opacity(0.12) : AppTheme.expense.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: item.type == .income ? "arrow.down.left" : "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(item.type == .income ? AppTheme.income : AppTheme.expense)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.note)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(L(item.frequency.rawValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyHelper.format(item.amount))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(item.type == .income ? AppTheme.income : AppTheme.expense)

            Button {
                withAnimation(.spring(response: 0.3)) {
                    recurringItems.removeAll { $0.id == item.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .transition(.scale.combined(with: .opacity))
    }

    private func submitAndComplete() async {
        isSubmitting = true

        for item in recurringItems {
            var body: [String: Any] = [
                "amount": item.amount,
                "currency": item.currency,
                "type": item.type.rawValue,
                "frequency": item.frequency.rawValue,
                "startDate": DateHelper.toAPIString(Date()),
                "note": item.note,
            ]
            if let catId = item.categoryId { body["categoryId"] = catId }

            do {
                let _: RecurringSingleResponse = try await APIClient.shared.request(
                    endpoint: "/recurring",
                    method: "POST",
                    body: body
                )
            } catch {
                print("Recurring save error: \(error)")
            }
        }

        isSubmitting = false
        onComplete()
    }
}

// MARK: - Add Recurring Sheet

struct OnboardingAddRecurringSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (OnboardingRecurringItem) -> Void

    @State private var type: Transaction.TransactionType = .expense
    @State private var amountText = ""
    @State private var note = ""
    @State private var frequency: RecurringRule.Frequency = .monthly
    @State private var selectedCategoryId: Int?
    @StateObject private var catViewModel = RecurringViewModel()

    private var currency: String {
        AuthService.shared.currentUser?.preferredCurrency ?? "ILS"
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    typePicker

                    CurrencyTextField(
                        title: "amount",
                        value: $amountText,
                        currency: currency
                    )

                    SolidCard {
                        VStack(spacing: 0) {
                            fieldRow(icon: "pencil.line") {
                                TextField(
                                    type == .income ? L("onb_recurring_note_income") : L("onb_recurring_note_expense"),
                                    text: $note
                                )
                                .font(.subheadline)
                            }

                            Divider().padding(.leading, 52)

                            NavigationLink {
                                CategoryPickerView(
                                    categories: catViewModel.categories.filter {
                                        $0.type.rawValue == type.rawValue || $0.type == .both
                                    },
                                    selectedId: $selectedCategoryId
                                )
                            } label: {
                                fieldRow(icon: "tag.fill") {
                                    if let cat = catViewModel.categories.first(where: { $0.id == selectedCategoryId }) {
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

                    frequencyPicker

                    Button {
                        addItem()
                    } label: {
                        Text(L("onb_add"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                (amountText.isEmpty || note.isEmpty)
                                    ? AnyShapeStyle(Color.gray.opacity(0.3))
                                    : AnyShapeStyle(AppTheme.primaryGradient)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(
                                color: (amountText.isEmpty || note.isEmpty) ? .clear : AppTheme.accent.opacity(0.3),
                                radius: 12, y: 6
                            )
                    }
                    .disabled(amountText.isEmpty || note.isEmpty)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L("onb_add_recurring"))
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
            .task {
                await catViewModel.loadRules()
            }
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
            .background(
                type == t
                    ? (t == .expense ? AppTheme.expenseGradient : AppTheme.incomeGradient)
                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing)
            )
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
                            .background(
                                frequency == freq
                                    ? AppTheme.primaryGradient
                                    : LinearGradient(colors: [Color(.secondarySystemBackground)], startPoint: .leading, endPoint: .trailing)
                            )
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

    private func addItem() {
        guard let amount = Double(amountText), amount > 0, !note.isEmpty else { return }

        let item = OnboardingRecurringItem(
            amount: amount,
            currency: currency,
            type: type,
            frequency: frequency,
            note: note,
            categoryId: selectedCategoryId
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onAdd(item)
        dismiss()
    }
}

// MARK: - Models

struct OnboardingRecurringItem: Identifiable {
    let id = UUID()
    let amount: Double
    let currency: String
    let type: Transaction.TransactionType
    let frequency: RecurringRule.Frequency
    let note: String
    let categoryId: Int?
}

// MARK: - Shared Button

struct OnboardingButton: View {
    let title: String
    var icon: String = "arrow.forward"
    var gradient: LinearGradient = AppTheme.primaryGradient
    var shadowColor: Color = AppTheme.accent
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.headline)
                Image(systemName: icon)
                    .font(.body.weight(.bold))
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(gradient)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: shadowColor.opacity(0.25), radius: 12, y: 6)
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { isPressed = false } }
        )
    }
}
