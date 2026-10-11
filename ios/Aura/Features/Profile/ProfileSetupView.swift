import SwiftUI
import UIKit
struct ProfileSetupView: View {
    @ObservedObject var model: DiscoveryViewModel
    @State private var server = APIService.shared.baseURL
    var body: some View {
        NavigationStack { ScrollView { VStack(alignment:.leading,spacing:28) {
            HStack { AuraBrand(size:42);Spacer();Text("DEVNET PILOT").font(.caption2.monospaced()).foregroundStyle(AuraTheme.lime) }
            Text("Your people.\nAlready in the room.").font(.system(size:40,weight:.semibold)).tracking(-1.5)
            Text("Bring your context. Choose to be seen. Find a reason to say hello.").foregroundStyle(.secondary)
            VStack(alignment:.leading,spacing:14) {
                Text("Connect your identity").font(.headline)
                Text("Pair this phone with a wallet-verified Aura session. No private keys are stored in Aura.").font(.subheadline).foregroundStyle(.secondary)
                TextField("Aura server origin",text:$server).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).textFieldStyle(.roundedBorder)
                Text("Use the server address supplied by your pilot host. For a local pilot, keep this phone and the Mac on the same Wi-Fi.").font(.caption).foregroundStyle(.secondary)
                if let pairing = model.pairing {
                    Text(pairing.code).font(.system(size:30,weight:.bold,design:.monospaced)).textSelection(.enabled).foregroundStyle(AuraTheme.lime)
                    Button("Copy pairing code") { UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic:pairing.code]], options:[.localOnly:true,.expirationDate:Date(timeIntervalSince1970:pairing.expires/1000)]) }
                    Text("In Solflare’s browser, open the address below, verify your wallet, then enter this code under Connect your phone → Approve this device. Return to Aura to finish.").font(.caption)
                    Text(model.api.baseURL).font(.caption.monospaced()).textSelection(.enabled)
                    if let url = URL(string:model.api.baseURL) { Link("Open web companion ↗",destination:url) }
                    Text("If this opens Safari without a wallet, copy the address into your wallet’s browser.").font(.caption).foregroundStyle(.secondary)
                    TimelineView(.periodic(from:.now,by:1)) { context in
                        let remaining = max(0,Int(ceil(pairing.expires/1000-context.date.timeIntervalSince1970)))
                        Text("Expires in \(remaining/60):\(String(format:"%02d",remaining%60)) · This is not your event code.").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    ProgressView().accessibilityLabel("Waiting for pairing approval")
                }
                if !model.pairingStatus.isEmpty { Text(model.pairingStatus).font(.caption).foregroundStyle(.secondary) }
                Button(model.pairing == nil ? "Create pairing code ↗" : "Generate a new code") { model.perform { try await model.pair(server:server) } }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(model.busy)
            }.padding(22).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:20))
            Text("Bluetooth and camera access support discovery and optional positioning. Visibility starts only when you choose it.").font(.caption).foregroundStyle(.secondary)
        }.padding(25) }.background(AuraTheme.background) }
    }
}
