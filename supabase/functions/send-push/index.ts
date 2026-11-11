// Envía una notificación (fila de public.notifications) a los dispositivos iOS del jugador vía APNs.
// La invoca el trigger push_notification (pg_net) con la cabecera x-push-secret.
// Secretos: PUSH_WEBHOOK_SECRET, APNS_TEAM_ID, APNS_BUNDLE_ID (opcional) y una clave por entorno (las claves
// "Topic Specific" de Apple valen para un solo entorno): APNS_KEY + APNS_KEY_ID (producción) y
// APNS_KEY_SANDBOX + APNS_KEY_ID_SANDBOX (desarrollo). Si falta la de sandbox se usa la de producción
// (sirve cuando la clave es "Sandbox & Production").
import { importPKCS8, SignJWT } from "npm:jose@5";
import { json, serviceClient } from "../_shared/ai.ts";

const BUNDLE = Deno.env.get("APNS_BUNDLE_ID") ?? "com.carlosordaz.tutifruti";
const cached: Record<string, { jwt: string; at: number }> = {};

function credentials(sandbox: boolean): { key: string; kid: string } | null {
  const key = (sandbox && Deno.env.get("APNS_KEY_SANDBOX")) || Deno.env.get("APNS_KEY");
  const kid = (sandbox && Deno.env.get("APNS_KEY_SANDBOX") && Deno.env.get("APNS_KEY_ID_SANDBOX")) || Deno.env.get("APNS_KEY_ID");
  return key && kid ? { key, kid } : null;
}

async function providerToken(sandbox: boolean): Promise<string | null> {
  const cred = credentials(sandbox);
  if (!cred) return null;
  // APNs acepta el mismo token hasta 60 min; se renueva a los 50.
  const hit = cached[cred.kid];
  if (hit && Date.now() - hit.at < 50 * 60_000) return hit.jwt;
  const key = await importPKCS8(cred.key.replace(/\\n/g, "\n"), "ES256");
  const jwt = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: cred.kid })
    .setIssuer(Deno.env.get("APNS_TEAM_ID")!)
    .setIssuedAt()
    .sign(key);
  cached[cred.kid] = { jwt, at: Date.now() };
  return jwt;
}

type Notif = { id: number; user_id: string; kind: string; title: string; body: string | null; payload: Record<string, unknown> };

Deno.serve(async (req) => {
  const secret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-push-secret") !== secret) return json({ error: "forbidden" }, 403);
  if (!Deno.env.get("APNS_KEY") && !Deno.env.get("APNS_KEY_SANDBOX")) return json({ status: "apns-not-configured" });
  try {
    const n = (await req.json()) as Notif;
    const db = serviceClient();
    const { data: tokens } = await db.from("push_tokens").select("token, sandbox").eq("user_id", n.user_id);
    if (!tokens?.length) return json({ status: "no-tokens" });

    const { count: unread } = await db.from("notifications").select("*", { count: "exact", head: true })
      .eq("user_id", n.user_id).eq("read", false);
    const body = JSON.stringify({
      aps: {
        alert: { title: n.title, body: n.body ?? "" },
        sound: "default",
        badge: unread ?? 0,
        "thread-id": n.kind,
      },
      kind: n.kind,
      ...n.payload,
    });
    let sent = 0;
    for (const t of tokens) {
      const jwt = await providerToken(t.sandbox);
      if (!jwt) continue;
      const host = t.sandbox ? "api.sandbox.push.apple.com" : "api.push.apple.com";
      const res = await fetch(`https://${host}/3/device/${t.token}`, {
        method: "POST",
        headers: {
          authorization: `bearer ${jwt}`,
          "apns-topic": BUNDLE,
          "apns-push-type": "alert",
          "apns-priority": "10",
          "apns-collapse-id": `${n.kind}-${n.id}`,
        },
        body,
      });
      if (res.ok) { sent++; continue; }
      const reason = (await res.json().catch(() => ({})))?.reason ?? String(res.status);
      if (res.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered") {
        await db.from("push_tokens").delete().eq("token", t.token);
      } else {
        console.error("APNs", res.status, reason);
      }
    }
    return json({ status: "ok", sent });
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});
