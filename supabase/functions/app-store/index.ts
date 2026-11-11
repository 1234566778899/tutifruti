// Compras de StoreKit 2 validadas en el servidor (reemplaza grant_item desde la app).
// · POST { jws }            (con el JWT del jugador): la app envía Transaction.jwsRepresentation tras comprar o
//                            al restaurar; se verifica la firma de Apple y se otorga el artículo / Plus.
// · POST { signedPayload }  (sin JWT): App Store Server Notifications v2 (renovaciones, reembolsos, vencimientos).
//   URL para App Store Connect: https://liejnmzxlpctqybecrbu.supabase.co/functions/v1/app-store
// Desplegar con --no-verify-jwt (las notificaciones de Apple no traen JWT de Supabase).
import * as x509 from "npm:@peculiar/x509@1";
import { compactVerify, decodeProtectedHeader } from "npm:jose@5";
import { cors, json, serviceClient, userClient } from "../_shared/ai.ts";

x509.cryptoProvider.set(crypto);

const BUNDLE = Deno.env.get("APNS_BUNDLE_ID") ?? "com.carlosordaz.tutifruti";
const PLUS_IDS = ["com.carlosordaz.tutifruti.plus.monthly", "com.carlosordaz.tutifruti.plus.yearly"];
// Apple Root CA - G3 (SHA-256 63:34:3A:BF:…:3E:91:79), https://www.apple.com/certificateauthority/
const APPLE_ROOT_G3 =
  "MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==";
const OID_LEAF = "1.2.840.113635.100.6.11.1";
const OID_INTERMEDIATE = "1.2.840.113635.100.6.2.1";

type Tx = {
  transactionId: string; originalTransactionId: string; bundleId: string; productId: string;
  purchaseDate: number; expiresDate?: number; revocationDate?: number; environment: string;
  appAccountToken?: string; type: string;
};

/** Verifica un JWS firmado por el App Store (cadena x5c hasta Apple Root CA G3) y devuelve su contenido. */
async function verifyApple<T>(jws: string): Promise<T> {
  const { x5c, alg } = decodeProtectedHeader(jws) as { x5c?: string[]; alg?: string };
  if (alg !== "ES256" || !x5c || x5c.length !== 3) throw new Error("JWS sin cadena x5c válida");
  const [leaf, inter, root] = x5c.map((c) => new x509.X509Certificate(c));
  if (x5c[2] !== APPLE_ROOT_G3) throw new Error("La raíz no es Apple Root CA G3");
  if (!leaf.getExtension(OID_LEAF) || !inter.getExtension(OID_INTERMEDIATE)) throw new Error("Certificados sin OID de Apple");
  const now = new Date();
  for (const c of [leaf, inter, root]) if (c.notBefore > now || c.notAfter < now) throw new Error("Certificado vencido");
  if (!(await inter.verify({ publicKey: root, signatureOnly: true }))) throw new Error("Intermedio no firmado por la raíz");
  if (!(await leaf.verify({ publicKey: inter, signatureOnly: true }))) throw new Error("Hoja no firmada por el intermedio");
  const key = await leaf.publicKey.export({ name: "ECDSA", namedCurve: "P-256" }, ["verify"]);
  const { payload } = await compactVerify(jws, key);
  return JSON.parse(new TextDecoder().decode(payload)) as T;
}

/** Guarda la transacción y aplica sus efectos (Plus / artículo). */
async function apply(tx: Tx, userId: string | null) {
  const db = serviceClient();
  if (tx.bundleId !== BUNDLE) throw new Error("Bundle incorrecto");
  // dueño: el de la transacción original si ya existe; si no, el jugador que la envía
  const { data: prev } = await db.from("purchases").select("user_id")
    .eq("original_transaction_id", tx.originalTransactionId).limit(1).maybeSingle();
  const owner = prev?.user_id ?? userId;
  if (!owner) return { status: "unknown-owner" };
  if (userId && prev && prev.user_id !== userId) throw new Error("Esta compra pertenece a otra cuenta");
  if (userId && tx.appAccountToken && tx.appAccountToken.toLowerCase() !== userId.toLowerCase()) {
    throw new Error("La compra se hizo con otra cuenta");
  }

  const isPlus = PLUS_IDS.includes(tx.productId);
  const expires = tx.expiresDate ? new Date(tx.expiresDate).toISOString() : null;
  const revoked = tx.revocationDate ? new Date(tx.revocationDate).toISOString() : null;
  const { error } = await db.from("purchases").upsert({
    transaction_id: tx.transactionId,
    original_transaction_id: tx.originalTransactionId,
    user_id: owner,
    product_id: tx.productId,
    environment: tx.environment,
    purchased_at: new Date(tx.purchaseDate).toISOString(),
    expires_at: expires,
    revoked_at: revoked,
  });
  if (error) throw error;
  const { error: e2 } = await db.rpc("_apply_purchases", { p_user: owner });
  if (e2) throw e2;
  return { status: "ok", product: tx.productId, plus: isPlus };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const body = await req.json();
    if (typeof body.signedPayload === "string") {
      // Notificación del servidor de Apple
      const n = await verifyApple<{ notificationType: string; data?: { bundleId?: string; signedTransactionInfo?: string } }>(body.signedPayload);
      if (n.data?.bundleId && n.data.bundleId !== BUNDLE) return json({ status: "ignored" });
      if (!n.data?.signedTransactionInfo) return json({ status: "ignored", type: n.notificationType });
      const tx = await verifyApple<Tx>(n.data.signedTransactionInfo);
      return json(await apply(tx, null));
    }
    if (typeof body.jws === "string") {
      const { data: { user } } = await userClient(req).auth.getUser();
      if (!user) return json({ error: "No autenticado" }, 401);
      const tx = await verifyApple<Tx>(body.jws);
      return json(await apply(tx, user.id));
    }
    return json({ error: "Solicitud no válida" }, 400);
  } catch (err) {
    console.error(err);
    return json({ error: err instanceof Error ? err.message : String(err) }, 400);
  }
});
