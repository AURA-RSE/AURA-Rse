import Foundation
import Security
import Combine

@MainActor
final class APIService: ObservableObject {
    static let shared = APIService()
    @Published private(set) var token: String?
    @Published private(set) var baseURL: String
    init() {
        baseURL = UserDefaults.standard.string(forKey: "aura.server") ?? "http://localhost:4317"
        token = KeychainService.read(account: baseURL)
    }
    func configure(server: String) throws {
        let value = server.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: value), url.host != nil, url.user == nil, url.password == nil, url.query == nil, url.fragment == nil, url.path.isEmpty else { throw APIError.message("Enter the server origin, without a path.") }
        #if DEBUG
        guard ["http", "https"].contains(url.scheme ?? "") else { throw APIError.message("Use an HTTP or HTTPS server.") }
        #else
        guard url.scheme == "https" else { throw APIError.message("Release builds require HTTPS.") }
        #endif
        #if !targetEnvironment(simulator)
        guard !["localhost", "127.0.0.1", "::1", "[::1]"].contains(url.host?.lowercased() ?? "") else {
            throw APIError.message("This address points to your iPhone. Enter the Aura server address supplied by your pilot host. For a local pilot, connect the phone and Mac to the same Wi-Fi.")
        }
        #endif
        baseURL = value
        UserDefaults.standard.set(value, forKey: "aura.server")
        token = KeychainService.read(account: value)
    }
    func checkServer() async throws {
        struct Health: Decodable { let status: String; let cluster: String }
        let health: Health = try await request("/api/health")
        guard health.status == "ok", health.cluster == "devnet" else { throw APIError.message("This address is not an available Aura devnet pilot.") }
    }
    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await URLSession.shared.data(for: request) }
        catch let error as URLError {
            if error.code == .cancelled { throw error }
            if [.timedOut, .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed, .dataNotAllowed].contains(error.code) {
                throw APIError.connection("Cannot reach Aura at \(baseURL). Check the address and your connection. For a local pilot, keep the Mac running, use the same Wi-Fi, and allow Local Network access for Aura in Settings.")
            }
            throw error
        }
    }
    func authorize(_ value: String) throws { try KeychainService.save(value, account: baseURL); token = value }
    func media(_ id:String) async throws -> Data {
        guard let url = URL(string:baseURL + "/api/media/" + id) else { throw APIError.message("Invalid media URL.") }
        var request = URLRequest(url:url);request.timeoutInterval = 30
        if let token { request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization") }
        let (data,response) = try await send(request)
        guard let http = response as? HTTPURLResponse,http.statusCode == 200 else { throw APIError.message("Media unavailable.") }
        return data
    }
    func clearSession() { KeychainService.remove(account: baseURL); token = nil }
    func request<T: Decodable>(_ path: String, method: String = "GET", body: [String:Any]? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.message("Invalid server address.") }
        var request = URLRequest(url: url)
        request.httpMethod = method; request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else { throw APIError.message("No server response.") }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String:Any])?["error"] as? String
            if http.statusCode == 401 { clearSession() }
            throw APIError.message(message ?? "Request failed (\(http.statusCode)).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
enum APIError: LocalizedError {
    case message(String), connection(String)
    var errorDescription: String? { switch self { case .message(let message), .connection(let message): return message } }
}
enum KeychainService {
    private static func query(_ account: String) -> [String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"com.Waliu.Aura.session",kSecAttrAccount as String:account] }
    static func read(account: String) -> String? {
        var q = query(account); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?; guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ token: String, account: String) throws {
        remove(account: account); var q = query(account)
        q[kSecValueData as String] = Data(token.utf8); q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(q as CFDictionary, nil) == errSecSuccess else { throw APIError.message("Could not securely save this session.") }
    }
    static func remove(account: String) { SecItemDelete(query(account) as CFDictionary) }
}
