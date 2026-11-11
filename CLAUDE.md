# Tutifruti AI — iOS

Juego de Stop / Basta / Tutifruti multijugador con un árbitro de IA que valida cada respuesta.
Diseño (wireframes en grises, 12 módulos, ~60 pantallas):
https://www.figma.com/design/P8AAzV4oac2pY8r4GKSKiQ/tutifruti?node-id=3260-2

## Stack
- **iOS**: SwiftUI nativo (iOS 17+, `@Observable`), componentes estándar de iOS (List, Form, NavigationStack,
  TabView, sheets, Swift Charts, StoreKit 2) con capa de "vida": paleta `Brand` (naranja→rosa), mascota, sonidos y
  animaciones (ver "Arte, sonido y animación").
- **Backend**: Supabase (Auth, Postgres + RLS, Realtime, Edge Functions).
- **IA**: Gemini `gemini-3.5-flash-lite` con `thinkingLevel: minimal` (~2 s por ronda) en Edge Functions.
  `thinkingBudget: 0` da 400 en los modelos 3.x lite; `gemini-2.5-flash-lite` ya no está disponible.
- Proyecto Xcode generado con **XcodeGen** (`project.yml`). Regenerar con `xcodegen generate`.

## Arte, sonido y animación
- **Estilo "arcade frutal"** (original, no copiar otros juegos): `Views/Components/GameTheme.swift` → paleta `Game`
  (verde azulado profundo + crema + naranja/lima/cereza/cielo con contorno café). **Color principal: amarillo limón
  `#FFD23F`** (`Game.lemon`, AccentColor y tint) para texto, íconos y pestañas; el naranja solo en rellenos grandes.
  Texto sobre rellenos claros en café (`Game.onFill`), `GameBackground` (patrón `game_pattern`),
  `CandyButtonStyle`, `RoundIconButtonStyle`, `CreamCard`, `GamePanel`, `OutlinedTitle`, `GamePill`, `GameDialog`
  (diálogo ilustrado con Tuti). Usar `GameList`/`GameForm` en lugar de `List`/`Form` (ponen fondo y filas del tema).
  Más piezas: `gameTitle(_:)` (título con contorno; usar en vez de navigationTitle), `GameSegmented` (en vez de
  Picker .segmented), `GameSection("…")` (en vez de Section("…")), `GameMenuRow` (íconos `icon_*` de `art/icons`),
  `GameEmptyState`, `GameToggleLabel`; `PrimaryButton` ya es botón caramelo.
  **Criterio de diseño:** un solo protagonista por pantalla (botón caramelo naranja grande); lo secundario en paneles
  translúcidos (`GamePanel`, `HomeTile`, `SmallActionLabel`) con el color solo en el ícono; acentos en amarillo.
  La app fuerza modo oscuro. Logo: `logo_wordmark` + `logo_badge` (`LogoView`).
- Mascota v2 (ChatGPT, GPT-6 Astra en modo Work): 8 poses con transparencia real en `art/source/poses_v2`
  (+ `tuti_bye`, `tuti_think`). Para nuevos assets: pedir grilla sobre fondo magenta plano y recortar con
  `tools/crop_sheet.py <hoja> <cols> <filas> <nombres> <salida> --key FF00FF`.
- **Sin emojis** en la app ni en la base: avatares = claves (`fox`, `owl`, … `dragon`) → imagen `avatar_<clave>`
  (`Avatars` en `Models.swift`, mapea emojis antiguos). Reacciones = claves (`haha`, `fire`, …) → símbolos SF (`Reactions`).
  Migración `005_no_emoji.sql` (aplicada).
- Arte generado con ChatGPT (hojas en `art/source/`): 18 avatares, mascota **Tuti** (naranja) en 6 poses
  (`tuti_hello/judge/party/sad/stop/sleep`, `MascotView`), ícono de la app (`art/icon.png`).
  `tools/crop_sheet.py` recorta hojas → `art/avatars`, `art/mascot`; `tools/build_assets.py` las pasa a `Assets.xcassets`.
- Sonidos sintetizados con `tools/make_sounds.py` → `Tutifruti/Resources/Sounds/*.wav`; se reproducen con
  `Sfx.play(.tap)` (`SoundManager`, sesión `.ambient`, respeta silencio). Interruptores Sonidos/Vibración en Perfil.
