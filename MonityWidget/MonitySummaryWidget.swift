import WidgetKit
import SwiftUI

struct SummaryEntry: TimelineEntry {
    let date: Date
    let balance: Double
    let income: Double
    let expense: Double
    let currency: String
    let month: String
    let isPlaceholder: Bool
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: .now, balance: 12500, income: 14700, expense: 3850, currency: "ILS", month: "April 2026", isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> SummaryEntry {
        if let data = WidgetDataLoader.load() {
            return SummaryEntry(date: .now, balance: data.balance, income: data.income, expense: data.expense, currency: data.currency, month: data.month, isPlaceholder: false)
        }
        return SummaryEntry(date: .now, balance: 0, income: 0, expense: 0, currency: "ILS", month: "", isPlaceholder: true)
    }
}

struct SummaryWidgetView: View {
    let entry: SummaryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue.opacity(0.8))
                Text("Monity")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !entry.month.isEmpty {
                    Text(entry.month)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text(entry.isPlaceholder ? "---" : WidgetDataLoader.formatCurrency(entry.balance, currency: entry.currency))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 16) {
                miniCard(
                    icon: "arrow.down.circle.fill",
                    color: .green,
                    label: "Income",
                    value: entry.income
                )
                miniCard(
                    icon: "arrow.up.circle.fill",
                    color: .red,
                    label: "Expenses",
                    value: entry.expense
                )
            }
        }
        .padding()
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func miniCard(icon: String, color: Color, label: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(entry.isPlaceholder ? "---" : WidgetDataLoader.formatCurrency(value, currency: entry.currency))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.fill.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MonitySummaryWidget: Widget {
    let kind = "MonitySummaryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SummaryProvider()) { entry in
            SummaryWidgetView(entry: entry)
        }
        .configurationDisplayName("Monthly Summary")
        .description("Balance, income, and expenses.")
        .supportedFamilies([.systemMedium])
    }
}
