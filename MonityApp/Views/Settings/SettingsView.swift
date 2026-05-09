import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var biometricManager: BiometricAuthManager
    @EnvironmentObject var invitationCenter: HouseholdInvitationCenter
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var householdViewModel = HouseholdViewModel()
    @State private var showLogoutAlert = false
    @State private var showResetAccountConfirm = false
    @State private var isResettingAccount = false
    @State private var reminderDate = Date()

    @AppStorage("budget_alert_threshold_pct") private var budgetAlertThresholdStored = 80
    @AppStorage("card_reminder_days_before") private var cardReminderDaysStored = 2
    @AppStorage("recurring_due_reminder_enabled") private var recurringDueReminderStored = false

    private var budgetThresholdPercent: Int {
        let v = budgetAlertThresholdStored
        if [80, 90, 100].contains(v) { return v }
        return 80
    }

    private var cardDaysBeforeClamped: Int {
        let v = cardReminderDaysStored
        if v < 1 { return 2 }
        return min(7, v)
    }

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    profileHeader

                    settingsGroup(title: "preferences") {
                        row(icon: "dollarsign.circle.fill", color: BrandColor.income, label: "currency") {
                            NavigationLink {
                                CurrencySelectionView(
                                    currencies: viewModel.currencies,
                                    selectedCode: authService.currentUser?.preferredCurrency ?? "ILS"
                                ) { code in
                                    Task { await viewModel.updateCurrency(code) }
                                }
                            } label: {
                                trailingChevron(text: authService.currentUser?.preferredCurrency ?? "ILS")
                            }
                        }
                        Divider().padding(.leading, 56)
                        row(icon: "globe", color: BrandColor.primary, label: "language") {
                            Picker("", selection: Binding(
                                get: { languageManager.currentLanguage },
                                set: { newLang in
                                    languageManager.setLanguage(newLang)
                                    Task { await viewModel.updateLocale(newLang) }
                                }
                            )) {
                                Text("עברית").tag("he")
                                Text("English").tag("en")
                            }
                            .pickerStyle(.menu)
                            .tint(.secondary)
                        }
                        Divider().padding(.leading, 56)
                        row(icon: appearanceManager.appearanceMode.icon, color: BrandColor.accent, label: "appearance") {
                            Picker("", selection: $appearanceManager.appearanceMode) {
                                ForEach(AppearanceManager.AppearanceMode.allCases, id: \.self) { mode in
                                    Label(mode.displayName, systemImage: mode.icon).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.secondary)
                        }
                    }

                    settingsGroup(title: "security") {
                        row(icon: biometricManager.biometricIcon, color: BrandColor.income, label: LocalizedStringKey(biometricManager.biometricName)) {
                            Toggle("", isOn: Binding(
                                get: { biometricManager.isEnabled },
                                set: { biometricManager.isEnabled = $0 }
                            ))
                            .labelsHidden()
                            .tint(BrandColor.primary)
                        }
                    }

                    settingsGroup(title: "notifications") {
                        Text("notifications_intro")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)

                        row(icon: "bell.badge.fill", color: BrandColor.warning, label: "daily_reminder") {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.dailyReminderEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted {
                                                notificationManager.dailyReminderEnabled = true
                                                await notificationManager.refreshCardAndRecurringFromServer()
                                            }
                                        }
                                    } else {
                                        notificationManager.dailyReminderEnabled = false
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(BrandColor.primary)
                        }
                        if notificationManager.dailyReminderEnabled {
                            Divider().padding(.leading, 56)
                            row(icon: "clock.fill", color: BrandColor.warning, label: "reminder_time") {
                                DatePicker("", selection: $reminderDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .onChange(of: reminderDate) { _, newValue in
                                        notificationManager.dailyReminderHour = Calendar.current.component(.hour, from: newValue)
                                    }
                            }
                        }

                        Divider().padding(.leading, 56)
                        row(icon: "exclamationmark.triangle.fill", color: BrandColor.expense, label: "budget_alerts") {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.budgetAlertsEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted { notificationManager.budgetAlertsEnabled = true }
                                        }
                                    } else {
                                        notificationManager.budgetAlertsEnabled = false
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(BrandColor.primary)
                        }
                        if notificationManager.budgetAlertsEnabled {
                            Divider().padding(.leading, 56)
                            row(icon: "percent", color: BrandColor.expense, label: "budget_alert_threshold_label") {
                                Picker("", selection: Binding(
                                    get: { budgetThresholdPercent },
                                    set: { budgetAlertThresholdStored = $0 }
                                )) {
                                    Text("80%").tag(80)
                                    Text("90%").tag(90)
                                    Text("100%").tag(100)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 260)
                            }
                        }

                        Divider().padding(.leading, 56)
                        row(icon: "creditcard.fill", color: BrandColor.info, label: "card_reminders") {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.cardReminderEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted {
                                                notificationManager.cardReminderEnabled = true
                                                await notificationManager.refreshCardAndRecurringFromServer()
                                            }
                                        }
                                    } else {
                                        notificationManager.cardReminderEnabled = false
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(BrandColor.primary)
                        }
                        if notificationManager.cardReminderEnabled {
                            Divider().padding(.leading, 56)
                            row(icon: "calendar.badge.clock", color: BrandColor.info, label: "card_reminder_days_label") {
                                Stepper(
                                    value: Binding(
                                        get: { cardDaysBeforeClamped },
                                        set: { newVal in
                                            cardReminderDaysStored = newVal
                                            Task { await notificationManager.refreshCardAndRecurringFromServer() }
                                        }
                                    ),
                                    in: 1...7
                                ) {
                                    Text("\(cardDaysBeforeClamped)")
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider().padding(.leading, 56)
                        row(icon: "arrow.triangle.2.circlepath", color: BrandColor.income, label: "recurring_reminder_toggle") {
                            Toggle("", isOn: Binding(
                                get: { recurringDueReminderStored },
                                set: { newValue in
                                    recurringDueReminderStored = newValue
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted {
                                                await notificationManager.refreshCardAndRecurringFromServer()
                                            } else {
                                                recurringDueReminderStored = false
                                            }
                                        }
                                    } else {
                                        notificationManager.cancelRecurringDueReminders()
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(BrandColor.primary)
                        }
                        if recurringDueReminderStored {
                            Text("recurring_reminder_footnote")
                                .font(AppFont.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 56)
                        }

                        Divider().padding(.leading, 56)
                        row(icon: "square.and.arrow.up.circle", color: BrandColor.accent, label: "export_reminder_monthly") {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.exportReminderEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted {
                                                notificationManager.exportReminderEnabled = true
                                            }
                                        }
                                    } else {
                                        notificationManager.exportReminderEnabled = false
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(BrandColor.primary)
                        }
                    }

                    settingsGroup(title: "household") {
                        NavigationLink {
                            Group {
                                if householdViewModel.hasHousehold {
                                    HouseholdSettingsView(viewModel: householdViewModel)
                                } else {
                                    HouseholdScreen(viewModel: householdViewModel)
                                }
                            }
                        } label: {
                            row(icon: "person.2.fill", color: BrandColor.info, label: "household_settings") {
                                trailingChevron(text: householdViewModel.hasHousehold ? (householdViewModel.household?.name ?? "") : L("household_not_set"))
                            }
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            HouseholdPermissionsInfoView()
                        } label: {
                            row(icon: "info.circle.fill", color: BrandColor.info, label: "household_permissions_link") {
                                trailingChevron()
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup(title: "productivity") {
                        NavigationLink {
                            SavingsGoalsListView()
                        } label: {
                            row(icon: "target", color: BrandColor.primary, label: "savings_goals_title") {
                                trailingChevron()
                            }
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            CategoryRulesListView()
                        } label: {
                            row(icon: "wand.and.stars", color: BrandColor.accent, label: "category_rules_title") {
                                trailingChevron()
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    settingsGroup(title: "reset_account_section") {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showResetAccountConfirm = true
                        } label: {
                            row(icon: "exclamationmark.triangle.fill", color: BrandColor.expense, label: "reset_account") {
                                if isResettingAccount {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                        .environment(\.layoutDirection, .leftToRight)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isResettingAccount)
                    }

                    settingsGroup(title: "data") {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            Task { await viewModel.exportCSV() }
                        } label: {
                            row(icon: "square.and.arrow.up.fill", color: BrandColor.expense, label: "export_csv") {
                                if viewModel.isExporting {
                                    ProgressView().scaleEffect(0.8)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                        .environment(\.layoutDirection, .leftToRight)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isExporting)

                        NavigationLink {
                            PrivacyPolicyView()
                        } label: {
                            row(icon: "hand.raised.fill", color: BrandColor.primary, label: "privacy_policy_title") {
                                trailingChevron()
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showLogoutAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("logout").font(.subheadline.weight(.bold))
                        }
                        .foregroundStyle(BrandColor.expense)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(BrandColor.expense.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    }

                    Text("Monity v1.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
        .alert(L("reset_account_confirm_title"), isPresented: $showResetAccountConfirm) {
            Button(L("cancel"), role: .cancel) {}
            Button(L("reset_account_button"), role: .destructive) {
                Task {
                    isResettingAccount = true
                    await viewModel.resetAccountData()
                    isResettingAccount = false
                    if viewModel.errorMessage == nil {
                        await authService.refreshProfile()
                        await invitationCenter.refresh()
                    }
                    await householdViewModel.loadHousehold()
                }
            }
        } message: {
            Text(L("reset_account_confirm_message"))
        }
        .alert("error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("ok", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .navigationTitle("settings")
        .alert("logout_confirm", isPresented: $showLogoutAlert) {
            Button("cancel", role: .cancel) {}
            Button("logout", role: .destructive) { authService.logout() }
        } message: {
            Text("logout_message")
        }
        .sheet(isPresented: $viewModel.showExportSheet) {
            if let url = viewModel.exportURL {
                ShareSheet(items: [url])
            }
        }
        .task {
            await viewModel.loadCurrencies()
            await householdViewModel.loadHousehold()
            var comps = DateComponents()
            comps.hour = notificationManager.dailyReminderHour
            comps.minute = 0
            reminderDate = Calendar.current.date(from: comps) ?? Date()
        }
    }

    private var profileHeader: some View {
        GlassSurface(elevation: .raised) {
            HStack(spacing: 14) {
                if let user = authService.currentUser {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [BrandColor.primary, BrandColor.primaryDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 54, height: 54)
                    .shadow(color: BrandColor.primary.opacity(0.35), radius: 8, y: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.name)
                            .font(AppFont.titleS)
                        Text(user.email)
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private func settingsGroup<Content: View>(title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)

            GlassSurface(padding: 0) {
                VStack(spacing: 0) {
                    content()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func row<Trailing: View>(icon: String, color: Color, label: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.13))
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(AppFont.body)
                .foregroundStyle(.primary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func trailingChevron() -> some View {
        trailingChevron(text: "")
    }

    private func trailingChevron(text: String) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(AppFont.bodyS)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}

// MARK: - Currency Selection

struct CurrencySelectionView: View {
    let currencies: [CurrencyInfo]
    let selectedCode: String
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(currencies) { currency in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSelect(currency.code)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(BrandColor.primary.opacity(0.12))
                                    Text(currency.symbol)
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(BrandColor.primary)
                                }
                                .frame(width: 42, height: 42)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(currency.code)
                                        .font(AppFont.label)
                                    Text(currency.name)
                                        .font(AppFont.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if currency.code == selectedCode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(BrandColor.primary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(currency.code == selectedCode ? BrandColor.primarySoft : Surface.card)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(
                                        currency.code == selectedCode ? BrandColor.primary.opacity(0.3) : Surface.separator.opacity(0.4),
                                        lineWidth: currency.code == selectedCode ? 1.5 : 0.5
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("select_currency")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