- Componentes en `Views/Components/Fun.swift`: `BrandBackground`, `MascotView`, `ConfettiView`, `GradientButtonStyle`,
  `BouncyButtonStyle`, `CountingText`, `.popIn()`, `FloatingPoints`; en `RoundViews.swift`: `TimerRing`, `SunburstView`, `ThinkingDots`.
- Para compilar en simulador **no** usar `CODE_SIGNING_ALLOWED=NO`: sin firma no hay llavero y la sesión de Supabase no se
  guarda (las RPC fallan con "No autenticado").

## Invitaciones y reconexión
- **Enlace de amistad**: `https://tutifruti-ai.vercel.app/a/<token>` (o `tutifruti://friend/<token>`). Quien lo abre queda
  como amigo al instante (`accept_friend_invite`) y ve `FriendAddedSheet`. Tokens en `friend_invites` (30 días, 200 usos,
  revocables con "Generar un enlace nuevo"); validaciones en `010_friend_links.sql` (invitados, propio enlace, vencido,
  revocado, ya amigos, solicitud pendiente, límite 20/hora y 500 amigos). Se comparte desde `FriendLinkCard` (Amigos).
- Enlace para compartir: `https://tutifruti-ai.vercel.app/j/TUTI-XXXX` (`Config.inviteURL`). Universal Link
  (`applinks:tutifruti-ai.vercel.app`, AASA en `web/.well-known/`) abre la app y se une sola; si no, la página `web/join.html`
  intenta `tutifruti://join/CODE` y muestra el código. Proyecto Vercel `tutifruti-ai` (root `web/`), se despliega solo al hacer push a `main` si cambió `web/`.
- Reconexión: al volver a primer plano `GameStore.appBecameActive()` → `resync()` (reloj, latido, canal realtime, estado,
  reenvío de respuestas); `healthCheck()` reconecta con backoff si el canal cae y recarga cada 10 s como respaldo.
  `AppState.sceneBecameActive()` reactiva notificaciones y vuelve a la partida en curso. Errores de red no muestran alertas.

## Versión web (`webapp/`)
- SvelteKit + Svelte 5 (runes), `ssr = false`, adaptador Vercel. Usa las **mismas RPC/tablas** que iOS
  (`src/lib/api.ts` ↔ `API.swift`, `src/lib/game/game.svelte.ts` ↔ `GameStore.swift`): web e iOS juegan en las mismas salas.
- Importes con alias `#lib/...` y extensión explícita (`.ts`, `.svelte.ts`). Arte y sonidos copiados en `static/`.
- Responsive: una columna en móvil; en ≥1024 px la sala muestra jugadores y chat en un panel lateral.
- Dev: `cd webapp && npm run dev`. Verificar: `npx svelte-check` y `npm run build`.
- Producción: proyecto Vercel `tutifruti-web` → **https://tutifruti.site** (+ `www`), dominio de Namecheap con
  nameservers `ns1/ns2.vercel-dns.com`. Despliegue **automático**: cada push a `main` en GitHub (`1234566778899/tutifruti`) despliega en Vercel
  (root `webapp/`; solo construye si cambió esa carpeta).

## Repositorio
- GitHub **público**: https://github.com/1234566778899/tutifruti (rama `main`). Nunca subir claves: van en `CLAUDE.local.md`
  (ignorado). La publishable key de Supabase sí puede estar en el código.

## Estructura
- `Tutifruti/` — código de la app (App, Models, Services, Views/<módulo>).
- `supabase/migrations/` — `001_schema.sql` (tablas + RLS + realtime), `002_game_logic.sql` (RPCs), `003_seed.sql`.
- `supabase/functions/` — `validate-round`, `resolve-dispute`, `categories-ai` (+ `_shared/ai.ts`).
- `supabase/tests/smoke.sql` — prueba de humo del flujo completo (corre en transacción y hace ROLLBACK).

## Lógica del juego (en Postgres, RPCs SECURITY DEFINER)
- Toda la autoridad está en el servidor; los tiempos usan `now()` del servidor (la app sincroniza con `server_now()`).
- Salas: **privadas** (solo código/invitación) y **públicas** (`create_room(..., p_is_public)`; listadas por
  `list_public_rooms`, se entra con `join_public_room` mientras están en espera; cuentan para rankings). Ya no hay
  partida rápida/matchmaking (`find_public_match` queda sin uso). Migración `007_public_rooms.sql`.
