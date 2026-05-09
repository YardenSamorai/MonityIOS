import SwiftUI

struct CreditCardListView: View {
    @StateObject private var viewModel = CreditCardViewModel()
    @State private var showAddCard = false
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground()

                if viewModel.cards.isEmpty && !viewModel.isLoading {
                    EmptyStateCard(
                        icon: "creditcard",
                        title: "no_credit_cards",
                        message: "add_first_credit_card",
                        actionTitle: "add_card",
                        action: { showAddCard = true }
                    )
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            if viewModel.cards.count > 1, isEditing {
                                Text("reorder_hint")
                                    .font(AppFont.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }

                            ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                                cardItem(card: card, index: index)
                            }
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 110)
                    }
                    .refreshable { await viewModel.loadCards() }
                }
            }
            .navigationTitle("credit_cards")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.cards.count > 1 {
                        Button {
                            withAnimation(Motion.smooth) { isEditing.toggle() }
                        } label: {
                            Text(isEditing ? "done" : "edit")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BrandColor.primary)
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    FloatingPlusButton { showAddCard = true }
                }
            }
            .sheet(isPresented: $showAddCard) {
                AddCreditCardView { Task { await viewModel.loadCards() } }
            }
            .task { await viewModel.loadCards() }
        }
    }

    @ViewBuilder
    private func cardItem(card: CreditCard, index: Int) -> some View {
        if isEditing {
            HStack(spacing: 12) {
                VStack(spacing: 6) {
                    arrowButton(direction: "up", enabled: index > 0) {
                        guard index > 0 else { return }
                        withAnimation(Motion.snappy) { viewModel.cards.swapAt(index, index - 1) }
                        Task { await viewModel.saveCardOrder() }
                    }
                    arrowButton(direction: "down", enabled: index < viewModel.cards.count - 1) {
                        guard index < viewModel.cards.count - 1 else { return }
                        withAnimation(Motion.snappy) { viewModel.cards.swapAt(index, index + 1) }
                        Task { await viewModel.saveCardOrder() }
                    }
                }
                CreditCardVisual(card: card)
            }
        } else {
            NavigationLink {
                CreditCardDetailView(cardId: card.id)
            } label: {
                CreditCardVisual(card: card)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button(role: .destructive) {
                    Task { await viewModel.deleteCard(card.id) }
                } label: {
                    Label("delete", systemImage: "trash")
                }
            }
        }
    }

    private func arrowButton(direction: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: direction == "up" ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(enabled ? BrandColor.primary : Color.secondary.opacity(0.4))
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .disabled(!enabled)
    }
}

// MARK: - Credit Card Visual

struct CreditCardVisual: View {
    let card: CreditCard
    var displayBalance: Double?

    private var effectiveBalance: Double {
        displayBalance ?? card.currentBalance ?? 0
    }

    private var cardColor: Color {
        Color(hex: card.color)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if !card.lastFourDigits.isEmpty {
                        Text("• • • •  \(card.lastFourDigits)")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.85))
                            .tracking(2)
                    }
                }
                Spacer()
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.bottom, 28)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("current_balance")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(CurrencyHelper.format(effectiveBalance))
                        .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("billing_day_label")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text("\(card.billingDay)")
                        .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
            }

            if let limit = card.creditLimit, limit > 0 {
                let progress = min(effectiveBalance / limit, 1.0)
                progressBar(progress: progress, limit: limit)
                    .padding(.top, 16)
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(
                        colors: [cardColor, cardColor.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)

                GeometryReader { geo in
                    Ellipse()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.7)
                        .offset(x: -geo.size.width * 0.2, y: -geo.size.height * 0.5)
                        .blur(radius: 30)
                        .blendMode(.plusLighter)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: cardColor.opacity(0.4), radius: 18, y: 10)
        .shadow(color: cardColor.opacity(0.2), radius: 4, y: 2)
    }

    private func progressBar(progress: Double, limit: Double) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.18)).frame(height: 6)
                    Capsule().fill(Color.white.opacity(0.85)).frame(width: max(geo.size.width * progress, 0), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("\(L("limit")): \(CurrencyHelper.format(limit))")
                    .font(.system(size: 10, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}
