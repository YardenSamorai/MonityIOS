import WidgetKit
import SwiftUI

struct BalanceEntry: TimelineEntry {
    let date: Date
    let balance: Double
    let currency: String
    let month: String
    let isPlaceholder: Bool
}

struct BalanceProvider: TimelineProvider {
    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, balance: 12500, currency: "ILS", month: "April 2026", isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> Void) {
        let entry = makeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func makeEntry() -> BalanceEntry {
        if let data = WidgetDataLoader.load() {
            return BalanceEntry(date: .now, balance: data.balance, currency: data.currency, month: data.month, isPlaceholder: false)
        }
        return BalanceEntry(date: .now, balance: 0, currency: "ILS", month: "", isPlaceholder: true)
    }
}

struct BalanceWidgetView: View {
    let entry: BalanceEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue.opacity(0.8))
                Text("Monity")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            Text(entry.isPlaceholder ? "---" : WidgetDataLoader.formatCurrency(entry.balance, currency: entry.currency))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(.primary)

            if !entry.month.isEmpty {
                Text(entry.month)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct MonityBalanceWidget: Widget {
    let kind = "MonityBalanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BalanceProvider()) { entry in
            BalanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Balance")
        .description("Your current balance at a glance.")
        .supportedFamilies([.systemSmall])
    }
}
