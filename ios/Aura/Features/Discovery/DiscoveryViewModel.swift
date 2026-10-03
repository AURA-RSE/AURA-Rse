import Foundation
import Combine
import AVFoundation

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
    private var runningRequests: [String:String] = [:]
    private var positioningEpoch = 0
    private var positioningOperations = 0
    private var positioningRevision = 0
    private var positioningRequestIDs: [String:String] = [:]
    private var generation = 0
    private var observers = Set<AnyCancellable>()
    init() {
        positioning.onFailure = { [weak self] peer,message in
            Task { @MainActor in
                guard let self else { return };self.error=message
                if let request=self.requests.first(where:{$0.peer.wallet==peer}) { try? await self.dismiss(request) }
            }
        }
        scanner.onToken = { [weak self] peripheral,token,rssi in Task { await self?.resolve(peripheral,token,rssi) } }
        api.$token.dropFirst().sink { [weak self] token in if token == nil { self?.stopLocal();self?.profile = nil } }.store(in:&observers)
    }
    func perform(_ action: @escaping () async throws -> Void) { Task { error = nil;busy = true;defer { busy = false };do { try await action() } catch { self.error = error.localizedDescription } } }
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
        let presence:Presence = try await api.request("/api/presence",method:"POST",body:["event":selectedEvent,"rangingProtocol":positioning.supportsDistance ? "apple-ni-v2" : "","resetRanging":true])
        guard generation == current else { return }
        active = true;presenceExpires = Date(timeIntervalSince1970:presence.expires/1000);broadcaster.advertise(presence);scanner.start();statusMessage = "Discovering participating devices. Keep Aura open."
        tick?.cancel();tick = Task { [weak self] in
            var count = 0
            discoveryLoop: while !Task.isCancelled {
                do { try await Task.sleep(for:.seconds(1)) } catch { return }
                guard let self,self.active,self.generation == current else { return }
                self.peers.removeAll { Date().timeIntervalSince($0.lastSeen)>15 || $0.expires < Date().timeIntervalSince1970*1000 }
                for target in self.positioning.peerIDs where !self.peers.contains(where:{$0.id==target}) {
                    self.positioning.stop(peer:target);self.runningRequests.removeValue(forKey:target)
                    if let request=self.requests.first(where:{$0.peer.wallet==target}) { try? await self.dismiss(request) }
                }
                count += 1
                if count % 3 == 0 {
                    do {
                        let me:ProfileResponse = try await self.api.request("/api/me")
                        guard self.active,self.generation == current else { return }
                        self.profile = me.profile
                        if me.profile.status == "stealth" { await self.stop();return }
                        if self.presenceExpires.timeIntervalSinceNow < 40 {
                            let renewed:Presence = try await self.api.request("/api/presence",method:"POST",body:["event":self.selectedEvent,"rangingProtocol":self.positioning.supportsDistance ? "apple-ni-v2" : ""])
                            guard self.active,self.generation == current else { return }
                            self.presenceExpires = Date(timeIntervalSince1970:renewed.expires/1000);self.broadcaster.advertise(renewed)
                        }
                        if self.positioningOperations>0 { continue }
                        let revision=self.positioningRevision,spatial=self.positioningEpoch
                        let result:RangingResponse = try await self.api.request("/api/ranging")
                        guard self.active,self.generation == current else { return }
                        guard self.positioningOperations==0,self.positioningRevision==revision else { continue }
                        self.requests = result.requests
                        for request in result.requests where request.sender==self.profile?.wallet || request.recipient_token != nil {
                            if !self.positioning.peerIDs.contains(request.peer.wallet) { try? await self.dismiss(request);continue discoveryLoop }
                        }
                        for (peer,id) in self.positioningRequestIDs where !result.requests.contains(where:{$0.id==id}) { self.positioning.stop(peer:peer);self.runningRequests.removeValue(forKey:peer);self.positioningRequestIDs.removeValue(forKey:peer) }
                        for outgoing in result.requests where outgoing.sender==self.profile?.wallet {
                            guard self.active,self.generation==current,self.positioningEpoch==spatial else { continue discoveryLoop }
                            guard let token=outgoing.recipient_token,self.runningRequests[outgoing.peer.wallet] != outgoing.id else { continue }
                            // Local session tokens cannot be restored after a lifecycle reset.
                            guard self.positioning.peerIDs.contains(outgoing.peer.wallet) else { try? await self.dismiss(outgoing);continue }
                            do { try self.positioning.run(peer:outgoing.peer.wallet,peerToken:token);self.runningRequests[outgoing.peer.wallet]=outgoing.id }
                            catch { self.error=error.localizedDescription;try? await self.dismiss(outgoing);continue discoveryLoop }
                        }
                    } catch { self.error = error.localizedDescription;self.stopLocal();return }
                }
            }
        }
    }
    func stopLocal() { generation += 1;active = false;tick?.cancel();tick = nil;scanner.stop();broadcaster.stop();positioning.stop();peers = [];requests = [];runningRequests = [:];positioningRequestIDs = [:];positioningEpoch += 1;selectedPeer = nil;statusMessage = "Discovery paused. You are no longer broadcasting from this device." }
    func stop() async { stopLocal();guard api.token != nil else { return };do { let _:EmptyResponse = try await api.request("/api/presence",method:"DELETE",body:[:]) } catch { self.error = "Stopped on this phone. Server presence expires within 90 seconds if unreachable." } }
    private func resolve(_ peripheral:String,_ token:String,_ rssi:Int) async {
        guard active,!resolving.contains(token) else { return };resolving.insert(token);defer { resolving.remove(token) };let current = generation
        do {
            let result:ResolveResponse = try await api.request("/api/discovery/resolve",method:"POST",body:["token":token])
            guard active,current == generation,result.event == selectedEvent else { return }
            let peer = NearbyPeer(profile:result.profile,peripheralID:peripheral,lastSeen:Date(),expires:result.expires,rssi:rssi,rangingProtocol:result.rangingProtocol)
            peers.removeAll { $0.id == peer.id || $0.peripheralID == peripheral };peers.append(peer)
        } catch { peers.removeAll { $0.peripheralID == peripheral } }
    }
    private func cameraPermission() async throws {
        guard positioning.supportsDistance else { throw APIError.message("This phone does not support precise positioning.") }
        if positioning.supportsCamera {
            let permission=AVCaptureDevice.authorizationStatus(for:.video)
            if permission == .notDetermined { guard await AVCaptureDevice.requestAccess(for:.video) else { throw APIError.message("Camera access is needed for camera positioning.") } }
            else if permission != .authorized { throw APIError.message("Allow Camera for Aura in Settings to position profiles.") }
        }
    }
    func requestPosition(_ peer:AuraProfile) async throws {
        positioningOperations += 1;positioningRevision += 1
        defer { positioningOperations -= 1;positioningRevision += 1 }
        guard active,peers.contains(where:{$0.id==peer.wallet && $0.rangingProtocol=="apple-ni-v2"}) else { throw APIError.message("This participant is not advertising compatible positioning. Both phones need the updated iPhone app and active discovery.") }
        let current=generation,spatial=positioningEpoch
        try await cameraPermission()
        guard active,current==generation,spatial==positioningEpoch else { return }
        let token=try positioning.prepare(peer:peer.wallet)
        do {
            let reply:IDResponse=try await api.request("/api/ranging",method:"POST",body:["wallet":peer.wallet,"discoveryToken":token])
            guard active,current==generation,spatial==positioningEpoch else {
                let _:EmptyResponse=try await api.request("/api/ranging",method:"DELETE",body:["id":reply.id]);return
            }
            positioningRequestIDs[peer.wallet]=reply.id
            let result:RangingResponse=try await api.request("/api/ranging")
            if active,current==generation,spatial==positioningEpoch { requests=result.requests }
        } catch { if current==generation,spatial==positioningEpoch { positioning.stop(peer:peer.wallet) };throw error }
    }
    func accept(_ request:RangingRequest) async throws {
        positioningOperations += 1;positioningRevision += 1
        defer { positioningOperations -= 1;positioningRevision += 1 }
        guard active else { throw APIError.message("Start discovery before accepting.") }
        let current=generation,spatial=positioningEpoch
        try await cameraPermission()
        guard active,current==generation,spatial==positioningEpoch else { return }
        let token=try positioning.prepare(peer:request.sender)
        do {
            let _:EmptyResponse=try await api.request("/api/ranging/accept",method:"POST",body:["id":request.id,"discoveryToken":token])
            guard active,current==generation,spatial==positioningEpoch else {
                let _:EmptyResponse=try await api.request("/api/ranging",method:"DELETE",body:["id":request.id]);return
            }
            try positioning.run(peer:request.sender,peerToken:request.sender_token);runningRequests[request.sender]=request.id;positioningRequestIDs[request.sender]=request.id
            if let index=requests.firstIndex(where:{$0.id==request.id}) { requests[index]=RangingRequest(id:request.id,sender:request.sender,recipient:request.recipient,sender_token:request.sender_token,recipient_token:token,expires:request.expires,peer:request.peer) }
        } catch { if current==generation,spatial==positioningEpoch { positioning.stop(peer:request.sender) };try? await dismiss(request);throw error }
    }
    func dismiss(_ request:RangingRequest) async throws {
        positioningOperations += 1;positioningRevision += 1
        defer { positioningOperations -= 1;positioningRevision += 1 }
        positioning.stop(peer:request.peer.wallet);runningRequests.removeValue(forKey:request.peer.wallet);positioningRequestIDs.removeValue(forKey:request.peer.wallet);requests.removeAll{$0.id==request.id}
        let _:EmptyResponse=try await api.request("/api/ranging",method:"DELETE",body:["id":request.id])
    }
    func saveConnection(_ peer:AuraProfile,note:String) async throws { let _:EmptyResponse = try await api.request("/api/connections",method:"PUT",body:["wallet":peer.wallet,"note":note]);try await refresh() }
    func block(_ peer:AuraProfile) async throws { let _:EmptyResponse = try await api.request("/api/blocks",method:"POST",body:["wallet":peer.wallet]);peers.removeAll{$0.id==peer.wallet};selectedPeer = nil;positioning.stop(peer:peer.wallet);runningRequests.removeValue(forKey:peer.wallet);try await refresh() }
    func report(_ peer:AuraProfile,reason:String) async throws { let _:EmptyResponse = try await api.request("/api/reports",method:"POST",body:["wallet":peer.wallet,"reason":reason]) }
    func payment(_ peer:AuraProfile,amount:String) async throws -> URL { let result:PaymentRecord = try await api.request("/api/payments",method:"POST",body:["wallet":peer.wallet,"amount":amount]);return try WalletManager.paymentURL(id:result.id,api:api) }
    func endPositioning() async {
        positioningOperations += 1;positioningRevision += 1
        defer { positioningOperations -= 1;positioningRevision += 1 }
        positioningEpoch += 1;positioning.stop();runningRequests = [:];positioningRequestIDs = [:]
        let ending=requests;requests=[]
        for request in ending { do { let _:EmptyResponse = try await api.request("/api/ranging",method:"DELETE",body:["id":request.id]) } catch { self.error = error.localizedDescription } }
    }
    func logout() async { await stop();do { let _:EmptyResponse = try await api.request("/api/auth/logout",method:"POST",body:[:]) } catch { self.error = error.localizedDescription };api.clearSession();profile = nil;connections = [];payments = [];events = [];polling?.cancel() }
}
