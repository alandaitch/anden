import Foundation

// Credenciales de la API Transporte BA. Se leen de Secrets.plist en Bundle.main.
// El widget NO incluye Secrets.plist en su bundle: ahí isConfigured == false.
enum BASecrets {
    // Carga perezosa del plist. nil si falta el archivo (no crashea).
    private static let dict: [String: Any]? = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let map = plist as? [String: Any]
        else { return nil }
        return map
    }()

    static var clientId: String { (dict?["BAClientId"] as? String) ?? "" }
    static var clientSecret: String { (dict?["BAClientSecret"] as? String) ?? "" }

    // true solo si ambas claves existen y no están vacías.
    static var isConfigured: Bool {
        !clientId.isEmpty && !clientSecret.isEmpty
    }

    // Devuelve "client_id=..&client_secret=..".
    static func authQuery() -> String {
        "client_id=\(clientId)&client_secret=\(clientSecret)"
    }
}
