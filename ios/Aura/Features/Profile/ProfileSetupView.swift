import SwiftUI
struct ProfileSetupView: View {
    @ObservedObject var model: DiscoveryViewModel
    @State private var server = APIService.shared.baseURL
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment:.leading,spacing:28) {
            HStack { Text("aura◌").font(.system(size:42,weight:.bold,design:.rounded));Spacer();Text("DEVNET PILOT").font(.caption2.monospaced()).foregroundStyle(AuraTheme.lime) }
            Text("Your people.\nAlready in the room.").font(.system(size:40,weight:.semibold)).tracking(-1.5)
            Text("Bring your context. Choose to be seen. Find a reason to say hello.").foregroundStyle(.secondary)
            VStack(alignment:.leading,spacing:14) {
                Text("Connect your identity").font(.headline)
                Text("Pair this phone with a wallet-verified Aura session. No private keys are stored in Aura.").font(.subheadline).foregroundStyle(.secondary)
                TextField("Aura server origin",text:$server).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder)
                Text("On a physical iPhone, use the Mac’s reachable network address or an HTTPS server. localhost works only in the simulator.").font(.caption).foregroundStyle(.secondary)
                if let pairing = model.pairing {
                    Text(pairing.code).font(.system(size:30,weight:.bold,design:.monospaced)).textSelection(.enabled).foregroundStyle(AuraTheme.lime)
                    Text("Open the server address in a wallet-enabled browser. Verify your wallet, save your profile, and approve this code under Connect your iPhone. It expires in five minutes.").font(.caption)
                    if let url = URL(string:server) { Link("Open web companion ↗",destination:url) }
                    ProgressView("Waiting for your approval…")
                }
                Button(model.pairing == nil ? "Create pairing code ↗" : "Generate a new code") { model.perform { try await model.pair(server:server) } }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(model.busy)
            }.padding(22).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:20))
            Text("Bluetooth and camera access support discovery and optional positioning. Visibility starts only when you choose it.").font(.caption).foregroundStyle(.secondary)
        }.padding(25) }.background(AuraTheme.background) }
    }
}
