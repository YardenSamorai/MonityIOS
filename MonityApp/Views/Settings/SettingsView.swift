import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var appearanceManager: AppearanceManager
    @EnvironmentObject var biometricManager: BiometricAuthManager
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var householdViewModel = HouseholdViewModel()
    @State private var showLogoutAlert = false
    @State private var reminderDate = Date()

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
                        row(icon: "bell.badge.fill", color: BrandColor.warning, label: "daily_reminder") {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.dailyReminderEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted { notificationManager.dailyReminderEnabled = true }
                                        }
                                    } else { notificationManager.dailyReminderEnabled = false }
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
                                    } else { notificationManager.budgetAlertsEnabled = false }
                                }
                            ))
                            .labelsHidden()
                            .tint(BrandColor.primary)
                        }
                        Divider().padding(.leading, 56)
                        row(icon: "creditcard.fill", color: BrandColor.info, label: "card_reminders") {
                            Toggle("", isOn: Binding(
                                get: { notificationManager.cardReminderEnabled },
                                set: { newValue in
                                    if newValue {
                                        Task {
                                            let granted = await notificationManager.requestPermission()
                                            if granted { notificationManager.cardReminderEnabled = true }
                                        }
                                    } else { notificationManager.cardReminderEnabled = false }
                                }
                            ))
                            .labelsHidden()
                            .tint(BrandColor.primary)
                        }
                    }

                    settingsGroup(title: "household") {
                        NavigationLink {
                            if householdViewModel.hasHousehold {
                                HouseholdSettingsView(viewModel: householdViewModel)
                            } else {
                                HouseholdView()
                            }
                        } label: {
                            row(icon: "person.2.fill", color: BrandColor.info, label: "household_settings") {
                                trailingChevron(text: householdViewModel.hasHousehold ? (householdViewModel.household?.name ?? "") : L("household_not_set"))
                            }
                        }
                        .buttonStyle(.plain)
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
