# Plantillas de correo (Supabase Auth → Emails)

Pegadas en el dashboard el 2026-11-11. El enlace va a `tutifruti.site/auth/confirm` con `token_hash` (no depende de PKCE):
la web confirma, o en iPhone reenvía a la app (`tutifruti://auth/callback`) si el correo se pidió desde la app.

- `confirmation.html` — asunto: "Confirma tu cuenta de Tutifruti AI"
- `recovery.html` — asunto: "Restablece tu contraseña de Tutifruti AI"
- `email_change.html` — asunto: "Confirma tu nuevo correo en Tutifruti AI"
- `magic_link.html` — asunto: "Tu enlace para entrar a Tutifruti AI"
