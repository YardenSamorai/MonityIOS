import SwiftUI

/// Legacy empty state view used by older screens.
/// New screens should use `EmptyStateCard` from DesignComponents.swift.
struct EmptyStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        EmptyStateCard(icon: icon, title: title, message: message)
    }
}
