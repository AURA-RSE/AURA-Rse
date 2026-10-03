import SwiftUI

/// Membership-scoped directory; independent of camera and Bluetooth discovery.
struct EventPeopleView: View {
    @ObservedObject var model: DiscoveryViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var profiles: [AuraProfile] = []
    @State private var query = ""
    @State private var intent = "All"
    @State private var error: String?
    @State private var loading = true
    @State private var selected: AuraProfile?
    private var matches: [AuraProfile] { profiles.filter { profile in
        (intent == "All" || profile.intents.contains(intent)) && (query.isEmpty || "\(profile.name) \(profile.role) \(profile.project)".localizedCaseInsensitiveContains(query))
    } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(model.events.first(where:{$0.id==model.selectedEvent})?.name ?? "Your event").font(.headline)
                    Text("Browse participants who choose to appear in event search. No camera or Bluetooth needed. This directory does not show who is physically nearby.").font(.caption).foregroundStyle(.secondary)
                    Text("To appear here, enable Show me in event search in My Aura, choose a visible status, and save.").font(.caption).foregroundStyle(.secondary)
                    Picker("Intent",selection:$intent) { ForEach(["All","Building","Hiring","Fundraising","Looking for a team","Offering feedback","Open to connect"],id:\.self) { Text($0).tag($0) } }
                }
                if loading { ProgressView("Loading participants…") }
                if let error { Text(error).foregroundStyle(.orange);Button("Try again") { Task { await refresh() } } }
                if !loading && error == nil && matches.isEmpty { Text(profiles.isEmpty ? "No participants have enabled event search yet." : "No profiles match your search.").foregroundStyle(.secondary) }
                ForEach(matches) { person in
                    Button { Task {
                        do { let response:ProfileResponse = try await model.api.request("/api/profiles/read",method:"POST",body:["wallet":person.wallet]);selected=response.profile }
                        catch { self.error=error.localizedDescription;await refresh() }
                    } } label: {
                        HStack(spacing:12) { NearbyAvatar(profile:person,size:44);VStack(alignment:.leading,spacing:5) { Text(person.name).font(.headline);Text([person.role,person.project].filter{!$0.isEmpty}.joined(separator:" · ")).font(.subheadline).foregroundStyle(.secondary) } }.padding(.vertical,6)
                    }.buttonStyle(.plain)
                }
            }.navigationTitle("People at this event").navigationBarTitleDisplayMode(.inline)
            .searchable(text:$query,prompt:"Name, role or project")
            .toolbar { ToolbarItem(placement:.topBarTrailing) { Button("Done") { dismiss() } } }
            .refreshable { await refresh() }
            .task(id:model.selectedEvent) {
                profiles=[]
                while !Task.isCancelled {
                    if phase == .active { await refresh() }
                    do { try await Task.sleep(for:.seconds(5)) } catch { return }
                }
            }
            .onChange(of:phase) { _,value in if value != .active { profiles=[] } }
            .sheet(item:$selected) { person in PeerDetailView(model:model,peer:person) }
        }
    }
    private func refresh() async {
        let event=model.selectedEvent
        guard !event.isEmpty else { profiles=[];loading=false;return }
        do {
            let response:EventPeopleResponse = try await model.api.request("/api/events/people",method:"POST",body:["event":event])
            guard !Task.isCancelled,model.selectedEvent==event,phase == .active else { return }
            profiles=response.profiles;error=nil;loading=false
        } catch { if !Task.isCancelled { profiles=[];self.error=error.localizedDescription;loading=false } }
    }
}
