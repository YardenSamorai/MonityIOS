import Foundation

struct Category: Codable, Identifiable {
    let id: Int
    var name: String
    var nameHe: String?
    var icon: String
    var color: String
    var type: CategoryType
    var isDefault: Bool

    enum CategoryType: String, Codable {
        case expense
        case income
        case both
    }

    var localizedName: String {
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "he"
        if lang == "he", let he = nameHe, !he.isEmpty {
            return he
        }
        return name
    }
}

struct CategoryListResponse: Codable {
    let categories: [Category]
}

struct CategorySingleResponse: Codable {
    let category: Category
}
