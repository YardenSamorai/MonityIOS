import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var biometricManager: BiometricAuthManager
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showLogoutAlert = false
    @State private var reminderDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    profileHeader

                    settingsGroup(title: "preferences") {
                        settingsRow(icon: "dollarsign.circle.fill", iconGradient: AppTheme.incomeGradient, label: "currency") {
                            NavigationLink {
                                CurrencySelectionView(
                                    currencies: viewModel.currencies,
                                    selectedCode: authService.currentUser?.preferredCurrency ?? "ILS"
                                ) { code in
                                    Task { await viewModel.updateCurrency(code) }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(authService.currentUser?.preferredCurrency ?? "ILS")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }

                        Divider().padding(.leading, 52)

                        settingsRow(icon: "globe", iconGradient: AppTheme.primaryGradient, label: "language") {
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

                        Divider().padding(.leading, 52)

                        settingsRow(icon: appearanceManager.appearanceMode.icon, iconGradient: LinearGradient(colors: [Color(hex: "6C63FF"), Color(hex: "A29BFE")], startPoint: .topLeading, endPoint: .bottomTrailing), label: "appearance") {
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
                        settingsRow(
                            icon: biometricManager.biometricIcon,
                            iconGradient: LinearGradient(colors: [Color(hex: "00B894"), Color(hex: "4ECDC4")], startPoint: .topLeading, endPoint: .bottomTrailing),
                            label: LocalizedStringKey(biometricManager.biometricName)
                        ) {
                            Toggle("", isOn: Binding(
                                get: { biometricManager.isEnabled },
                                set: { newValue in
                                    biometricManager.isEnabled = newValue
                                }
                            ))
                            .tint(AppTheme.accent)
                        }
                    }

                    settingsGroup(title: "notifications") {
                        settingsRow(
                            icon: "bell.badge.fill",
                            iconGradient: LinearGradient(colors: [Color(hex: "FDCB6E"), Color(hex: "E17055")], startPoint: .topLeading, endPoint: .bottomTrailing),
                            label: "daily_reminder"
                        ) {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.dailyReminderEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted {
                                                notificationManager.dailyReminderEnabled = true
                                            }
                                        }
                                    } else {
                                        notificationManager.dailyReminderEnabled = false
                                    }
                                }
                            ))
                            .tint(AppTheme.accent)
                        }

                        if notificationManager.dailyReminderEnabled {
                            Divider().padding(.leading, 52)
                            settingsRow(
                                icon: "clock.fill",
                                iconGradient: LinearGradient(colors: [Color(hex: "FDCB6E"), Color(hex: "E17055")], startPoint: .topLeading, endPoint: .bottomTrailing),
                                label: "reminder_time"
                            ) {
                                DatePicker("", selection: $reminderDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .onChange(of: reminderDate) { _, newValue in
                                        notificationManager.dailyReminderHour = Calendar.current.component(.hour, from: newValue)
                                    }
                            }
                        }

                        Divider().padding(.leading, 52)

                        settingsRow(
                            icon: "exclamationmark.triangle.fill",
                            iconGradient: AppTheme.expenseGradient,
                            label: "budget_alerts"
                        ) {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.budgetAlertsEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted {
                                                notificationManager.budgetAlertsEnabled = true
                                            }
                                        }
                                    } else {
                                        notificationManager.budgetAlertsEnabled = false
                                    }
                                }
                            ))
                            .tint(AppTheme.accent)
                        }

                        Divider().padding(.leading, 52)

                        settingsRow(
                            icon: "creditcard.fill",
                            iconGradient: LinearGradient(colors: [Color(hex: "2D3436"), Color(hex: "636E72")], startPoint: .topLeading, endPoint: .bottomTrailing),
                            label: "card_reminders"
                        ) {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.cardReminderEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted {
                                                notificationManager.cardReminderEnabled = true
                                            }
                                        }
                                    } else {
                                        notificationManager.cardReminderEnabled = false
                                    }
                                }
                            ))
                            .tint(AppTheme.accent)
                        }
                    }

                    settingsGroup(title: "data") {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            Task { await viewModel.exportCSV() }
                        } label: {
                            settingsRow(icon: "square.and.arrow.up.fill", iconGradient: AppTheme.expenseGradient, label: "export_csv") {
                                if viewModel.isExporting {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .disabled(viewModel.isExporting)

                        Divider().padding(.leading, 52)

                        NavigationLink {
                            BudgetListView()
                        } label: {
                            settingsRow(icon: "chart.bar.doc.horizontal.fill", iconGradient: AppTheme.primaryGradient, label: "manage_budgets") {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        Divider().padding(.leading, 52)

                        NavigationLink {
                            RecurringListView()
                        } label: {
                            settingsRow(icon: "arrow.triangle.2.circlepath", iconGradient: AppTheme.incomeGradient, label: "manage_recurring") {
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("logout", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    Text("Monity v1.0")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                        .padding(.top, 8)
                }
                .padding(20)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
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
                var comps = DateComponents()
                comps.hour = notificationManager.dailyReminderHour
                comps.minute = 0
                reminderDate = Calendar.current.date(from: comps) ?? Date()
            }
        }
    }

    private var profileHeader: some View {
        SolidCard {
            HStack(spacing: 16) {
                if let user = authService.currentUser {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 56, height: 56)
                        Text(String(user.name.prefix(1)).uppercased())
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.headline)
                        Text(user.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
            .padding(18)
        }
    }

    private func settingsGroup<Content: View>(title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            SolidCard(cornerRadius: 18) {
                VStack(spacing: 0) {
                    content()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func settingsRow<Trailing: View>(icon: String, iconGradient: LinearGradient, label: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(iconGradient)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct CurrencySelectionView: View {
    let currencies: [CurrencyInfo]
    let selectedCode: String
    var onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(currencies) { currency in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelect(currency.code)
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Text(currency.symbol)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.accent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(currency.code)
                                    .font(.subheadline.weight(.semibold))
                                Text(currency.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if currency.code == selectedCode {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(14)
                        .background(
                            currency.code == selectedCode
                                ? AppTheme.accent.opacity(0.06)
                                : Color(.secondarySystemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
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
