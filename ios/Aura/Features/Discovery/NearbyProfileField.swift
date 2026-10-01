import SwiftUI

/// A browsing layout for already-authorized BLE peers; layout never represents coordinates.
struct NearbyProfileField: View {
    let peers: [NearbyPeer]
    let select: (AuraProfile) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:14,alignment:.top),count:columns),alignment:.center,spacing:22) {
            ForEach(Array(peers.enumerated()),id:\.element.id) { index,peer in
                FloatingProfileCard(profile:peer.profile,alternate:index % 2 == 1) { select(peer.profile) }
                    .padding(.top,columns == 2 && index % 2 == 1 ? 22 : 0)
            }
        }.padding(.vertical,8)
    }
}

private struct FloatingProfileCard: View {
    let profile: AuraProfile
    let alternate: Bool
    let select: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false
    var body: some View {
        Button(action:select) {
            VStack(alignment:.leading,spacing:12) {
                HStack { NearbyAvatar(profile:profile,size:52);Spacer(minLength:0);Image(systemName:"arrow.up.right").font(.caption).foregroundStyle(.secondary) }
                Text(profile.name).font(.headline).foregroundStyle(.white).lineLimit(2)
                if !profile.role.isEmpty { Text(profile.role).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                if !profile.project.isEmpty { Text(profile.project).font(.subheadline.weight(.medium)).foregroundStyle(AuraTheme.lime).lineLimit(2) }
                if let intent = profile.intents.first { Text(intent).font(.caption2).padding(.horizontal,9).padding(.vertical,6).background(.white.opacity(0.06),in:Capsule()).foregroundStyle(.white) }
                Label(profile.statusLabel,systemImage:profile.status == "open" ? "circle.fill" : "moon.fill")
                    .font(.caption2).foregroundStyle(profile.status == "open" ? AuraTheme.lime : .orange)
            }
            .frame(maxWidth:.infinity,alignment:.leading).padding(16)
            .background(LinearGradient(colors:[AuraTheme.lime.opacity(alternate ? 0.09 : 0.04),Color.white.opacity(0.025)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:26))
            .overlay(RoundedRectangle(cornerRadius:26).strokeBorder(AuraTheme.lime.opacity(0.16),lineWidth:1))
            .shadow(color:.black.opacity(0.22),radius:12,y:8)
        }.buttonStyle(.plain)
        .accessibilityLabel([profile.name,profile.role,profile.project,profile.statusLabel,profile.intents.joined(separator:", ")].filter{!$0.isEmpty}.joined(separator:". "))
        .accessibilityHint("Open this nearby profile")
        .offset(y:reduceMotion ? 0 : lifted ? -3 : 3)
        .animation(reduceMotion ? nil : .easeInOut(duration:alternate ? 3.6 : 3).repeatForever(autoreverses:true),value:lifted)
        .onAppear { lifted = true }
    }
}

struct NearbyAvatar: View {
    let profile: AuraProfile
    let size: CGFloat
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            Circle().fill(AuraTheme.lime.opacity(0.12))
            if let image { Image(uiImage:image).resizable().scaledToFill() }
            else { Text(String(profile.name.prefix(1)).uppercased()).font(.system(size:size*0.4,weight:.bold)).foregroundStyle(AuraTheme.lime) }
        }.frame(width:size,height:size).clipShape(Circle()).accessibilityHidden(true)
        .task(id:profile.avatarMediaId) {
            image = nil
            guard let id = profile.avatarMediaId else { return }
            guard let data = try? await APIService.shared.media(id),!Task.isCancelled else { return }
            image = UIImage(data:data)
        }
    }
}