- Flujo: `create_room` / `join_room_by_code` / `join_public_room` → el anfitrión hace `start_game` → por ronda:
  `save_answer` (autoguardado) → `call_stop` → `close_round` → Edge Function `validate-round`
  (respaldo: `validate_round_basic`) → resultados → cada jugador marca listo con `set_round_ready` → cuando
  todos los conectados están listos, `advance_room` pasa a la siguiente ronda o a `_finish_game` (sin avance automático;
  los desconectados >45 s no bloquean; migración `006_round_ready.sql`).
- STOP: disponible al completar el 75 % de las categorías (redondeado arriba; `stop_threshold`, migración
  `009_stop_threshold.sql`). El botón solo aparece al llegar a ese mínimo.
- Puntos: 10 única, 5 repetida, 0 inválida/vacía/dudosa. 2 impugnaciones por partida (`submit_dispute` →
  `resolve-dispute`, respaldo `resolve_dispute_basic`).
- XP por nivel: `250 * nivel`. Logros en `achievements`.
- **Juego minimalista**: la app ya no muestra desafíos, rankings ni temporadas (pestaña Rankings eliminada).
  Las tablas/RPCs (`challenges`, `leaderboard`, `seasons`) siguen en la base sin uso desde la app.

## Aplicar migraciones
```bash
export PGPASSWORD=...   # ver CLAUDE.local.md
psql "host=aws-0-us-east-1.pooler.supabase.com port=5432 user=postgres.liejnmzxlpctqybecrbu dbname=postgres sslmode=require" \
  -v ON_ERROR_STOP=1 -1 -f supabase/migrations/<archivo>.sql
```
La conexión directa `db.<ref>.supabase.co` es solo IPv6 y no resuelve en esta Mac: usar el pooler.

## Desplegar Edge Functions
El CLI está logueado en otra cuenta (no ve este proyecto). Hace falta `supabase login` con la cuenta dueña del proyecto:
```bash
supabase secrets set GEMINI_API_KEY=... --project-ref liejnmzxlpctqybecrbu
supabase functions deploy validate-round resolve-dispute categories-ai --project-ref liejnmzxlpctqybecrbu
```

## Credenciales
Las claves privadas (secret key, service role, contraseña de la base, Gemini) están en `CLAUDE.local.md`, que **no** se
sube al repo (`.gitignore`). Proyecto Supabase: `liejnmzxlpctqybecrbu`; la app y la web solo usan la publishable key.

## Configuración pendiente en el dashboard de Supabase
- Auth → Email: la confirmación de correo está activada (`mailer_autoconfirm: false`); la app lo maneja.
- Auth → Anonymous sign-ins: activado.
- Auth → URL Configuration: Site URL `https://tutifruti.site`; redirects `tutifruti.site/**`, `www.tutifruti.site/**`,
  `tutifruti-web.vercel.app/**` (2026-11-11).
- Auth → Apple: activado para inicio nativo (Client IDs = `com.carlosordaz.tutifruti`). Sin Secret Key: solo hace
  falta para OAuth web (Services ID + .p8), que la app no usa.

## Pendientes (estado al 2026-11-10)

### Bloqueantes para probar el juego completo
- [x] **Edge Functions desplegadas** (2026-11-10) desde el editor del dashboard (`validate-round`, `resolve-dispute`,
      `categories-ai`), cada una como un solo archivo con `_shared/ai.ts` inlinado. Probado: el gateway acepta los JWT
      ES256 de usuario (anónimo) y la función llega a Gemini. Para redesplegar con el CLI hace falta `supabase login`
      con la cuenta dueña.
- [x] **Secreto `GEMINI_API_KEY`** configurado (2026-11-10).
- [ ] **Probar end-to-end en simulador con dos cuentas** (no se crearon cuentas de prueba). Verificar: sala privada,
      partida pública, ronda, STOP, validación IA, resultados, impugnación, clasificación final, subida de nivel.
- [x] Probado contra una ronda real (2026-11-10, vía REST con 2 usuarios anónimos): `validate-round` ~6 s, veredictos
      correctos y `validated_by_ai = true`; `resolve-dispute` ~4 s; `categories-ai` ~2-3 s. Quedaron datos de prueba
      (sala "Prueba IA" y usuarios anónimos `pruebaa*`/`pruebab*`) para borrar a mano.

