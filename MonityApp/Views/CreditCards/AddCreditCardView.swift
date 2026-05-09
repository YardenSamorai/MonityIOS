import SwiftUI

struct AddCreditCardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreditCardViewModel()

    @State private var name = ""
    @State private var lastFourDigits = ""
    @State private var billingDay = 10
    @State private var hasLimit = false
    @State private var limitText = ""
    @State private var selectedColor = "#0A6B5F"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var onSave: (() -> Void)?

    private let cardColors = [
        "#0A6B5F", "#044238", "#1A8F73", "#C8924A",
        "#4A88C8", "#C84A4A", "#E84393", "#2D3436",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        cardPreview

                        formCard

                        colorPickerSection

                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        PrimaryButton(
                            title: "save",
                            icon: "checkmark",
                            isLoading: isSubmitting,
                            isDisabled: name.isEmpty
                        ) {
                            Task { await save() }
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("add_credit_card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    GlassIconButton(icon: "xmark", size: 32) { dismiss() }
                }
            }
        }
    }

    private var cardPreview: some View {
        let color = Color(hex: selectedColor)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(name.isEmpty ? L("card_name_placeholder") : name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Text(lastFourDigits.isEmpty ? "• • • •" : "• • • •  \(lastFourDigits)")
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
                .tracking(2)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("billing_day_label")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text("\(billingDay)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
            }
            .padding(.top, 8)
        }
        .frame(height: 170)
        .padding(22)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [color, color.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: color.opacity(0.4), radius: 18, y: 10)
        .animation(Motion.smooth, value: selectedColor)
    }

    private var formCard: some View {
        GlassSurface(padding: 0) {
            VStack(spacing: 0) {
                fieldRow(icon: "creditcard", label: "card_name") {
                    TextField(L("card_name_placeholder"), text: $name)
                        .font(AppFont.body)
                }
                Divider().padding(.leading, 52)
                fieldRow(icon: "number", label: "last_4_digits") {
                    TextField(L("last_four_digits"), text: $lastFourDigits)
                        .font(AppFont.body.monospacedDigit())
                        .keyboardType(.numberPad)
                        .onChange(of: lastFourDigits) { _, newVal in
                            if newVal.count > 4 { lastFourDigits = String(newVal.prefix(4)) }
                        }
                }
                Divider().padding(.leading, 52)
                fieldRow(icon: "calendar.badge.clock", label: "billing_day") {
                    Picker("", selection: $billingDay) {
                        ForEach(1...28, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                }
                Divider().padding(.leading, 52)
                fieldRow(icon: "gauge.with.dots.needle.33percent", label: "credit_limit") {
                    Toggle("", isOn: $hasLimit.animation(Motion.snappy))
                        .labelsHidden()
                        .tint(BrandColor.primary)
                }
                if hasLimit {
                    Divider().padding(.leading, 52)
                    fieldRow(icon: "sheqelsign", label: "limit_amount") {
                        TextField(L("limit_amount"), text: $limitText)
                            .font(AppFont.body)
                            .keyboardType(.decimalPad)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("card_color")
                .font(AppFont.label)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)

            GlassSurface(padding: 16) {
                HStack(spacing: 10) {
                    ForEach(cardColors, id: \.self) { hex in
                        let isSelected = selectedColor == hex
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(Motion.snappy) { selectedColor = hex }
                        } label: {
                            ZStack {
                                Circle().fill(Color(hex: hex))
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 34, height: 34)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: isSelected ? 2 : 0)
                                    .padding(-3)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(Color(hex: hex).opacity(isSelected ? 0.6 : 0), lineWidth: 2)
                                    .padding(-5)
                            )
                            .scaleEffect(isSelected ? 1.1 : 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
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
            Text(message).font(AppFont.caption)
            Spacer()
        }
        .foregroundStyle(BrandColor.expense)
        .padding(12)
        .background(BrandColor.expense.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
    }

    private func save() async {
        guard !name.isEmpty else {
            errorMessage = L("fill_all_fields")
            return
        }
        isSubmitting = true
        errorMessage = nil
        let limit = hasLimit ? Double(limitText) : nil
        do {
            try await viewModel.createCard(
                name: name, lastFourDigits: lastFourDigits,
                billingDay: billingDay, creditLimit: limit, color: selectedColor
            )
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
