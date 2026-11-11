// Genera categorías temáticas o revisa una categoría personalizada.
import { askJSON, cors, json, userClient } from "../_shared/ai.ts";

const GEN_SCHEMA = {
  type: "object", additionalProperties: false, required: ["categories"],
  properties: { categories: { type: "array", items: { type: "string" } } },
};
const CHECK_SCHEMA = {
  type: "object", additionalProperties: false, required: ["ok", "reason"],
  properties: { ok: { type: "boolean" }, reason: { type: "string" } },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { data: { user } } = await userClient(req).auth.getUser();
    if (!user) return json({ error: "No autenticado" }, 401);
    const body = await req.json();

    if (body.action === "generate") {
      const res = await askJSON<{ categories: string[] }>(
        "Diseñas categorías para el juego Stop / Basta en español. Cada categoría debe tener muchas respuestas posibles " +
          "para casi cualquier letra, ser apta para todo público y tener máximo 3 palabras.",
        `Tema: ${String(body.theme).slice(0, 80)}\nPropón exactamente 6 categorías.`,
        GEN_SCHEMA,
      );
      return json({ categories: res.categories.slice(0, 6) });
    }

    if (body.action === "check") {
      const res = await askJSON<{ ok: boolean; reason: string }>(
        "Revisas categorías personalizadas para el juego Stop / Basta. Aprueba si es clara, apropiada para todo público " +
          "y tiene suficientes respuestas posibles. 'reason' en español, máximo 120 caracteres.",
        `Categoría: ${String(body.name).slice(0, 60)}\nDescripción: ${String(body.description ?? "").slice(0, 200)}`,
        CHECK_SCHEMA,
      );
      return json(res);
    }
    return json({ error: "Acción no válida" }, 400);
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});