### Invitados
- Invitado (anónimo) = solo jugar: apodo + avatar (nombre único automático `apodo####`), solo pestaña Inicio, sin amigos
  ni perfil (`008_guests.sql` bloquea amistades y búsqueda de invitados). "Guardar mi progreso" vincula Apple
  (`linkIdentityWithIdToken`); "Salir del modo invitado" borra la cuenta temporal.
- [x] **Auth → Allow manual linking** activado (2026-11-11).
- [x] pg_cron (`011_cleanup_cron.sql`, 2026-11-11): `cleanup_guests()` diario 04:30 UTC y `cleanup_rooms()` cada 15 min
      (cancela salas `waiting`/`playing` sin nadie conectado hace > 30 min).
- [ ] **SMTP propio** en Supabase: el correo por defecto solo entrega a miembros del equipo, así que el registro con
      correo y "olvidé mi contraseña" no llegan a usuarios reales.

### Dashboard de Supabase (Auth)
- [x] **Anonymous sign-ins** activado (2026-11-10).
- [x] **Sign in with Apple** (2026-11-10): App ID `com.carlosordaz.tutifruti` creado en Apple Developer con la
      capability; provider Apple activado en Supabase (flujo nativo `signInWithIdToken`); `DEVELOPMENT_TEAM: JZ9Z9GWH7P`
      en `project.yml`. Falta probarlo en un dispositivo/simulador con Apple ID.
- [ ] Decidir si se mantiene la confirmación por correo (`mailer_autoconfirm: false`). Personalizar plantillas de email
      y configurar el redirect URL de "recuperar contraseña" (hoy no hay pantalla in-app para poner la nueva contraseña
      desde el enlace; solo "Cambiar contraseña" en Cuenta).

### Funcionalidad que falta o está simplificada
- [ ] **Notificaciones push (APNs)**: hoy solo hay notificaciones in-app (tabla `notifications` + realtime + toast).
      Falta registro de device token, tabla de tokens y Edge Function/trigger que envíe a APNs respetando `notif_prefs`.
- [ ] **Validar compras de StoreKit en el servidor**: `grant_item` se llama desde la app (cualquiera podría darse Plus).
      Implementar App Store Server API / notificaciones de servidor v2 en una Edge Function.
- [ ] Crear los productos reales en App Store Connect (IDs en `StoreManager` y `Products.storekit`).
- [ ] **Temas visuales** ("Pizarra", "Neón"): se guardan en `profiles.theme` pero la UI no los aplica todavía.
- [ ] **Idioma de juego**: se guarda en `profiles.language` pero la IA y la UI siguen en español.
- [ ] Notificación "amigo conectado" (`friend_online`) y "inicio de temporada" (`season`): las preferencias existen,
      pero nada las genera.
- [ ] Logros `polyglot` y `season_top100` no se desbloquean (no hay lógica); cierre de temporada y entrega de
      recompensas de temporada no implementados.
- [ ] Moderación: los reportes se guardan en `reports` pero no hay panel ni acciones; filtrar chat de jugadores
      silenciados funciona solo en cliente.
- [ ] `public.rooms`/`room_players`/`rounds`/`profiles` son legibles por cualquier usuario autenticado; endurecer RLS
      si se necesita más privacidad.
- [x] Limpieza de salas abandonadas: `cleanup_rooms()` con pg_cron (ver Invitados).
- [x] Ícono de la app (2026-11-10). Falta pantalla de lanzamiento personalizada.
- [ ] Páginas reales de Términos y Privacidad (hoy apuntan a supabase.com como placeholder).
- [ ] Renombrar migraciones al formato con timestamp del CLI si se va a usar `supabase db push`.
- [ ] Tests (unitarios del store y UI tests) y CI.

### Seguridad
- [ ] Las claves secretas (secret key, service role, DB password, Gemini) se compartieron por chat: considerar
      rotarlas antes de producción. Nunca deben ir en la app; la app solo usa la publishable key.
- [ ] Inicializar git con `.gitignore` y no versionar este `CLAUDE.md` con credenciales en un repo público
      (o moverlas a un archivo ignorado).

## Convenciones
- Responder y escribir la UI en español.
- Componentes nativos de iOS como base, con la capa de marca/mascota/animación encima. Nada de emojis.
- Las mutaciones de juego van por RPC, nunca con updates directos desde la app.
