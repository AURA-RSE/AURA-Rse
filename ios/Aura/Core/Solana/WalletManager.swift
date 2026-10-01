import Foundation

/// iOS holds an authenticated API session, not a signing key.
/// Signing takes place in the wallet-enabled web companion; receipts are verified by the server.
@MainActor
enum WalletManager {
    static func paymentURL(id:String,api:APIService) throws -> URL {
        guard var components = URLComponents(string:api.baseURL) else { throw APIError.message("Invalid server origin.") }
        components.queryItems = [URLQueryItem(name:"payment",value:id)]
        guard let url = components.url else { throw APIError.message("Invalid payment URL.") }
        return url
    }
    static func explorerURL(signature:String) -> URL? { URL(string:"https://explorer.solana.com/tx/\(signature)?cluster=devnet") }
}
