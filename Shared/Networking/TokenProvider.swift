import Foundation

// Genera y cachea el JWT de SOFSE. Ver api-reference sección 2 y sofse_client.py.
actor TokenProvider {
    static let shared = TokenProvider()

    private let base = "https://api-servicios.sofse.gob.ar/v1"
    private let session: URLSession
    private var cached: (token: String, exp: Date)?

    private let defaults: UserDefaults
    private let tokenKey = "sofse.jwt"
    private let expKey = "sofse.jwt.exp"

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = 60
            self.session = URLSession(configuration: cfg)
        }
        self.defaults = UserDefaults(suiteName: "group.com.alandaitch.anden") ?? .standard
    }

    // Devuelve el JWT crudo (sin 'Bearer'). Regenera si force o si venció.
    func token(force: Bool = false) async throws -> String {
        if !force, let t = validCached() { return t }
        return try await refresh()
    }

    private func validCached() -> String? {
        if let c = cached, c.exp.timeIntervalSinceNow > 60 { return c.token }
        if let t = defaults.string(forKey: tokenKey) {
            let exp = Date(timeIntervalSince1970: defaults.double(forKey: expKey))
            if exp.timeIntervalSinceNow > 60 {
                cached = (t, exp)
                return t
            }
        }
        return nil
    }

    private func refresh() async throws -> String {
        let creds = Self.generateCredentials()
        guard let url = URL(string: base + "/auth/authorize") else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "username": creds.username,
            "password": creds.password
        ])

        let data: Data
        let resp: URLResponse
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: (resp as? HTTPURLResponse)?.statusCode ?? -1,
                                body: String(data: data, encoding: .utf8))
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["token"] as? String else {
            throw APIError.unauthorized
        }
        let exp = Self.expiry(of: token) ?? Date(timeIntervalSinceNow: 86400)
        cached = (token, exp)
        defaults.set(token, forKey: tokenKey)
        defaults.set(exp.timeIntervalSince1970, forKey: expKey)
        return token
    }

    // MARK: - Algoritmo de credenciales (portado de sofse_client.py, verificado)

    private static let cipherTable: [(String, [String])] = [
        ("a", ["#t", "#j"]), ("e", ["#x", "#p"]), ("i", ["#f", "#w"]),
        ("o", ["#l", "#8"]), ("u", ["#7", "#0"]), ("=", ["#g", "#v"])
    ]

    private static func b64(_ s: String) -> String {
        Data(s.utf8).base64EncodedString()
    }

    private static func cipher(_ s: String, _ step: Int) -> String {
        var r = s
        for (ch, out) in cipherTable {
            r = r.replacingOccurrences(of: ch, with: out[step])
        }
        return r
    }

    // Réplica de urllib.parse.quote (safe='/'): sin codificar letras, dígitos, "_.-~/".
    private static func urlencode(_ s: String) -> String {
        var allowed = CharacterSet()
        allowed.insert(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-~/")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    static func generateCredentials(date: Date = Date()) -> (username: String, password: String) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let datestr = String(format: "%04d%02d%02dsofse", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let username = b64(datestr)
        var p = b64(username)
        p = cipher(p, 0)
        p = String(p.reversed())
        p = b64(p)
        p = cipher(p, 1)
        p = String(p.reversed())
        let password = urlencode(p)
        return (username, password)
    }

    static func expiry(of jwt: String) -> Date? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var b64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = obj["exp"] as? Double else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}
