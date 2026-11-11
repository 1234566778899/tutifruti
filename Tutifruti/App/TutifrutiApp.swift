import SwiftUI

@main
struct TutifrutiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app = AppState()
    @State private var store = StoreManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(store)
                .onOpenURL { app.handleDeepLink($0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { app.handleDeepLink(url) }
                }
                .scrollDismissesKeyboard(.interactively)
                .preferredColorScheme(.dark)  // el estilo de juego es oscuro
                .onAppear { KeyboardDismisser.shared.install() }
        }
    }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        Group {
            switch app.phase {
            case .loading:
                VStack(spacing: 18) {
                    LogoView(height: 90)
                    MascotView(pose: .hello, size: 160)
                    ThinkingDots()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { GameBackground() }
            case .signedOut:
                NavigationStack { WelcomeView() }
            case .needsProfile:
                NavigationStack { ProfileSetupView() }
            case .ready:
                MainTabView()
                    .fullScreenCover(item: Binding(
                        get: { app.activeRoom.map(RoomID.init) },
                        set: { app.activeRoom = $0?.id }
                    )) { room in
                        GameContainerView(roomId: room.id)
                            .id(room.id)
                    }
                    .task {
                        if let code = app.pendingJoinCode {
                            app.pendingJoinCode = nil
                            try? await app.join(code: code)
                        }
                        if let token = app.pendingFriendToken {
                            app.pendingFriendToken = nil
                            await app.acceptFriendLink(token)
                        }
                    }
                    .sheet(item: $app.friendAdded) { r in FriendAddedSheet(result: r).gameScreen() }
                    .sheet(isPresented: $app.guestNeedsAccount) { GuestAccountSheet().gameScreen() }
            }
        }
        .animation(.default, value: app.phase)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await app.sceneBecameActive() } }
        }
        .overlay(alignment: .top) { ToastView(text: $app.toast) }
        .sheet(isPresented: $app.needsNewPassword) { NewPasswordView().gameScreen() }
    }
}

struct RoomID: Identifiable { let id: UUID }

struct MainTabView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        if app.isGuest {
            // Invitado: solo el inicio (salas y jugar). Sin amigos ni perfil.
            NavigationStack { HomeView() }
        } else {
        TabView(selection: $app.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .tag(AppState.Tab.home)
            NavigationStack { FriendsView() }
                .tabItem { Label("Amigos", systemImage: "person.2.fill") }
                .tag(AppState.Tab.friends)
            NavigationStack { ProfileView() }
                .tabItem { Label("Perfil", systemImage: "person.crop.circle.fill") }
                .tag(AppState.Tab.profile)
        }
        .tint(Game.lemon)
        }
    }
}
