import AppIntents
import Foundation

/// Quickly logs an expense to Monity. Designed for the Apple Pay / Wallet flow:
/// after a charge, the user runs this from the Action Button, Lock Screen, Siri, or a
/// Personal Automation, and the amount/place/date are POSTed to the existing
/// `/transactions` endpoint using the signed-in user's Keychain token — so no API key
/// or JWT ever needs to be stored inside the Shortcut.
struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log expense in Monity"
    static var description = IntentDescription(
        "Adds a new expense using the amount, place and date you provide.",
        categoryName: "Tracking"
    )

    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true

    @Parameter(title: "Amount")
    var amount: Double

    @Parameter(title: "Place / merchant", default: "")
    var place: String

    @Parameter(title: "Note", default: "")
    var note: String

    @Parameter(title: "Date")
    var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let token = AuthService.shared.token, !token.isEmpty else {
            throw MonityIntentError.notSignedIn
        }

        let trimmedPlace = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let composedNote: String
        switch (trimmedPlace.isEmpty, trimmedNote.isEmpty) {
        case (true, true):
            composedNote = "Apple Pay"
        case (false, true):
            composedNote = "Apple Pay · \(trimmedPlace)"
        case (true, false):
            composedNote = trimmedNote
        case (false, false):
            composedNote = "\(trimmedNote) · \(trimmedPlace)"
        }

        let resolvedDate = date ?? Date()
        let currency = AuthService.shared.currentUser?.preferredCurrency ?? "ILS"

        let viewModel = TransactionViewModel()
        try await viewModel.createTransaction(
            amount: amount,
            currency: currency,
            type: .expense,
            note: composedNote,
            date: resolvedDate,
            categoryId: nil
        )

        let formatted = CurrencyHelper.format(amount, currency: currency)
        let dialog: IntentDialog = trimmedPlace.isEmpty
            ? IntentDialog("Logged \(formatted) in Monity.")
            : IntentDialog("Logged \(formatted) at \(trimmedPlace) in Monity.")

        return .result(dialog: dialog)
    }
}

enum MonityIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notSignedIn

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notSignedIn:
            return "Open Monity, sign in, then run the shortcut again."
        }
    }
}

/// Surfaces ``LogExpenseIntent`` automatically in the Shortcuts app, Spotlight and Siri.
struct MonityAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogExpenseIntent(),
            phrases: [
                "Log expense in \(.applicationName)",
                "Add Apple Pay charge to \(.applicationName)",
                "New \(.applicationName) expense",
            ],
            shortTitle: "Log expense",
            systemImageName: "creditcard.fill"
        )
    }
}
