import SwiftUI
@main struct AuraApp: App {
    @StateObject private var model = DiscoveryViewModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            Group { if model.profile == nil { ProfileSetupView(model:model) } else { RootView(model:model) } }
            .tint(AuraTheme.lime).preferredColorScheme(.dark).task { await model.restore() }
            .onChange(of:phase) { _,value in if value == .background { Task { await model.stop() } } }
            .alert("Aura",isPresented:Binding(get:{model.error != nil},set:{if !$0 { model.error = nil }})) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        }
    }
}
enum AuraTheme { static let lime = Color(red:0.82,green:1,blue:0.45);static let background = Color(red:0.04,green:0.05,blue:0.07) }
struct RootView: View {
    @ObservedObject var model: DiscoveryViewModel
    var body: some View {
        TabView {
            DiscoveryView(model:model).tabItem { Label("Discover",systemImage:"viewfinder") }
            ConnectionsView(model:model).tabItem { Label("Connections",systemImage:"person.2") }
            ActivityView(model:model).tabItem { Label("Activity",systemImage:"bolt") }
            MyProfileView(model:model).tabItem { Label("My Aura",systemImage:"person.crop.circle") }
        }.sheet(item:$model.selectedPeer) { peer in PeerDetailView(model:model,peer:peer) }
    }
}
struct ConnectionsView: View {
    @ObservedObject var model: DiscoveryViewModel
    var body: some View {
        NavigationStack {
            List {
                if model.connections.isEmpty { ContentUnavailableView("Your next connection is nearby",systemImage:"person.2",description:Text("Save someone from Discover. Your notes remain private.")) }
                ForEach(model.connections) { c in Button { model.selectedPeer = c.profile } label: { VStack(alignment:.leading,spacing:6) { Text(c.profile.name).font(.headline).foregroundStyle(.white);Text(c.profile.project).foregroundStyle(.secondary);if !c.note.isEmpty { Text(c.note).font(.caption).foregroundStyle(.secondary) } } } }
            }.navigationTitle("Connections").refreshable { do { try await model.refresh() } catch { model.error = error.localizedDescription } }
        }
    }
}
struct ActivityView: View {
    @ObservedObject var model: DiscoveryViewModel
    var body: some View {
        NavigationStack {
            List {
                Section { Text("DEVNET ONLY · Confirmations are verified against Solana. Wallet approval happens in the web companion.").font(.caption).foregroundStyle(.secondary) }
                if model.payments.isEmpty { ContentUnavailableView("No payments yet",systemImage:"bolt",description:Text("Start a payment from a discovered or saved profile.")) }
                ForEach(model.payments) { p in VStack(alignment:.leading,spacing:8) {
                    Text("\(Double(p.lamports)/1e9,specifier:"%.4f") SOL").font(.headline)
                    Text("To \(p.recipient)").font(.caption.monospaced()).textSelection(.enabled)
                    if let signature = p.signature,let url = WalletManager.explorerURL(signature:signature) { Link("Confirmed · view on devnet ↗",destination:url) }
                    else { Text("Awaiting approval or confirmation").font(.caption).foregroundStyle(.orange) }
                } }
            }.navigationTitle("Activity").refreshable { do { try await model.refresh() } catch { model.error = error.localizedDescription } }
        }
    }
}
struct MyProfileView: View {
    @ObservedObject var model: DiscoveryViewModel
    @State private var draft: AuraProfile?
    @State private var code = ""
    var body: some View {
        NavigationStack {
            Form {
                if let draft {
                    Section("Wallet verified") { Text(draft.wallet).font(.caption.monospaced()).textSelection(.enabled);Text("Wallet keys remain with your wallet.").font(.caption).foregroundStyle(.secondary) }
                    Section("Your profile") {
                        field("Name",\.name);field("Role",\.role);field("Project",\.project);field("Your story",\.bio);field("Project / social HTTPS link",\.link);field("Intro video HTTPS link",\.video)
                        Picker("Presence",selection:binding(\.status)) { Text("Stealth").tag("stealth");Text("Open to connect").tag("open");Text("Heads down").tag("heads-down") }
                        Toggle("Show me in event search",isOn:Binding(get:{self.draft?.eventDirectory ?? false},set:{self.draft?.eventDirectory = $0}))
                        Text("Members of events you join can find your profile without Bluetooth. Stealth hides you. Saved connections can revisit your profile.").font(.caption).foregroundStyle(.secondary)
                        ForEach(["Building","Hiring","Fundraising","Looking for a team","Offering feedback","Open to connect"],id:\.self) { intent in Toggle(intent,isOn:Binding(get:{self.draft?.intents.contains(intent) ?? false},set:{value in if value { self.draft?.intents.append(intent) } else { self.draft?.intents.removeAll{$0==intent} } })) }
                        Button("Save profile") { model.perform { if let value = self.draft { try await model.save(value);self.draft = model.profile } } }.disabled(model.busy)
                    }
                }
                Section("Your event") { TextField("Event code (local pilot: AURA-LAB)",text:$code).textInputAutocapitalization(.characters).autocorrectionDisabled();Button("Join event") { model.perform { try await model.join(code:code);code = "" } } }
                Section("Privacy") {
                    Text("Stealth stops discovery. Saved connections can revisit your profile. Blocking prevents access between those accounts. Notes are private.").font(.caption)
                    if let url = URL(string:model.api.baseURL) { Link("Export, delete, and manage blocks ↗",destination:url) }
                    Button("Sign out",role:.destructive) { Task { await model.logout() } }
                }
                Section("Pilot capabilities") { Text("Foreground Bluetooth discovery. Up to three separately accepted positioning peers. Spatial cards require measured camera-assisted coordinates. Physical multi-peer accuracy and Android positioning remain unverified.").font(.caption) }
            }.navigationTitle("My Aura").onAppear { draft = model.profile }
        }
    }
    private func binding(_ path:WritableKeyPath<AuraProfile,String>) -> Binding<String> { Binding(get:{draft?[keyPath:path] ?? ""},set:{draft?[keyPath:path] = $0}) }
    private func field(_ name:String,_ path:WritableKeyPath<AuraProfile,String>) -> some View { TextField(name,text:binding(path)) }
}
