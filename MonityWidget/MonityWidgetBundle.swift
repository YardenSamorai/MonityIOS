import WidgetKit
import SwiftUI

@main
struct MonityWidgetBundle: WidgetBundle {
    var body: some Widget {
        MonityBalanceWidget()
        MonitySummaryWidget()
        MonityLockScreenWidget()
    }
}
