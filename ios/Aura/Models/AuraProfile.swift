import Foundation
import simd

struct AuraProfile: Codable, Identifiable, Equatable {
    var wallet: String
    var name: String
    var role: String
    var project: String
    var bio: String
    var link: String
    var video: String
    var intents: [String]
    var status: String
    var updated: Double
    var eventDirectory: Bool?
    var avatarMediaId: String?
    var videoMediaId: String?
    var id: String { wallet }
    var shortAddress: String { "\(wallet.prefix(6))…\(wallet.suffix(6))" }
    var statusLabel: String { status == "open" ? "Open to connect" : status == "heads-down" ? "Heads down" : "Stealth" }
    var payload: [String: Any] { ["eventDirectory":eventDirectory ?? false,"name":name,"role":role,"project":project,"bio":bio,"link":link,"video":video,"intents":intents,"status":status] }
}
struct AuraEvent: Codable, Identifiable { let id: String; let name: String; let owner: String? }
struct Presence: Decodable { let token: String; let expires: Double; let event: String }
struct DeviceStart: Decodable { let deviceSecret: String; let code: String; let expires: Double }
struct DevicePoll: Decodable { let state: String; let token: String?; let profile: AuraProfile? }
struct ProfileResponse: Decodable { let profile: AuraProfile }
struct ResolveResponse: Decodable { let profile: AuraProfile; let event: String; let expires: Double }
struct EventPeopleResponse: Decodable { let event: String; let profiles: [AuraProfile] }
struct EventsResponse: Decodable { let events: [AuraEvent] }
struct EmptyResponse: Decodable {}
struct ConnectionRecord: Decodable, Identifiable { let target: String; let note: String; let created: Double; let profile: AuraProfile; var id: String { target } }
struct ConnectionsResponse: Decodable { let connections: [ConnectionRecord] }
struct PaymentRecord: Decodable, Identifiable { let id: String; let sender: String; let recipient: String; let lamports: Int; let signature: String?; let expires: Double }
struct PaymentsResponse: Decodable { let payments: [PaymentRecord] }
struct RangingRequest: Decodable, Identifiable { let id: String; let sender: String; let recipient: String; let sender_token: String; let recipient_token: String?; let expires: Double; let peer: AuraProfile }
struct RangingResponse: Decodable { let requests: [RangingRequest] }
struct IDResponse: Decodable { let id: String }
struct NearbyPeer: Identifiable {
    var profile: AuraProfile
    var peripheralID: String
    var lastSeen: Date
    var expires: Double
    var rssi: Int
    var id: String { profile.wallet }
}
