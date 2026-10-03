import SwiftUI
import AVKit
import AVFoundation
struct DiscoveryView: View {
    @ObservedObject var model: DiscoveryViewModel
    @State private var query = ""
    @State private var intent = "All"
    @State private var showCamera = false
    @State private var showEventPeople = false
    @State private var presentation = "Floating"
    var filtered:[NearbyPeer] { model.peers.filter { p in (intent == "All" || p.profile.intents.contains(intent)) && (query.isEmpty || "\(p.profile.name) \(p.profile.role) \(p.profile.project)".localizedCaseInsensitiveContains(query)) }.sorted { a,b in
        let order = a.profile.name.localizedCaseInsensitiveCompare(b.profile.name)
        return order == .orderedSame ? a.id < b.id : order == .orderedAscending
    } }
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment:.leading,spacing:22) {
            AuraBrand()
            HStack { Text("THE ROOM IS YOURS.").font(.caption2).tracking(2).foregroundStyle(AuraTheme.lime);Spacer();Text("DEVNET").font(.caption2.monospaced()).foregroundStyle(.secondary) }
            Text("Builders around you.").font(.system(size:36,weight:.semibold)).tracking(-1)
            Text("Find a collaborator. Meet your next team.").font(.subheadline).foregroundStyle(.secondary)
            Picker("Event",selection:$model.selectedEvent) { Text("Choose an event").tag("");ForEach(model.events) { Text($0.name).tag($0.id) } }.disabled(model.active)
            Button { showCamera = true } label: { Label("Open room camera",systemImage:"camera.fill").frame(maxWidth:.infinity) }.buttonStyle(.borderedProminent).foregroundStyle(.black)
            Button { showEventPeople = true } label: { Label("People at this event",systemImage:"person.2.fill").frame(maxWidth:.infinity) }.buttonStyle(.bordered).disabled(model.selectedEvent.isEmpty)
            HStack {
                Button(model.active ? "Pause discovery" : "Start discovery ↗") { model.perform { if model.active { await model.stop() } else { try await model.start() } } }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(model.busy)
            }
            DiscoveryStatus(broadcaster:model.broadcaster,scanner:model.scanner,message:model.statusMessage)
            ForEach(model.requests) { r in VStack(alignment:.leading,spacing:10) {
                Text(r.recipient == model.profile?.wallet ? "\(r.peer.name) requested positioning" : "Positioning with \(r.peer.name)").font(.headline)
                Text("Shares device distance and direction for up to two minutes.").font(.caption).foregroundStyle(.secondary)
                HStack { if r.recipient == model.profile?.wallet && r.recipient_token == nil { Button("Accept") { model.perform { try await model.accept(r) } } };Button("Stop / decline") { model.perform { try await model.dismiss(r) } } }
            }.padding().background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14)) }
            TextField("Search people, roles, projects",text:$query).textFieldStyle(.roundedBorder)
            Picker("Intent",selection:$intent) { ForEach(["All","Building","Hiring","Fundraising","Looking for a team","Offering feedback","Open to connect"],id:\.self) { Text($0).tag($0) } }
            Picker("Nearby view",selection:$presentation) { Text("Floating").tag("Floating");Text("List").tag("List") }.pickerStyle(.segmented)
            HStack { Text(model.active ? "LIVE IN YOUR EVENT" : "DISCOVERY PAUSED").font(.caption2).tracking(2);Spacer();Text("\(filtered.count) nearby").font(.caption).foregroundStyle(AuraTheme.lime) }
            Text("Opt-in profiles discovered nearby. Cards are arranged for browsing; exact positions are not shown.").font(.caption).foregroundStyle(.secondary)
            if filtered.isEmpty {
                ContentUnavailableView(!model.active ? "Choose when to be seen" : model.peers.isEmpty ? "Your next connection is nearby" : "Try another filter",systemImage:"person.2.wave.2",description:Text(!model.active ? "Join an event in My Aura and choose a visible status to start." : model.peers.isEmpty ? "Keep both phones open in the same event. Profiles appear when their devices are discovered." : "No nearby profiles match this search and intent."))
            } else if presentation == "Floating" {
                NearbyProfileField(peers:filtered) { model.selectedPeer = $0 }
            } else {
                ForEach(filtered) { peer in Button { model.selectedPeer = peer.profile } label: { HStack(alignment:.top,spacing:15) {
                    NearbyAvatar(profile:peer.profile,size:48)
                    VStack(alignment:.leading,spacing:7) { Text(peer.profile.name).font(.headline).foregroundStyle(.white);Text([peer.profile.role,peer.profile.project].filter{!$0.isEmpty}.joined(separator:" · ")).font(.subheadline).foregroundStyle(.secondary);Text(peer.profile.statusLabel).font(.caption).foregroundStyle(peer.profile.status == "open" ? AuraTheme.lime : .orange) }
                    Spacer();Image(systemName:"arrow.up.right").foregroundStyle(.secondary)
                }.padding(18).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:18)) } .buttonStyle(.plain) }
            }
        }.padding(24) }.background(AuraTheme.background).navigationBarHidden(true).sheet(isPresented:$showEventPeople) { EventPeopleView(model:model) }.fullScreenCover(isPresented:$showCamera) { CameraSheet(model:model,positioning:model.positioning) } }
    }
}
struct DiscoveryStatus:View {
    @ObservedObject var broadcaster:BLEBroadcaster
    @ObservedObject var scanner:BLEScanner
    let message:String
    var body:some View { VStack(alignment:.leading,spacing:5) { Text(message);Text("Bluetooth: \(scanner.isScanning ? "scanning" : "paused") · Presence: \(broadcaster.isAdvertising ? "broadcasting" : "off")");if let error = scanner.error ?? broadcaster.error { Text(error).foregroundStyle(.orange) } }.font(.caption).foregroundStyle(.secondary) }
}
struct CameraSheet:View {
    @ObservedObject var model:DiscoveryViewModel
    @ObservedObject var positioning:UWBSessionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var cameraAllowed=false
    @State private var permissionChecked=false
    @State private var cameraPeer:AuraProfile?
    @State private var showPositioning=false
    private var incoming:Int { model.requests.filter{$0.recipient==model.profile?.wallet && $0.recipient_token==nil}.count }
    var body:some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if cameraAllowed && phase == .active {
                ARAuraView(positioning:positioning,profiles:model.peers.map(\.profile),select:{ wallet in cameraPeer=model.peers.first(where:{$0.id==wallet})?.profile }).ignoresSafeArea()
            } else if permissionChecked {
                ContentUnavailableView("Camera access is off",systemImage:"camera",description:Text("Allow Camera for Aura in Settings. Event search remains available."))
            }
            VStack(alignment:.leading,spacing:12) {
                HStack {
                    VStack(alignment:.leading,spacing:4) { AuraBrand(size:28);Text("ROOM CAMERA · BUILD \(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "—")").font(.caption2).tracking(2) }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName:"xmark").padding(12).background(.black.opacity(0.6),in:Circle()) }.accessibilityLabel("Close room camera")
                }.padding().background(.black.opacity(0.55))
                if positioning.measurements.isEmpty {
                    VStack(alignment:.leading,spacing:8) {
                        Text(model.active ? "Ready to position profiles" : "Start discovery to begin").font(.headline)
                        Text(model.active ? "Choose a compatible participant below. Once they accept and a position is measured, their profile will appear at their device as you turn." : "Both participants need active discovery in the same event.").font(.subheadline)
                    }.padding(18).background(.black.opacity(0.7),in:RoundedRectangle(cornerRadius:20)).padding(.horizontal,14)
                }
                Spacer()
                VStack(alignment:.leading,spacing:10) {
                    HStack { Text("\(positioning.measurements.count) measured devices").font(.headline);Spacer();Text("DEVNET").font(.caption2).foregroundStyle(AuraTheme.lime) }
                    Text(positioning.cameraMessage).font(.caption).foregroundStyle(.secondary)
                    if let error=model.error { Text(error).font(.caption).foregroundStyle(.orange) }
                    if !positioning.supportsCamera { Text("This phone cannot place measured profiles in the camera view.").font(.caption).foregroundStyle(.orange) }
                    if incoming>0 { Button("\(incoming) positioning request\(incoming==1 ? "" : "s") · Review") { showPositioning=true }.buttonStyle(.borderedProminent).foregroundStyle(.black) }
                    HStack {
                        Button(model.active ? "Position people" : "Start discovery") {
                            if model.active { showPositioning=true } else { model.perform { try await model.start();showPositioning=true } }
                        }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(model.busy || !cameraAllowed)
                        if model.active { Button("Pause") { model.perform { await model.stop() } }.buttonStyle(.bordered) }
                    }
                    Text("Up to three accepted devices. Cards follow measured device positions; they do not identify faces. Camera stays on your phone.").font(.caption2).foregroundStyle(.secondary)
                    Button("Browse people without camera") { dismiss() }.font(.caption)
                }.padding(18).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:24)).padding(.horizontal,14).padding(.bottom,12)
            }.foregroundStyle(.white)
        }.task {
            switch AVCaptureDevice.authorizationStatus(for:.video) {
            case .authorized:cameraAllowed=true
            case .notDetermined:cameraAllowed=await AVCaptureDevice.requestAccess(for:.video)
            default:cameraAllowed=false
            }
            permissionChecked=true
        }.sheet(item:$cameraPeer) { peer in PeerDetailView(model:model,peer:peer) }
        .sheet(isPresented:$showPositioning) { PositioningPeopleView(model:model,positioning:positioning) }
        .onDisappear { Task { await model.endPositioning() } }
    }
}

