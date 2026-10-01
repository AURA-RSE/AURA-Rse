import SwiftUI
import AVKit
struct DiscoveryView: View {
    @ObservedObject var model: DiscoveryViewModel
    @State private var query = ""
    @State private var intent = "All"
    @State private var showCamera = false
    var filtered:[NearbyPeer] { model.peers.filter { p in (intent == "All" || p.profile.intents.contains(intent)) && (query.isEmpty || "\(p.profile.name) \(p.profile.role) \(p.profile.project)".localizedCaseInsensitiveContains(query)) } }
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment:.leading,spacing:22) {
            HStack { Text("THE ROOM IS YOURS.").font(.caption2).tracking(2).foregroundStyle(AuraTheme.lime);Spacer();Text("DEVNET").font(.caption2.monospaced()).foregroundStyle(.secondary) }
            Text("Find your people.").font(.system(size:36,weight:.semibold)).tracking(-1)
            Picker("Event",selection:$model.selectedEvent) { Text("Choose an event").tag("");ForEach(model.events) { Text($0.name).tag($0.id) } }.disabled(model.active)
            HStack {
                Button(model.active ? "Pause discovery" : "Start discovery ↗") { model.perform { if model.active { await model.stop() } else { try await model.start() } } }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(model.busy)
                Button { showCamera = true } label: { Image(systemName:"camera.viewfinder").font(.title2) }.disabled(!model.active)
            }
            DiscoveryStatus(broadcaster:model.broadcaster,scanner:model.scanner,message:model.statusMessage)
            ForEach(model.requests) { r in VStack(alignment:.leading,spacing:10) {
                Text(r.recipient == model.profile?.wallet ? "\(r.peer.name) requested positioning" : "Positioning with \(r.peer.name)").font(.headline)
                Text("Shares device distance and direction for up to two minutes.").font(.caption).foregroundStyle(.secondary)
                HStack { if r.recipient == model.profile?.wallet && r.recipient_token == nil { Button("Accept") { model.perform { try await model.accept(r) } } };Button("Stop / decline") { model.perform { try await model.dismiss(r) } } }
            }.padding().background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14)) }
            TextField("Search people, roles, projects",text:$query).textFieldStyle(.roundedBorder)
            Picker("Intent",selection:$intent) { ForEach(["All","Building","Hiring","Fundraising","Looking for a team","Offering feedback","Open to connect"],id:\.self) { Text($0).tag($0) } }
            HStack { Text("NEARBY").font(.caption2).tracking(2);Spacer();Text("\(filtered.count) discovered").font(.caption).foregroundStyle(.secondary) }
            if filtered.isEmpty { ContentUnavailableView(model.active ? "Make room for a connection" : "Choose when to be seen",systemImage:"dot.radiowaves.left.and.right",description:Text(model.active ? "Participating devices appear here when discovered. Keep both phones open in the same event." : "Join an event in My Aura and choose a visible status to start.")) }
            ForEach(filtered) { peer in Button { model.selectedPeer = peer.profile } label: { HStack(alignment:.top,spacing:15) {
                Text(String(peer.profile.name.prefix(1))).font(.title2.bold()).frame(width:48,height:48).background(AuraTheme.lime.opacity(0.15),in:RoundedRectangle(cornerRadius:14)).foregroundStyle(AuraTheme.lime)
                VStack(alignment:.leading,spacing:7) { Text(peer.profile.name).font(.headline).foregroundStyle(.white);Text(peer.profile.role + " · " + peer.profile.project).font(.subheadline).foregroundStyle(.secondary);Text(peer.profile.statusLabel).font(.caption).foregroundStyle(peer.profile.status == "open" ? AuraTheme.lime : .orange) }
                Spacer();Image(systemName:"arrow.up.right").foregroundStyle(.secondary)
            }.padding(18).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:18)) } }
        }.padding(24) }.background(AuraTheme.background).navigationBarHidden(true).sheet(isPresented:$showCamera) { CameraSheet(model:model,positioning:model.positioning) } }
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
    @Environment(\.dismiss) var dismiss
    var body:some View { ZStack(alignment:.bottom) {
        ARAuraView(positioning:positioning,name:model.peers.first(where:{$0.id==positioning.peerID})?.profile.name ?? "Participant").ignoresSafeArea()
        VStack(spacing:12) { Text("MEASURED DEVICE POSITION").font(.caption2).tracking(2);Text(positioning.message).font(.subheadline);if let distance = positioning.distance { Text("\(distance,specifier:"%.2f") m").font(.title) };Button("Back to nearby list") { dismiss() }.buttonStyle(.borderedProminent).foregroundStyle(.black) }.padding(24).frame(maxWidth:.infinity).background(.ultraThinMaterial)
    }.onDisappear { Task { await model.endPositioning() } } }
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
        Section("Positioning") { Button("Request device positioning") { model.perform { try await model.requestPosition(peer) } }.disabled(!model.active);Text("The other participant must accept. Open the camera from Discover after acceptance. Device position does not prove who is holding it.").font(.caption).foregroundStyle(.secondary) }
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
