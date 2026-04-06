import SwiftUI

struct AddCreditCardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreditCardViewModel()

    @State private var name = ""
    @State private var lastFourDigits = ""
    @State private var billingDay = 10
    @State private var hasLimit = false
    @State private var limitText = ""
    @State private var selectedColor = "#6C63FF"
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var onSave: (() -> Void)?

    private let cardColors = [
        "#6C63FF", "#E17055", "#00B894", "#0984E3",
        "#D63031", "#E84393", "#FDCB6E", "#2D3436",
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    cardPreview

                    SolidCard {
                        VStack(spacing: 0) {
                            fieldRow(icon: "creditcard") {
                                TextField("card_name_placeholder", text: $name)
                                    .font(.subheadline)
                            }

                            Divider().padding(.leading, 52)

                            fieldRow(icon: "number") {
                                TextField("last_four_digits", text: $lastFourDigits)
                                    .font(.subheadline)
                                    .keyboardType(.numberPad)
                                    .onChange(of: lastFourDigits) { _, newVal in
                                        if newVal.count > 4 {
                                            lastFourDigits = String(newVal.prefix(4))
                                        }
                                    }
                            }

                            Divider().padding(.leading, 52)

                            fieldRow(icon: "calendar.badge.clock") {
                                HStack {
                                    Text("billing_day")
                                        .font(.subheadline)
                                    Spacer()
                                    Picker("", selection: $billingDay) {
                                        ForEach(1...28, id: \.self) { day in
                                            Text("\(day)").tag(day)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.secondary)
                                }
                            }

                            Divider().padding(.leading, 52)

                            fieldRow(icon: "gauge.with.dots.needle.33percent") {
                                Toggle("credit_limit", isOn: $hasLimit.animation(.spring(response: 0.3)))
                                    .font(.subheadline)
                                    .tint(AppTheme.accent)
                            }

                            if hasLimit {
                                Divider().padding(.leading, 52)
                                fieldRow(icon: "sheqelsign") {
                                    TextField("limit_amount", text: $limitText)
                                        .font(.subheadline)
                                        .keyboardType(.decimalPad)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }

                    colorPicker

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
                                Text("save")
                                    .font(.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(name.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(AppTheme.primaryGradient))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: name.isEmpty ? .clear : AppTheme.accent.opacity(0.3), radius: 12, y: 6)
                    }
                    .disabled(isSubmitting || name.isEmpty)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("add_credit_card")
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
        }
    }

    private var cardPreview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(name.isEmpty ? L("card_name_placeholder") : name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Text(lastFourDigits.isEmpty ? "••••" : "•••• \(lastFourDigits)")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))

            HStack {
                Text("billing_day_label")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(billingDay)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 180)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(hex: selectedColor), Color(hex: selectedColor).opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(color: Color(hex: selectedColor).opacity(0.4), radius: 16, y: 8)
        )
        .animation(.easeInOut(duration: 0.3), value: selectedColor)
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("card_color")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 12) {
                ForEach(cardColors, id: \.self) { hex in
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedColor = hex }
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: selectedColor == hex ? 3 : 0)
                                    .padding(2)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(hex: hex).opacity(0.5), lineWidth: selectedColor == hex ? 2 : 0)
                            )
                            .scaleEffect(selectedColor == hex ? 1.15 : 1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
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
        guard !name.isEmpty else {
            errorMessage = L("fill_all_fields")
            return
        }

        isSubmitting = true
        errorMessage = nil

        let limit = hasLimit ? Double(limitText) : nil

        do {
            try await viewModel.createCard(
                name: name,
                lastFourDigits: lastFourDigits,
                billingDay: billingDay,
                creditLimit: limit,
                color: selectedColor
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
