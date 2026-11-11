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
- SvelteKit + Svelte 5 (runes), adaptador Vercel. Usa las **mismas RPC/tablas** que iOS (`src/lib/api.ts` ↔ `API.swift`,
  `src/lib/game/game.svelte.ts` ↔ `GameStore.swift`, `src/lib/app.svelte.ts` ↔ `AppState.swift`): web e iOS juegan juntos.
- Importes con alias `#lib/...` y extensión explícita (`.ts`, `.svelte.ts`). Arte y sonidos copiados en `static/`.
- **Rutas públicas prerenderizadas (SEO)**: `/` landing (`src/lib/landing/`: `RoundDemo` animado, `Seo` con OG/Twitter/
  JSON-LD VideoGame + FAQPage, `SiteChrome`), `/como-jugar` (HowTo), `/terminos`, `/privacidad`. `static/`: `robots.txt`,
  `sitemap.xml`, `manifest.webmanifest`, `og.png` (generada con `tools/make_og.py`), íconos PWA.
- **Juego (grupo `(app)`, `ssr = false`, `noindex`)**: `/jugar` (inicio), `/salas`, `/crear` (con categorías por IA),
  `/sala/[id]`, `/perfil` (avatar, nombre, estadísticas, logros, historial, ajustes, cuenta, guardar progreso del invitado),
  `/avisos` (notificaciones in-app + realtime), `/amigos` (enlace, solicitudes, búsqueda, eliminar), `/restablecer`,
  `/j/[code]`, `/a/[token]`. `/auth/confirm` verifica los enlaces de correo con `token_hash` (no depende de PKCE).
- Resultados: detalle de respuesta (`AnswerSheet`: explicación, checks, impugnación, reporte/silenciar) y reacciones.
- Invitado web → cuenta: `updateUser({email})` + confirmación, luego crear contraseña (Supabase no permite contraseña a un
  anónimo sin correo verificado). En web no hay Iniciar sesión con Apple.
- Responsive: una columna en móvil; en ≥900–1024 px paneles en dos columnas y la sala con jugadores/chat al lado.
- Dev: `cd webapp && npm run dev`. Verificar: `npx svelte-check` y `npm run build`.
- Producción: proyecto Vercel `tutifruti-web` → **https://tutifruti.site** (+ `www`), dominio de Namecheap con
  nameservers `ns1/ns2.vercel-dns.com`. Despliegue **automático**: cada push a `main` despliega (root `webapp/`; solo
  construye si cambió esa carpeta). El sitio de invitaciones (`web/`, proyecto `tutifruti-ai`) igual con root `web/`;
  su portada redirige a tutifruti.site y en Android/computadora `/j/` y `/a/` abren la web.

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

## Invitados
- Invitado (anónimo) = solo jugar: apodo + avatar (nombre único automático `apodo####`), sin amigos
  (`008_guests.sql` bloquea amistades y búsqueda de invitados). iOS: "Guardar mi progreso" vincula Apple
  (`linkIdentityWithIdToken`). Web: vincula un correo (ver Versión web). "Salir del modo invitado" borra la cuenta
  temporal; los invitados inactivos > 7 días se borran solos (pg_cron).

## Pendientes (estado al 2026-11-11)

### Correo y autenticación (prioridad alta)
- [ ] **SMTP propio** en Supabase (p. ej. Resend con dominio `tutifruti.site`): el correo por defecto solo entrega a
      miembros del equipo, así que registro, "olvidé mi contraseña" y "guardar progreso" del invitado en web no llegan
      a usuarios reales.
- [ ] **Plantillas de correo** (Auth → Emails) en español y con enlace
      `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=<signup|recovery|email_change>`. Sin esto, un
      correo pedido desde el iPhone (PKCE) no se puede completar al abrirlo en otro dispositivo.
- [ ] iOS: pasar `redirectTo` en `resetPasswordForEmail`/registro y tener pantalla para la nueva contraseña (hoy solo
      "Cambiar contraseña" en Cuenta). Con las plantillas `token_hash`, el enlace abre la web y ahí se cambia.
- [ ] Decidir si se mantiene la confirmación por correo (`mailer_autoconfirm: false`).
- [ ] Probar Sign in with Apple en un dispositivo/simulador con Apple ID (configurado el 2026-11-10).
- [ ] Iniciar sesión con Apple en la web: requiere Services ID + clave .p8 en Supabase (OAuth web).
- [ ] Crear el correo `contacto@tutifruti.site` (lo citan Términos y Privacidad); el DNS ya está en Vercel, así que
      el reenvío de Namecheap no sirve: usar un proveedor (ImprovMX, Zoho, Google Workspace…) y sus registros MX en Vercel.

