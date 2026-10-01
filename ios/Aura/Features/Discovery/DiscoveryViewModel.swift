import Foundation
import Combine

@MainActor
final class DiscoveryViewModel: ObservableObject {
    let api = APIService.shared
    let broadcaster = BLEBroadcaster()
    let scanner = BLEScanner()
    let positioning = UWBSessionManager()
    @Published var profile: AuraProfile?
    @Published var events: [AuraEvent] = []
    @Published var selectedEvent = ""
    @Published var peers: [NearbyPeer] = []
    @Published var connections: [ConnectionRecord] = []
    @Published var payments: [PaymentRecord] = []
    @Published var requests: [RangingRequest] = []
    @Published var pairing: DeviceStart?
    @Published var busy = false
    @Published var active = false
    @Published var error: String?
    @Published var statusMessage = "Your presence is private until you start discovery."
    @Published var selectedPeer: AuraProfile?
    private var tick: Task<Void,Never>?
    private var polling: Task<Void,Never>?
    private var presenceExpires = Date.distantPast
    private var resolving = Set<String>()
    private var runningRequest: String?
    private var generation = 0
    private var observers = Set<AnyCancellable>()
    init() {
        scanner.onToken = { [weak self] peripheral,token,rssi in Task { await self?.resolve(peripheral,token,rssi) } }
        api.$token.dropFirst().sink { [weak self] token in if token == nil { self?.stopLocal();self?.profile = nil } }.store(in:&observers)
    }
    func perform(_ action: @escaping () async throws -> Void) { Task { busy = true;defer { busy = false };do { try await action() } catch { self.error = error.localizedDescription } } }
    func restore() async {
        guard api.token != nil else { return }
        do { let result:ProfileResponse = try await api.request("/api/me"); profile = result.profile;try await refresh() } catch { self.error = error.localizedDescription }
    }
    func pair(server:String) async throws {
        stopLocal();polling?.cancel();try api.configure(server:server)
        let result:DeviceStart = try await api.request("/api/device/start",method:"POST",body:[:]);pairing = result
        polling = Task { [weak self] in
            while !Task.isCancelled && Date().timeIntervalSince1970 * 1000 < result.expires {
                do {
                    try await Task.sleep(for:.seconds(2));guard !Task.isCancelled,let self else { return }
                    let reply:DevicePoll = try await self.api.request("/api/device/poll",method:"POST",body:["deviceSecret":result.deviceSecret])
                    if let token = reply.token { try self.api.authorize(token);self.profile = reply.profile;self.pairing = nil;try await self.refresh();return }
                } catch { if !Task.isCancelled { self?.error = error.localizedDescription };return }
            }
            self?.pairing = nil
        }
    }
    func refresh() async throws {
        let e:EventsResponse = try await api.request("/api/events");events = e.events
        if !events.contains(where:{$0.id == selectedEvent}) { selectedEvent = events.first?.id ?? "" }
        let c:ConnectionsResponse = try await api.request("/api/connections");connections = c.connections
        let p:PaymentsResponse = try await api.request("/api/payments");payments = p.payments
    }
    func save(_ value:AuraProfile) async throws {
        if value.status == "stealth" { stopLocal() }
        let result:ProfileResponse = try await api.request("/api/me",method:"PUT",body:value.payload);profile = result.profile
    }
    func join(code:String) async throws { let _:EmptyResponse = try await api.request("/api/events/join",method:"POST",body:["code":code]);try await refresh() }
    func start() async throws {
        guard !active,let profile,!profile.name.isEmpty,profile.status != "stealth",!selectedEvent.isEmpty else { throw APIError.message("Save your profile, choose a visible status, and join an event first.") }
        generation += 1;let current = generation
        let presence:Presence = try await api.request("/api/presence",method:"POST",body:["event":selectedEvent])
        guard generation == current else { return }
        active = true;presenceExpires = Date(timeIntervalSince1970:presence.expires/1000);broadcaster.advertise(presence);scanner.start();statusMessage = "Discovering participating devices. Keep Aura open."
        tick?.cancel();tick = Task { [weak self] in
            var count = 0
            while !Task.isCancelled {
                do { try await Task.sleep(for:.seconds(1)) } catch { return }
                guard let self,self.active,self.generation == current else { return }
                self.peers.removeAll { Date().timeIntervalSince($0.lastSeen)>15 || $0.expires < Date().timeIntervalSince1970*1000 }
                if let target = self.positioning.peerID,!self.peers.contains(where:{$0.id==target}) { self.positioning.stop();self.runningRequest = nil }
                count += 1
                if count % 3 == 0 {
                    do {
                        let me:ProfileResponse = try await self.api.request("/api/me")
                        guard self.active,self.generation == current else { return }
                        self.profile = me.profile
                        if me.profile.status == "stealth" { await self.stop();return }
                        if self.presenceExpires.timeIntervalSinceNow < 40 {
                            let renewed:Presence = try await self.api.request("/api/presence",method:"POST",body:["event":self.selectedEvent])
                            guard self.active,self.generation == current else { return }
                            self.presenceExpires = Date(timeIntervalSince1970:renewed.expires/1000);self.broadcaster.advertise(renewed)
                        }
                        let result:RangingResponse = try await self.api.request("/api/ranging")
                        guard self.active,self.generation == current else { return }
                        self.requests = result.requests
                        if let running = self.runningRequest,!result.requests.contains(where:{$0.id==running}) { self.positioning.stop();self.runningRequest = nil }
                        if let outgoing = result.requests.first(where:{$0.sender==self.profile?.wallet}),let token = outgoing.recipient_token,self.runningRequest != outgoing.id {
                            try self.positioning.run(peerToken:token);self.runningRequest = outgoing.id
                        }
                    } catch { self.error = error.localizedDescription;self.stopLocal();return }
                }
            }
        }
    }
    func stopLocal() { generation += 1;active = false;tick?.cancel();tick = nil;scanner.stop();broadcaster.stop();positioning.stop();peers = [];requests = [];runningRequest = nil;selectedPeer = nil;statusMessage = "Discovery paused. You are no longer broadcasting from this device." }
    func stop() async { stopLocal();guard api.token != nil else { return };do { let _:EmptyResponse = try await api.request("/api/presence",method:"DELETE",body:[:]) } catch { self.error = "Stopped on this phone. Server presence expires within 90 seconds if unreachable." } }
    private func resolve(_ peripheral:String,_ token:String,_ rssi:Int) async {
        guard active,!resolving.contains(token) else { return };resolving.insert(token);defer { resolving.remove(token) };let current = generation
        do {
            let result:ResolveResponse = try await api.request("/api/discovery/resolve",method:"POST",body:["token":token])
            guard active,current == generation,result.event == selectedEvent else { return }
            let peer = NearbyPeer(profile:result.profile,peripheralID:peripheral,lastSeen:Date(),expires:result.expires,rssi:rssi)
            peers.removeAll { $0.id == peer.id || $0.peripheralID == peripheral };peers.append(peer)
        } catch { peers.removeAll { $0.peripheralID == peripheral } }
    }
    func requestPosition(_ peer:AuraProfile) async throws {
        guard active else { throw APIError.message("Start discovery first.") }
        let token = try positioning.prepare(peer:peer.wallet)
        do { let _:IDResponse = try await api.request("/api/ranging",method:"POST",body:["wallet":peer.wallet,"discoveryToken":token]) }
        catch { positioning.stop();throw error }
    }
    func accept(_ request:RangingRequest) async throws {
        let token = try positioning.prepare(peer:request.sender)
        do { let _:EmptyResponse = try await api.request("/api/ranging/accept",method:"POST",body:["id":request.id,"discoveryToken":token]);try positioning.run(peerToken:request.sender_token);runningRequest = request.id }
        catch { positioning.stop();throw error }
    }
    func dismiss(_ request:RangingRequest) async throws { let _:EmptyResponse = try await api.request("/api/ranging",method:"DELETE",body:["id":request.id]);positioning.stop();runningRequest = nil;requests.removeAll{$0.id==request.id} }
    func saveConnection(_ peer:AuraProfile,note:String) async throws { let _:EmptyResponse = try await api.request("/api/connections",method:"PUT",body:["wallet":peer.wallet,"note":note]);try await refresh() }
    func block(_ peer:AuraProfile) async throws { let _:EmptyResponse = try await api.request("/api/blocks",method:"POST",body:["wallet":peer.wallet]);peers.removeAll{$0.id==peer.wallet};selectedPeer = nil;if positioning.peerID == peer.wallet { positioning.stop() };try await refresh() }
    func report(_ peer:AuraProfile,reason:String) async throws { let _:EmptyResponse = try await api.request("/api/reports",method:"POST",body:["wallet":peer.wallet,"reason":reason]) }
    func payment(_ peer:AuraProfile,amount:String) async throws -> URL { let result:PaymentRecord = try await api.request("/api/payments",method:"POST",body:["wallet":peer.wallet,"amount":amount]);return try WalletManager.paymentURL(id:result.id,api:api) }
    func endPositioning() async {
        positioning.stop();runningRequest = nil
        for request in requests { do { let _:EmptyResponse = try await api.request("/api/ranging",method:"DELETE",body:["id":request.id]) } catch { self.error = error.localizedDescription } }
        requests = []
    }
    func logout() async { await stop();do { let _:EmptyResponse = try await api.request("/api/auth/logout",method:"POST",body:[:]) } catch { self.error = error.localizedDescription };api.clearSession();profile = nil;connections = [];payments = [];events = [];polling?.cancel() }
}
