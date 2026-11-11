import SwiftUI

/// Salas públicas abiertas: cualquiera puede unirse mientras están en espera (antes de que el anfitrión inicie).
struct PublicRoomsView: View {
    @Environment(AppState.self) private var app
    @State private var rooms: [PublicRoom] = []
    @State private var loaded = false
    @State private var joining: UUID?
    @State private var error: String?
    @State private var creating = false

    var body: some View {
        GameList {
            if !loaded {
                Section { HStack { Spacer(); ProgressView(); Spacer() } }.listRowBackground(Color.clear)
            } else if rooms.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        MascotView(pose: .think, size: 150)
                        OutlinedTitle(text: "No hay salas abiertas", size: 22)
                        Text("Crea una y aparecerá aquí para que otros jugadores se unan.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button { creating = true } label: {
                            Label("Crear sala pública", systemImage: "plus")
                        }
                        .buttonStyle(CandyButtonStyle(color: Game.lime, icon: "plus"))
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(Array(rooms.enumerated()), id: \.element.id) { i, room in
                        PublicRoomRow(room: room, joining: joining == room.id) { await join(room) }
                            .popIn(i)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                } header: {
                    SectionTitle(text: rooms.count == 1 ? "Sala abierta" : "Salas abiertas", trailing: "\(rooms.count)").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4))
                } footer: {
                    Text("Puedes unirte hasta que el anfitrión inicie la partida. La lista se actualiza sola.")
                }
            }
        }
        .gameTitle("Salas públicas")
        .gameScreen()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Crear sala pública", systemImage: "plus") { creating = true }
            }
        }
        .navigationDestination(isPresented: $creating) { RoomConfigView(startPublic: true) }
        .refreshable { await load() }
        .task {
            // Se actualiza cada 5 s mientras la pantalla está visible.
            while !Task.isCancelled {
                await load()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .animation(.spring(duration: 0.35), value: rooms)
        .errorAlert($error)
    }

    private func load() async {
        if let list = try? await API.publicRooms() { rooms = list }
        loaded = true
    }

    private func join(_ room: PublicRoom) async {
        joining = room.id
        defer { joining = nil }
        do {
            let id = room.isMember ? room.id : try await API.joinPublicRoom(room.id)
            Sfx.play(.join)
            app.enterRoom(id)
        } catch {
            self.error = friendlyError(error)
            await load()
        }
    }
}

struct PublicRoomRow: View {
    var room: PublicRoom
    var joining: Bool
    var onJoin: () async -> Void

    var body: some View {
        GamePanel(padding: 12) { content }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(room.name), de \(room.hostName), \(room.players) de \(room.maxPlayers) jugadores, \(room.roundsTotal) rondas")
    }

    private var content: some View {
        HStack(spacing: 12) {
            AvatarView(avatar: room.hostAvatar, name: room.hostName, size: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text(room.name).font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(.white)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text("de \(room.hostName) · Nivel \(room.hostLevel)").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                HStack(spacing: 8) {
                    Label("\(room.players)/\(room.maxPlayers)", systemImage: "person.2.fill")
                        .foregroundStyle(room.isFull ? .red : .green)
                    Label("\(room.roundsTotal)", systemImage: "arrow.triangle.2.circlepath")
                    Label("\(room.roundSeconds) s", systemImage: "timer")
                    Label("\(room.categories.count)", systemImage: "square.grid.2x2")
                }
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.white.opacity(0.65))
                .labelStyle(CompactLabel())
            }
            Spacer(minLength: 6)
            Button {
                Task { await onJoin() }
            } label: {
                Group {
                    if joining { ProgressView().tint(.white) }
                    else { Text(room.isMember ? "Volver" : (room.isFull ? "Llena" : "Unirme")).fontWeight(.heavy) }
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(minWidth: 70).padding(.vertical, 9).padding(.horizontal, 8)
                .background {
                    ZStack {
                        Capsule().fill(Game.edge(room.isFull && !room.isMember ? .gray : Game.tangerine)).offset(y: 3)
                        Capsule().fill(room.isFull && !room.isMember ? Color.gray : Game.tangerine)
                    }
                }
                .overlay(Capsule().strokeBorder(Game.ink, lineWidth: 2))
            }
            .buttonStyle(BouncyButtonStyle())
            .disabled(joining || (room.isFull && !room.isMember))
        }
    }
}

/// Ícono + texto juntos y compactos.
struct CompactLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) { configuration.icon; configuration.title.lineLimit(1) }.fixedSize()
    }
}
