import SwiftUI
import AuthenticationServices
import PhotosUI
import Supabase

// MARK: Bienvenida
struct WelcomeView: View {
    @Environment(AppState.self) private var app
    @State private var error: String?
    @State private var guestLoading = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 4)
            LogoView(height: 96)
            ZStack {
                FloatingLetters()
                MascotView(pose: .hello, size: 180)
            }
            .frame(height: 210)
            Text("El clásico Stop / Basta con un árbitro de IA que valida cada respuesta.")
                .font(.system(.callout, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal)
                .popIn(2)
            Spacer(minLength: 4)

            // Protagonista: entrar a jugar ya (como invitado).
            Button(guestLoading ? "Entrando…" : "Jugar ahora") {
                Task {
                    guestLoading = true
                    defer { guestLoading = false }
                    do { _ = try await supabase.auth.signInAnonymously() } catch { self.error = friendlyError(error) }
                }
            }
            .buttonStyle(CandyButtonStyle(color: Game.tangerine, icon: "play.fill", height: 66))
            .disabled(guestLoading)

            // Secundario: crear cuenta para guardar el progreso.
            Text("o guarda tu progreso con una cuenta")
                .font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.6))
                .padding(.top, 2)
            SignInWithAppleButton(.continue) { app.prepareAppleRequest($0) } onCompletion: { result in
                Task { do { try await app.handleApple(result) } catch { self.error = friendlyError(error) } }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(Capsule())
            NavigationLink { RegisterView() } label: {
                SmallActionLabel(icon: "envelope.fill", title: "Continuar con correo", tint: Game.lemon)
            }
            .buttonStyle(BouncyButtonStyle())

            HStack(spacing: 18) {
                NavigationLink("Iniciar sesión") { LoginView() }
                Text("·").foregroundStyle(.white.opacity(0.5))
                NavigationLink("Ver reglas") { RulesView() }
            }
            .font(.system(.subheadline, design: .rounded).weight(.heavy))
            .foregroundStyle(Game.lemon)

            Text("Al continuar aceptas los Términos y la Política de privacidad.")
                .font(.caption).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24).padding(.bottom, 12)
        .background { GameBackground() }
        .errorAlert($error)
    }
}

