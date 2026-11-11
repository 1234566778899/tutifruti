// Segunda opinión IA para una impugnación.
import { askJSON, cors, json, serviceClient, userClient } from "../_shared/ai.ts";

const SYSTEM = `Eres un segundo árbitro independiente del juego Stop / Basta / Tutifruti en español.
Un jugador impugnó la evaluación de una respuesta. Evalúa desde cero, sin asumir que el primer árbitro tenía razón
ni que el jugador la tiene. Sé justo y consistente. "resolution" es una explicación breve (máx. 160 caracteres) en español.`;

const KIND: Record<string, string> = {
  my_valid: "El jugador defiende que su respuesta debió ser VÁLIDA.",
  other_invalid: "El jugador sostiene que la respuesta de otro jugador es INVÁLIDA.",
  not_duplicate: "El jugador sostiene que su respuesta NO debió contarse como duplicada.",
};

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["accept", "resolution"],
  properties: { accept: { type: "boolean" }, resolution: { type: "string" } },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { dispute_id } = await req.json();
    const { data: mine } = await userClient(req).from("disputes").select("id").eq("id", dispute_id).maybeSingle();
    if (!mine) return json({ error: "Impugnación no encontrada" }, 404);

    const db = serviceClient();
    const { data: d } = await db.from("disputes").select("*").eq("id", dispute_id).single();
    if (d.status !== "pending") return json(d);
    const { data: round } = await db.from("rounds").select("letter").eq("id", d.round_id).single();
    const { data: a } = await db.from("answers").select("value, status, reason")
      .match({ round_id: d.round_id, user_id: d.target_user, category: d.category }).single();

    const res = await askJSON<{ accept: boolean; resolution: string }>(
      SYSTEM,
      `Letra: ${round.letter}\nCategoría: ${d.category}\nRespuesta: "${a.value}"\n` +
        `Evaluación original: ${a.status} — ${a.reason ?? ""}\n${KIND[d.kind]}\nJustificación del jugador: ${d.justification}\n\n` +
        `¿Procede la impugnación?`,
      SCHEMA,

    );
    const { data: out, error } = await db.rpc("_apply_dispute", {
      p_dispute: dispute_id, p_accept: res.accept, p_resolution: res.resolution,
    });
    if (error) throw error;
    return json(out);
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});
