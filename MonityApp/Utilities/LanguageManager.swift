import SwiftUI

@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @AppStorage("app_language") var currentLanguage: String = "he" {
        didSet { applyLanguage() }
    }

    @Published var locale: Locale = Locale(identifier: "he")
    @Published var layoutDirection: LayoutDirection = .rightToLeft

    private(set) var bundle: Bundle = .main

    private init() {
        applyLanguage()
    }

    func setLanguage(_ code: String) {
        currentLanguage = code
    }

    private func applyLanguage() {
        locale = Locale(identifier: currentLanguage)
        layoutDirection = currentLanguage == "he" ? .rightToLeft : .leftToRight
        if let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
        } else {
            bundle = .main
        }
    }

    var isHebrew: Bool { currentLanguage == "he" }
}

func L(_ key: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "app_language") ?? "he"
    if let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    return NSLocalizedString(key, comment: "")
}
