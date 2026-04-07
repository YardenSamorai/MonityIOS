import SwiftUI

struct CreditCardListView: View {
    @StateObject private var viewModel = CreditCardViewModel()
    @State private var showAddCard = false
    @State private var appeared = false
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if viewModel.cards.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "creditcard",
                        title: "no_credit_cards",
                        message: "add_first_credit_card"
                    )
                } else {
                    VStack(spacing: 20) {
                        ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                            if isEditing {
                                HStack(spacing: 12) {
                                    VStack(spacing: 8) {
                                        Button {
                                            guard index > 0 else { return }
                                            withAnimation(.spring(response: 0.3)) {
                                                viewModel.cards.swapAt(index, index - 1)
                                            }
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            Task { await viewModel.saveCardOrder() }
                                        } label: {
                                            Image(systemName: "chevron.up")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(index > 0 ? AppTheme.accent : Color.gray.opacity(0.3))
                                                .frame(width: 32, height: 32)
                                                .background(Color(.systemGray5))
                                                .clipShape(Circle())
                                        }
                                        .disabled(index == 0)

                                        Button {
                                            guard index < viewModel.cards.count - 1 else { return }
                                            withAnimation(.spring(response: 0.3)) {
                                                viewModel.cards.swapAt(index, index + 1)
                                            }
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            Task { await viewModel.saveCardOrder() }
                                        } label: {
                                            Image(systemName: "chevron.down")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(index < viewModel.cards.count - 1 ? AppTheme.accent : Color.gray.opacity(0.3))
                                                .frame(width: 32, height: 32)
                                                .background(Color(.systemGray5))
                                                .clipShape(Circle())
                                        }
                                        .disabled(index == viewModel.cards.count - 1)
                                    }

                                    CreditCardVisual(card: card)
                                }
                                .transition(.opacity)
                            } else {
                                NavigationLink {
                                    CreditCardDetailView(cardId: card.id)
                                } label: {
                                    CreditCardVisual(card: card)
                                        .staggeredAppear(appeared: appeared, index: index)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        Task { await viewModel.deleteCard(card.id) }
                                    } label: {
                                        Label("delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("credit_cards")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if viewModel.cards.count > 1 {
                        Button {
                            withAnimation(.spring(response: 0.3)) { isEditing.toggle() }
                        } label: {
                            Text(isEditing ? "done" : "edit")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showAddCard = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.primaryGradient)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showAddCard) {
                AddCreditCardView {
                    Task { await viewModel.loadCards() }
                }
            }
            .refreshable { await viewModel.loadCards() }
            .task {
                await viewModel.loadCards()
                appeared = true
            }
        }
    }
}

struct CreditCardVisual: View {
    let card: CreditCard
    @State private var shimmerOffset: CGFloat = -1
    @State private var progressWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    if !card.lastFourDigits.isEmpty {
                        Text("•••• \(card.lastFourDigits)")
                            .font(.caption.weight(.medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                Image(systemName: "creditcard.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.bottom, 24)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("current_balance")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(CurrencyHelper.format(card.currentBalance ?? 0))
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("billing_day_label")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(card.billingDay)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                }
            }

            if let limit = card.creditLimit, limit > 0 {
                let progress = min((card.currentBalance ?? 0) / limit, 1.0)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.2))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.8))
                            .frame(width: max(geo.size.width * progressWidth, 0), height: 6)
                    }
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                            progressWidth = progress
                        }
                    }
                }
                .frame(height: 6)
                .padding(.top, 16)

                HStack {
                    Text(CurrencyHelper.format(card.currentBalance ?? 0))
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(CurrencyHelper.format(limit))
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 4)
            }
        }
        .padding(24)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardGradient)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.15), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset * 300)
                    .mask(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .shadow(color: Color(hex: card.color).opacity(0.4), radius: 16, y: 8)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).delay(0.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 1
            }
        }
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: card.color), Color(hex: card.color).opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
