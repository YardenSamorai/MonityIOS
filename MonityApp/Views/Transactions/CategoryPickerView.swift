import SwiftUI

struct CategoryPickerView: View {
    let categories: [Category]
    @Binding var selectedId: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(categories) { category in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedId = category.id
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Text(category.icon)
                                .font(.title2)
                                .frame(width: 46, height: 46)
                                .background(Color(hex: category.color).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                            Text(category.localizedName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            Spacer()

                            if selectedId == category.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.accent)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(14)
                        .background(
                            selectedId == category.id
                                ? AppTheme.accent.opacity(0.06)
                                : Color(.secondarySystemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selectedId == category.id ? AppTheme.accent.opacity(0.3) : .clear, lineWidth: 1.5)
                        )
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("select_category")
        .navigationBarTitleDisplayMode(.inline)
    }
}
