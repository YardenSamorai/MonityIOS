import SwiftUI

struct HouseholdSetupView: View {
    @ObservedObject var viewModel: HouseholdViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var householdName = ""
    @State private var partnerEmail = ""
    @State private var step: SetupStep = .create

    enum SetupStep {
        case create
        case invite
        case done
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch step {
                case .create:
                    createStep
                case .invite:
                    inviteStep
                case .done:
                    doneStep
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L("create_household"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("cancel")) { dismiss() }
                }
            }
            .alert(L("error"), isPresented: .constant(viewModel.errorMessage != nil)) {
                Button(L("ok")) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Create Step

    private var createStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryGradient)
                            .frame(width: 80, height: 80)
                        Image(systemName: "house.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 20)

                    Text("household_setup_title")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("household_setup_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("household_name")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField(L("household_name_placeholder"), text: $householdName)
                        .font(.body)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        let name = householdName.isEmpty ? "משק בית" : householdName
                        await viewModel.createHousehold(name: name)
                        if viewModel.hasHousehold {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                step = .invite
                            }
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isCreating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("onboarding_next")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(viewModel.isCreating)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Invite Step

    private var inviteStep: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.incomeGradient)
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 20)

                    Text("invite_partner_title")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("invite_partner_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("email")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField(L("partner_email_placeholder"), text: $partnerEmail)
                        .font(.body)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 24)

                if let success = viewModel.successMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.income)
                        Text(success)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.income)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.income.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task {
                            await viewModel.invitePartner(email: partnerEmail)
                        }
                    } label: {
                        HStack {
                            if viewModel.isInviting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                                Text("send_invitation")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            partnerEmail.isEmpty
                                ? LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                                : AppTheme.primaryGradient
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(partnerEmail.isEmpty || viewModel.isInviting)

                    Button {
                        dismiss()
                    } label: {
                        Text("household_skip_invite")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Done Step

    private var doneStep: some View {
        VStack(spacing: 24) {
            Spacer()

            SuccessCheckmark(color: AppTheme.income)
                .frame(width: 80, height: 80)

            Text("household_created_success")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text("household_created_message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.primaryGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Invite View (standalone from settings)

struct HouseholdInviteView: View {
    @ObservedObject var viewModel: HouseholdViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.incomeGradient)
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }

                    Text("invite_partner_title")
                        .font(.title3.weight(.bold))

                    Text("invite_partner_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text("email")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField(L("partner_email_placeholder"), text: $email)
                        .font(.body)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let success = viewModel.successMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.income)
                        Text(success)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.income)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.income.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if let error = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if (viewModel.household?.pendingMembers ?? []).count > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("pending_invitations")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(viewModel.household?.pendingMembers ?? []) { member in
                            HStack(spacing: 10) {
                                Image(systemName: "clock.fill")
                                    .foregroundStyle(.orange)
                                Text(member.invitedEmail ?? "")
                                    .font(.subheadline)
                                Spacer()
                                Text(L("status_pending"))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task {
                        await viewModel.invitePartner(email: email)
                        if viewModel.successMessage != nil {
                            email = ""
                            await viewModel.loadHousehold()
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isInviting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("send_invitation")
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        email.isEmpty
                            ? LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                            : AppTheme.primaryGradient
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(email.isEmpty || viewModel.isInviting)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L("invite_partner"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            viewModel.successMessage = nil
            viewModel.errorMessage = nil
        }
    }
}