### Pruebas
- [ ] **Probar end-to-end en el simulador con dos cuentas** (sala privada, pública, ronda, STOP, validación IA,
      resultados, impugnación, clasificación final, subida de nivel).
- [x] Web probada contra un bot (2026-11-11): ronda, STOP, validación IA, impugnación (resuelta por la 2.ª IA),
      reacciones, final, logros y avisos.
- [ ] Probar la web en ancho de móvil y en Safari/iPhone; partida mixta web + iOS en la misma sala.
- [ ] Borrar datos de prueba: sala "Prueba IA" y usuarios anónimos `pruebaa*`/`pruebab*` (2026-11-10).
- [ ] Tests (unitarios del store y UI tests) y CI (GitHub Actions: `svelte-check` + `build` de `webapp/`).

### Funcionalidad que falta o está simplificada
- [ ] **Notificaciones push (APNs)**: hoy solo hay notificaciones in-app (tabla `notifications` + realtime + toast).
      Falta registro de device token, tabla de tokens y Edge Function/trigger que envíe a APNs respetando `notif_prefs`.
      (En web se podría sumar Web Push.)
- [ ] **Validar compras de StoreKit en el servidor**: `grant_item` se llama desde la app (cualquiera podría darse Plus).
      Implementar App Store Server API / notificaciones de servidor v2 en una Edge Function.
- [ ] Crear los productos reales en App Store Connect (IDs en `StoreManager` y `Products.storekit`). La web no vende.
- [ ] Publicar la app en App Store y enlazarla desde la landing (hoy dice "también en iPhone" sin enlace).
- [ ] **Temas visuales** ("Pizarra", "Neón"): se guardan en `profiles.theme` pero la UI no los aplica todavía.
- [ ] **Idioma de juego**: se guarda en `profiles.language` pero la IA y la UI siguen en español.
- [ ] Notificación "amigo conectado" (`friend_online`) y "inicio de temporada" (`season`): las preferencias existen,
      pero nada las genera.
- [ ] Logros `polyglot` y `season_top100` no se desbloquean (no hay lógica; la web los oculta); cierre de temporada y
      recompensas de temporada no implementados.
- [ ] Moderación: los reportes se guardan en `reports` pero no hay panel ni acciones; silenciar solo filtra el chat
      en cliente.
- [ ] El árbitro a veces marca `checks.letter = true` en respuestas que no empiezan con la letra (visto con "Mesa" en
      ronda D): revisar el prompt/esquema de `validate-round`.
- [ ] `public.rooms`/`room_players`/`rounds`/`profiles` son legibles por cualquier usuario autenticado; endurecer RLS
      si se necesita más privacidad.
- [ ] Pantalla de lanzamiento personalizada en iOS.
- [ ] Renombrar migraciones al formato con timestamp del CLI si se va a usar `supabase db push`.
- [ ] SEO: dar de alta https://tutifruti.site en Google Search Console y enviar el `sitemap.xml`.

### Hecho recientemente
- [x] Edge Functions desplegadas y `GEMINI_API_KEY` configurado (2026-11-10).
- [x] Auth: anonymous sign-ins, Apple nativo, **Allow manual linking**, URL Configuration con tutifruti.site (2026-11-11).
- [x] pg_cron (`011_cleanup_cron.sql`, 2026-11-11): `cleanup_guests()` diario 04:30 UTC y `cleanup_rooms()` cada 15 min
      (cancela salas `waiting`/`playing` sin nadie conectado hace > 30 min).
- [x] Páginas reales de Términos y Privacidad (`tutifruti.site/terminos`, `/privacidad`), enlazadas desde iOS y web.
- [x] Landing + SEO, versión web completa y despliegue automático GitHub → Vercel (2026-11-11).
- [x] Ícono de la app (2026-11-10).

### Seguridad
- [ ] **Rotar las claves** (secret key, service role, contraseña de la base, Gemini): se compartieron por chat. Después
      de rotarlas, actualizar `CLAUDE.local.md` y el secreto `GEMINI_API_KEY` de las Edge Functions.
- [x] Git inicializado con `.gitignore`; las credenciales viven en `CLAUDE.local.md` (no versionado). El repo es
      público: revisar que ningún commit futuro incluya claves.

## Convenciones
- Responder y escribir la UI en español.
- Componentes nativos de iOS como base, con la capa de marca/mascota/animación encima. Nada de emojis.
- Las mutaciones de juego van por RPC, nunca con updates directos desde la app.