struct PositioningPeopleView:View {
    @ObservedObject var model:DiscoveryViewModel
    @ObservedObject var positioning:UWBSessionManager
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            List {
                Section {
                    Text("Ask a participant to share their device position for up to two minutes. Point the backs of both phones toward each other to acquire the first measurement, then return to the camera.").font(.subheadline)
                    Text("This build positions compatible iPhones. Android profiles remain available in nearby and event search.").font(.caption).foregroundStyle(.secondary)
                }
                if let error=model.error { Section { Text(error).foregroundStyle(.orange) } }
                Section("Positioning sessions") {
                    if model.requests.isEmpty { Text("No positioning sessions yet.").foregroundStyle(.secondary) }
                    ForEach(model.requests) { request in
                        VStack(alignment:.leading,spacing:8) {
                            Text(request.peer.name).font(.headline)
                            Text(positioning.messages[request.peer.wallet] ?? (request.recipient_token==nil ? "Waiting for approval" : "Waiting for a measurement")).font(.caption).foregroundStyle(.secondary)
                            HStack {
                                if request.recipient==model.profile?.wallet && request.recipient_token==nil {
                                    Button("Accept position sharing") { model.perform { try await model.accept(request) } }.disabled(model.busy)
                                }
                                Button("Stop",role:.destructive) { model.perform { try await model.dismiss(request) } }.disabled(model.busy)
                            }.buttonStyle(.bordered)
                        }
                    }
                }
                Section("Nearby participants") {
                    if model.peers.isEmpty { Text("Keep both phones open in the same event with discovery active.").foregroundStyle(.secondary) }
                    ForEach(model.peers.sorted{$0.profile.name<$1.profile.name}) { peer in
                        VStack(alignment:.leading,spacing:8) {
                            HStack { NearbyAvatar(profile:peer.profile,size:36);VStack(alignment:.leading) { Text(peer.profile.name).font(.headline);Text(peer.profile.role).font(.caption).foregroundStyle(.secondary) } }
                            if peer.rangingProtocol != "apple-ni-v2" { Text("Camera positioning unavailable on this participant’s current app or device.").font(.caption).foregroundStyle(.secondary) }
                            else if !model.requests.contains(where:{$0.peer.wallet==peer.id}) {
                                Button("Request positioning") { model.perform { try await model.requestPosition(peer.profile) } }.disabled(model.busy || !model.active || !positioning.supportsDistance || positioning.peerIDs.count>=UWBSessionManager.peerLimit)
                            }
                        }
                    }
                }
            }.navigationTitle("Position people").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Camera") { dismiss() } } }
        }
    }
}
struct PeerDetailView:View {
    @ObservedObject var model:DiscoveryViewModel
    let peer:AuraProfile
    @Environment(\.openURL) var openURL
    @State private var note = ""
    @State private var amount = "0.01"
    @State private var report = ""
    @State private var saved = false
    var body:some View { NavigationStack { Form {
        Section { Text(peer.name).font(.largeTitle.bold());Text(peer.role);Text(peer.project).foregroundStyle(AuraTheme.lime);Text(peer.bio);Text(peer.statusLabel).font(.caption);Text(peer.wallet).font(.caption.monospaced()).textSelection(.enabled) }
        Section("Media") { ProfileMediaView(profile:peer,api:model.api) }
        Section("Explore") { if let url = URL(string:peer.link),url.scheme=="https" { Link("Project / social ↗",destination:url) };if let url = URL(string:peer.video),url.scheme=="https" { Link("Watch intro ↗",destination:url) };Text(peer.intents.joined(separator:" · ")) }
        Section("Remember this connection") { TextField("Private note",text:$note,axis:.vertical);Button(saved ? "Saved ✓" : "Save connection") { model.perform { try await model.saveConnection(peer,note:note);saved = true } } }
        Section("Positioning") { Button("Request device positioning") { model.perform { try await model.requestPosition(peer) } }.disabled(!model.active || model.busy || !model.peers.contains(where:{$0.id==peer.wallet && $0.rangingProtocol=="apple-ni-v2"}));Text("Compatible participants must accept. Open Room Camera to see a profile at a fresh measured device position. Device position does not prove who is holding it.").font(.caption).foregroundStyle(.secondary) }
        Section("Send devnet SOL") { TextField("Amount",text:$amount).keyboardType(.decimalPad);Button("Review in your wallet browser ↗") { model.perform { let url = try await model.payment(peer,amount:amount);openURL(url) } };Text("Nothing is sent until you review and approve in your wallet. Maximum 1 devnet SOL per pilot payment.").font(.caption).foregroundStyle(.secondary) }
        Section("Safety") { Text("Safety reports remain for 90 days, including after account deletion. Include only information needed to review the incident.").font(.caption); TextField("Describe a concern",text:$report,axis:.vertical);Button("Submit report") { model.perform { try await model.report(peer,reason:report);report = "";model.error = "Report stored for pilot operator review." } }.disabled(report.isEmpty);Button("Block participant",role:.destructive) { model.perform { try await model.block(peer) } } }
    }.navigationTitle("Their Aura").navigationBarTitleDisplayMode(.inline).onAppear { note = model.connections.first(where:{$0.target==peer.wallet})?.note ?? "" } } }
}

struct ProfileMediaView: View {
    let profile: AuraProfile
    let api: APIService
    @State private var avatar: UIImage?
    @State private var player: AVPlayer?
    @State private var file: URL?
    @State private var error: String?
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            if let avatar { Image(uiImage:avatar).resizable().scaledToFill().frame(width:72,height:72).clipShape(Circle()) }
            if let player { VideoPlayer(player:player).frame(height:210) }
            else if let id = profile.videoMediaId { Button("Load intro video") { Task { do { let data = try await api.media(id);let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".mp4");try data.write(to:url,options:.atomic);file = url;player = AVPlayer(url:url) } catch { self.error = error.localizedDescription } } } }
            if profile.avatarMediaId == nil && profile.videoMediaId == nil { Text("No uploaded media yet.").font(.caption).foregroundStyle(.secondary) }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
        }.task { if let id = profile.avatarMediaId { do { avatar = UIImage(data:try await api.media(id)) } catch { self.error = error.localizedDescription } } }
        .onDisappear { player?.pause();player = nil;if let file { try? FileManager.default.removeItem(at:file) } }
    }
}
