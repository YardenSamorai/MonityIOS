import Foundation

enum Constants {
    #if targetEnvironment(simulator)
    static let baseURL = "http://localhost:3000/api"
    #else
    static let baseURL = "https://monityios-production.up.railway.app/api"
    #endif

    static let keychainTokenKey = "monity_auth_token"

    enum Colors {
        static let primary = "AccentColor"
        static let income = "IncomeGreen"
        static let expense = "ExpenseRed"
    }
}
