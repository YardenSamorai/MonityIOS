import SwiftUI

struct CategoryPickerView: View {
    let categories: [Category]
    @Binding var selectedId: Int?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(categories) { category in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedId = category.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(Color(hex: category.color).opacity(0.15))
                                    Text(category.icon).font(.system(size: 20))
                                }
                                .frame(width: 42, height: 42)

                                Text(category.localizedName)
                                    .font(AppFont.body)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if selectedId == category.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(BrandColor.primary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                selectedId == category.id
                                    ? BrandColor.primarySoft
                                    : Surface.card
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .strokeBorder(
                                        selectedId == category.id ? BrandColor.primary.opacity(0.3) : Surface.separator.opacity(0.4),
                                        lineWidth: selectedId == category.id ? 1.5 : 0.5
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
        .navigationTitle("select_category")
        .navigationBarTitleDisplayMode(.inline)
    }
}
