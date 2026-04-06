import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var currencies: [CurrencyInfo] = []
    @Published var isExporting = false
    @Published var exportURL: URL?
    @Published var showExportSheet = false
    @Published var errorMessage: String?

    func loadCurrencies() async {
        do {
            let response: CurrencyListResponse = try await APIClient.shared.request(
                endpoint: "/currencies/supported"
            )
            currencies = response.currencies
        } catch {
            print("Failed to load currencies: \(error)")
        }
    }

    func updateCurrency(_ code: String) async {
        do {
            try await AuthService.shared.updateProfile(currency: code)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateLocale(_ locale: String) async {
        do {
            try await AuthService.shared.updateProfile(locale: locale)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportCSV() async {
        isExporting = true
        errorMessage = nil

        do {
            let data = try await APIClient.shared.downloadData(endpoint: "/export/csv")
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("monity-export-\(Date().timeIntervalSince1970).csv")
            try data.write(to: tempURL)
            exportURL = tempURL
            showExportSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isExporting = false
    }
}
