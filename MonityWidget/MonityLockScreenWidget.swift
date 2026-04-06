import WidgetKit
import SwiftUI

struct LockScreenEntry: TimelineEntry {
    let date: Date
    let balance: Double
    let currency: String
    let isPlaceholder: Bool
}

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: .now, balance: 12500, currency: "ILS", isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let entry = makeEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func makeEntry() -> LockScreenEntry {
        if let data = WidgetDataLoader.load() {
            return LockScreenEntry(date: .now, balance: data.balance, currency: data.currency, isPlaceholder: false)
        }
        return LockScreenEntry(date: .now, balance: 0, currency: "ILS", isPlaceholder: true)
    }
}

struct LockScreenWidgetView: View {
    let entry: LockScreenEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            circularView
        }
    }

    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                Text(shortBalance)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.5)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
            Text(entry.isPlaceholder ? "---" : WidgetDataLoader.formatCurrency(entry.balance, currency: entry.currency))
                .font(.system(.body, design: .rounded).weight(.semibold))
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10))
                Text("Balance")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)

            Text(entry.isPlaceholder ? "---" : WidgetDataLoader.formatCurrency(entry.balance, currency: entry.currency))
                .font(.system(.body, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var shortBalance: String {
        guard !entry.isPlaceholder else { return "---" }
        let abs = abs(entry.balance)
        if abs >= 1_000_000 {
            return String(format: "%.1fM", entry.balance / 1_000_000)
        } else if abs >= 1_000 {
            return String(format: "%.0fK", entry.balance / 1_000)
        }
        return String(format: "%.0f", entry.balance)
    }
}

struct MonityLockScreenWidget: Widget {
    let kind = "MonityLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Balance")
        .description("Quick balance view.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}