/// Letras que flotan alrededor de la mascota en la bienvenida.
struct FloatingLetters: View {
    private let letters: [(String, CGFloat, CGFloat, Double)] = [
        ("A", -125, -45, 0), ("S", 128, -40, 0.8), ("M", -138, 55, 1.6), ("P", 132, 62, 2.4), ("R", -95, -88, 3.2), ("T", 100, -86, 4.0),
    ]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(letters.indices, id: \.self) { i in
                    let (l, x, y, ph) = letters[i]
                    LetterBadge(letter: l, size: 38)
                        .rotationEffect(.degrees(12 * sin(t * 0.9 + ph)))
                        .offset(x: x, y: y + 8 * sin(t * 1.3 + ph))
                        .opacity(0.9)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Iniciar sesión
struct LoginView: View {
    @Environment(AppState.self) private var app
    @State private var email = ""
    @State private var password = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        GameForm {
            Section {
                Text("Bienvenido de nuevo").font(.title2.bold()).listRowBackground(Color.clear)
            }
            Section {
                TextField("nombre@correo.com", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Contraseña", text: $password).textContentType(.password)
            } footer: {
                NavigationLink("¿Olvidaste tu contraseña?") { RecoverView(email: email) }.font(.footnote)
            }
            Section {
                PrimaryButton(title: "Iniciar sesión", systemImage: "person.fill", loading: loading) { await login() }
                    .disabled(email.isEmpty || password.isEmpty)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section {
                SignInWithAppleButton(.signIn) { app.prepareAppleRequest($0) } onCompletion: { result in
                    Task { do { try await app.handleApple(result) } catch { self.error = friendlyError(error) } }
                }
                .frame(height: 48)
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section {
                NavigationLink("¿No tienes cuenta? Regístrate") { RegisterView() }
            }
        }
        .gameTitle("Iniciar sesión")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert($error)
    }

    private func login() async {
        loading = true
        defer { loading = false }
        do { _ = try await supabase.auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password) }
        catch { self.error = friendlyError(error) }
    }
}

// MARK: Registro (paso 1)
struct RegisterView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var accepted = false
    @State private var loading = false
    @State private var error: String?
    @State private var needsConfirmation = false

    private var valid: Bool {
        email.contains("@") && password.count >= 8 && password == confirm && accepted
    }

    var body: some View {
        GameForm {
            Section {
                TextField("Correo electrónico", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("Contraseña (mínimo 8 caracteres)", text: $password).textContentType(.newPassword)
                SecureField("Repite la contraseña", text: $confirm).textContentType(.newPassword)
            } header: { SectionTitle(text: "Paso 1 de 2 · Tu cuenta").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) } footer: {
                if !confirm.isEmpty && confirm != password {
                    Text("Las contraseñas no coinciden.").foregroundStyle(.red)
                }
            }
            Section {
                Toggle("Acepto Términos y Política de privacidad", isOn: $accepted)
            }
            Section {
                PrimaryButton(title: "Continuar", systemImage: "arrow.right", loading: loading) { await register() }
                    .disabled(!valid)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
        }
        .gameTitle("Crear cuenta")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert($error)
        .alert("Revisa tu correo", isPresented: $needsConfirmation) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Te enviamos un enlace a \(email) para confirmar tu cuenta. Después inicia sesión para elegir tu nombre de usuario.")
        }
    }

    private func register() async {
        loading = true
        defer { loading = false }
        do {
            let res = try await supabase.auth.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
            if res.session == nil { needsConfirmation = true }
            // Con sesión, AppState pasa a "needsProfile" (paso 2) automáticamente.
        } catch {
            self.error = friendlyError(error)
        }
    }
}

// MARK: Usuario y avatar (paso 2)
struct ProfileSetupView: View {
    @Environment(AppState.self) private var app
    @State private var username = ""
    @State private var avatar = Avatars.free[0]
    @State private var available: Bool?
    @State private var checking = false
    @State private var loading = false
    @State private var error: String?
    @State private var photo: PhotosPickerItem?

    private var normalized: String { username.lowercased().trimmingCharacters(in: .whitespaces) }
    private var formatOK: Bool { normalized.range(of: "^[a-z0-9._]{3,20}$", options: .regularExpression) != nil }
    /// Apodo de invitado convertido a nombre válido (sin acentos ni espacios), sin el sufijo numérico.
    private var guestBase: String {
        let folded = username.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
        let clean = String(folded.unicodeScalars.filter { CharacterSet.lowercaseLetters.union(.decimalDigits).contains($0) && $0.isASCII }
            .map(Character.init))
        return String(clean.prefix(14))
    }
    private var guestOK: Bool { guestBase.count >= 2 }

    var body: some View {
        GameForm {
            Section {
                VStack(spacing: 12) {
                    AvatarView(avatar: avatar, name: username, size: 96)
                    if !app.isGuest {
                        PhotosPicker(selection: $photo, matching: .images) {
                            Label("Subir foto", systemImage: "photo")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } header: {
                SectionTitle(text: app.isGuest ? "Así te verán" : "Paso 2 de 2 · Así te verán").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4))
            }

            GameSection("Elige un avatar") {
                AvatarGrid(selection: $avatar)
            }

            Section {
                TextField(app.isGuest ? "Tu apodo" : "Nombre de usuario", text: $username)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .onChange(of: username) { if !app.isGuest { checkLater() } }
            } footer: {
                if app.isGuest {
                    Text(guestOK ? "Te verán como \(guestBase) + un número (p. ej. \(guestBase)\(previewSuffix))." : "Escribe al menos 2 letras.")
                } else if !username.isEmpty && !formatOK {
                    Text("3 a 20 caracteres: letras, números, punto o guion bajo.").foregroundStyle(.red)
                } else if checking {
                    Text("Comprobando…")
                } else if let available {
                    Label(available ? "\(normalized) está disponible" : "\(normalized) ya está en uso",
                          systemImage: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(available ? .green : .red)
                }
            }

            Section {
                PrimaryButton(title: "Empezar a jugar", systemImage: "play.fill", loading: loading, color: Game.lime) { await create() }
                    .disabled(app.isGuest ? !guestOK : !(formatOK && available == true))
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            Section {
                Button(app.isGuest ? "Cancelar" : "Cerrar sesión", role: .destructive) {
                    Task { if app.isGuest { await app.leaveGuestMode() } else { await app.signOut() } }
                }
            }
        }
        .gameTitle(app.isGuest ? "¿Cómo te llamas?" : "Tu perfil")
        .errorAlert($error)
        .onChange(of: photo) { Task { await uploadPhoto() } }
    }

    @State private var checkTask: Task<Void, Never>?
    private func checkLater() {
        available = nil
        checkTask?.cancel()
        guard formatOK else { return }
        checkTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            checking = true
            available = await API.usernameAvailable(normalized)
            checking = false
        }
    }

    private func uploadPhoto() async {
        guard let photo, let data = try? await photo.loadTransferable(type: Data.self),
              let img = UIImage(data: data), let jpg = img.resizedSquare(256).jpegData(compressionQuality: 0.8) else { return }
        do { avatar = try await API.uploadAvatar(jpg) } catch { self.error = friendlyError(error) }
    }

    @State private var previewSuffix = Int.random(in: 10...999)

    private func create() async {
        loading = true
        defer { loading = false }
        do {
            if app.isGuest {
                // Nombre único automático: apodo + número; reintenta si ya existe.
                var lastError: Error?
                for _ in 0..<5 {
                    let name = guestBase + String(Int.random(in: 10...9999))
                    do { _ = try await API.createProfile(username: name, avatar: avatar); lastError = nil; break }
                    catch { lastError = error }
                }
                if let lastError { throw lastError }
            } else {
                _ = try await API.createProfile(username: normalized, avatar: avatar)
            }
            await app.loadProfile()
        } catch {
            self.error = friendlyError(error)
        }
    }
}

struct AvatarGrid: View {
    @Binding var selection: String
    var owned: [String] = []

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
            ForEach(Array((Avatars.free + owned).enumerated()), id: \.element) { i, a in
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.6)) { selection = a }
                } label: {
                    AvatarView(avatar: a, size: 60)
                        .padding(3)
                        .overlay(Circle().stroke(selection == a ? Color.accentColor : .clear, lineWidth: 3))
                        .scaleEffect(selection == a ? 1.1 : 1)
                        .popIn(i)
                }
                .buttonStyle(BouncyButtonStyle())
                .accessibilityLabel(Avatars.names[a] ?? a)
                .accessibilityAddTraits(selection == a ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

extension UIImage {
    func resizedSquare(_ side: CGFloat) -> UIImage {
        let s = min(size.width, size.height)
        let crop = CGRect(x: (size.width - s) / 2, y: (size.height - s) / 2, width: s, height: s)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            draw(in: CGRect(x: -crop.minX * side / s, y: -crop.minY * side / s, width: size.width * side / s, height: size.height * side / s))
        }
    }
}

// MARK: Recuperar acceso
struct RecoverView: View {
    @State var email: String
    @State private var sent = false
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        GameForm {
            Section {
                TextField("Correo electrónico", text: $email)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
            } header: { SectionTitle(text: "Te enviaremos un enlace para restablecer tu contraseña.").listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 6, trailing: 4)) }
            Section {
                PrimaryButton(title: "Enviar enlace", systemImage: "envelope.fill", loading: loading) {
                    loading = true
                    defer { loading = false }
                    do { try await supabase.auth.resetPasswordForEmail(email); sent = true }
                    catch { self.error = friendlyError(error) }
                }
                .disabled(!email.contains("@"))
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if sent {
                Section {
                    Label("Si el correo está registrado, recibirás el enlace en unos minutos. Revisa también la carpeta de spam.",
                          systemImage: "info.circle")
                        .font(.subheadline)
                }
            }
        }
        .gameTitle("Recuperar acceso")
        .navigationBarTitleDisplayMode(.inline)
        .errorAlert($error)
    }
}

// MARK: Reglas
struct RulesView: View {
    private let rules: [(String, String, String)] = [
        ("1. Sale una letra", "El servidor sortea una letra al azar para todos a la vez.", "textformat.abc"),
        ("2. Completa las categorías", "Escribe una palabra por categoría que empiece con esa letra.", "square.and.pencil"),
        ("3. ¡STOP!", "El primero que termina presiona STOP, los demás tienen unos segundos para cerrar.", "hand.raised.fill"),
        ("4. La IA arbitra", "Valida cada respuesta y explica por qué la acepta o la rechaza.", "sparkles"),
        ("5. Suma puntos", "10 por respuesta única, 5 si se repite, 0 si es inválida o vacía.", "plus.forwardslash.minus"),
    ]

    var body: some View {
        List(rules, id: \.0) { r in
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.0).font(.headline)
                    Text(r.1).font(.subheadline).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: r.2).foregroundStyle(Color.accentColor)
            }
            .padding(.vertical, 6)
        }
        .gameTitle("Reglas")
    }
}
