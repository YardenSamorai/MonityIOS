import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    @State private var tabBounce: [Int: Bool] = [:]

    var body: some View {
        TabView(selection: tabSelection) {
            DashboardView()
                .tabItem {
                    Label("dashboard", systemImage: "house.fill")
                }
                .tag(0)

            TransactionListView()
                .tabItem {
                    Label("transactions", systemImage: "list.bullet.rectangle")
                }
                .tag(1)

            CreditCardListView()
                .tabItem {
                    Label("credit_cards", systemImage: "creditcard.fill")
                }
                .tag(2)

            ChartsView()
                .tabItem {
                    Label("charts", systemImage: "chart.pie.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(.accentColor)
    }

    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == selectedTab {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                selectedTab = newValue
            }
        )
    }
}
