// Cliente compartido de IA (Gemini) para las Edge Functions de Tutifruti AI.
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

export const MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-3.5-flash-lite";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

export function serviceClient(): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
}

/** Cliente con el JWT del jugador: respeta RLS, sirve para comprobar permisos. */
export function userClient(req: Request): SupabaseClient {
  return createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
}

/** Llama a Gemini con salida JSON estructurada (JSON Schema) y devuelve el objeto parseado. */
export async function askJSON<T>(system: string, user: string, schema: Record<string, unknown>, timeoutMs = 20000): Promise<T> {
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
    method: "POST",
    signal: AbortSignal.timeout(timeoutMs),
    headers: { "Content-Type": "application/json", "x-goog-api-key": Deno.env.get("GEMINI_API_KEY")! },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: user }] }],
      generationConfig: {
        responseMimeType: "application/json",
        responseJsonSchema: schema,
        thinkingConfig: { thinkingLevel: "minimal" },
        temperature: 0,
      },
    }),
  });
  if (!res.ok) throw new Error(`Gemini ${res.status}: ${(await res.text()).slice(0, 300)}`);
  const data = await res.json();
  const text = data?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text ?? "").join("") ?? "";
  if (!text) throw new Error(`Gemini sin respuesta (${data?.candidates?.[0]?.finishReason ?? "?"})`);
  return JSON.parse(text) as T;
}
