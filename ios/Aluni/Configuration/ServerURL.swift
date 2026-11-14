import Foundation

/// The Rails server this build talks to (BASE_URL from the xcconfig through
/// Info.plist) and the locale-prefixed paths the shell starts from.
enum ServerURL {
    static var base: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String, !value.isEmpty else {
            return "https://aluni.us"
        }
        return value
    }

    static var locale: String { Locale.preferredAppLocale }
    static var homePath: String { "/\(locale)/app" }
    static var accountPath: String { "/\(locale)/passkeys" }
    static var signInPath: String { "/\(locale)/sign_in" }
}

extension Locale {
    /// The app speaks English and Spanish; anything else falls back to English.
    static var preferredAppLocale: String {
        Locale.preferredLanguages.first?.hasPrefix("es") == true ? "es" : "en"
    }
}
