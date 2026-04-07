import SwiftUI

struct HouseholdSettingsView: View {
    @ObservedObject var viewModel: HouseholdViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showLeaveAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let household = viewModel.household {
                    membersSection(household)

                    if (household.activeMembers.count) < 2 {
                        NavigationLink {
                            HouseholdInviteView(viewModel: viewModel)
                        } label: {
                            HStack {
                                Spacer()
                                Label("invite_partner", systemImage: "person.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                Spacer()
                            }
                            .padding(16)
                            .background(AppTheme.accent.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    leaveButton
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L("household_settings"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L("leave_household_confirm"), isPresented: $showLeaveAlert) {
            Button(L("cancel"), role: .cancel) {}
            Button(L("leave_household"), role: .destructive) {
                Task {
                    await viewModel.leaveHousehold()
                    dismiss()
                }
            }
        } message: {
            Text(viewModel.myMember?.isOwner == true
                 ? L("leave_household_owner_message")
                 : L("leave_household_message"))
        }
        .task { await viewModel.loadHousehold() }
    }

    private func membersSection(_ household: Household) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("household_members")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            SolidCard {
                VStack(spacing: 0) {
                    ForEach(Array((household.HouseholdMembers ?? []).enumerated()), id: \.element.id) { index, member in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(member.isOwner ? AppTheme.primaryGradient : AppTheme.incomeGradient)
                                    .frame(width: 40, height: 40)
                                Text(String(member.displayName.prefix(1)).uppercased())
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.displayName)
                                    .font(.subheadline.weight(.semibold))
                                if let email = member.User?.email ?? member.invitedEmail {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(member.isOwner ? L("household_owner") : L("household_member"))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(member.isOwner ? AppTheme.accent : .secondary)

                                if member.isPending {
                                    Text(L("status_pending"))
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.orange.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if index < (household.HouseholdMembers?.count ?? 1) - 1 {
                            Divider().padding(.leading, 70)
                        }
                    }
                }
            }
        }
    }

    private var leaveButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showLeaveAlert = true
        } label: {
            HStack {
                Spacer()
                Label(
                    viewModel.myMember?.isOwner == true ? "dissolve_household" : "leave_household",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
                Spacer()
            }
            .padding(16)
            .background(Color.red.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.top, 12)
    }
}
