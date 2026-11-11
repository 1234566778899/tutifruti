// Árbitro IA: valida todas las respuestas de una ronda y calcula los puntos.
import { askJSON, cors, json, serviceClient, userClient } from "../_shared/ai.ts";
import { firstLetter } from "../_shared/letters.ts";

type Verdict = {
  id: number;
  status: "valid" | "invalid" | "doubtful";
  reason: string;
  checks: { letter: boolean; category: boolean; real_word: boolean; spelling: boolean };
};

const LANGS: Record<string, string> = { es: "español", en: "inglés", pt: "portugués" };

const system = (lang: string) => `Eres el árbitro del juego Stop / Basta / Tutifruti. La partida se juega en ${LANGS[lang] ?? "español"}.
Las categorías pueden estar escritas en español aunque la partida sea en otro idioma.
Para cada respuesta decides si es válida para su categoría y la letra de la ronda.
Criterios:
- Debe empezar con la letra indicada (ignora mayúsculas y acentos; la Ñ es distinta de la N). Fíjate en la PRIMERA letra
  de la respuesta tal como está escrita: "Mesa" empieza con M, no con D.
- Debe pertenecer claramente a la categoría. Acepta respuestas en ${LANGS[lang] ?? "español"} y nombres de otros idiomas
  si son de uso común.
- Debe ser una palabra o nombre real. Acepta errores ortográficos menores (una letra, acentos faltantes) pero márcalos en "spelling": false.
- Marca "doubtful" solo si es genuinamente ambigua (puede o no pertenecer a la categoría).
- "invalid" si no empieza con la letra, no existe, no pertenece a la categoría o es un intento de trampa.
"reason" es una explicación breve (máx. 120 caracteres) en español neutro, dirigida al jugador.`;

const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["verdicts"],
  properties: {
    verdicts: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["id", "status", "reason", "checks"],
        properties: {
          id: { type: "integer" },
          status: { type: "string", enum: ["valid", "invalid", "doubtful"] },
          reason: { type: "string" },
          checks: {
            type: "object",
            additionalProperties: false,
            required: ["letter", "category", "real_word", "spelling"],
            properties: {
              letter: { type: "boolean" },
              category: { type: "boolean" },
              real_word: { type: "boolean" },
              spelling: { type: "boolean" },
            },
          },
        },
      },
    },
  },
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { round_id } = await req.json();
    // Permisos: el jugador debe ser miembro (la RPC devuelve null si no lo es o si ya no está validando).
    const { data: attempt, error: e1 } = await userClient(req).rpc("mark_validation_attempt", { p_round: round_id });
    if (e1) return json({ error: e1.message }, 403);
    if (attempt === null) return json({ status: "skipped" });

    const db = serviceClient();
    const { data: round } = await db.from("rounds").select("id, letter, status, room_id").eq("id", round_id).single();
    if (!round || round.status !== "validating") return json({ status: "skipped" });
    const { data: room } = await db.from("rooms").select("language").eq("id", round.room_id).single();
    const lang = (room?.language as string | undefined) ?? "es";

    const { data: answers } = await db.from("answers").select("user_id, category, value")
      .eq("round_id", round_id).eq("status", "pending");
    const rows = answers ?? [];
    const empty = rows.filter((a) => a.value.trim() === "");
    const filled = rows.filter((a) => a.value.trim() !== "");

    // Respuestas idénticas se evalúan una sola vez.
    const key = (a: { category: string; value: string }) =>
      `${a.category}|${a.value.trim().toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")}`;
    const unique = [...new Map(filled.map((a) => [key(a), a])).values()];

    const verdicts = new Map<string, Verdict>();
    if (unique.length > 0) {
      const list = unique.map((a, i) => `${i + 1}. [${a.category}] ${a.value.trim()}`).join("\n");
      const res = await askJSON<{ verdicts: Verdict[] }>(
        system(lang),
        `Letra de la ronda: ${round.letter}\nRespuestas (id. [categoría] respuesta):\n${list}\n\nDevuelve un veredicto por cada id.`,
        SCHEMA,
      );
      for (const v of res.verdicts) {
        const a = unique[v.id - 1];
        if (!a) continue;
        // La IA a veces se equivoca con la letra: se comprueba aquí de forma determinista.
        if (firstLetter(a.value) !== round.letter) {
          v.status = "invalid";
          v.checks = { ...v.checks, letter: false };
          v.reason = `No empieza con la letra ${round.letter}.`;
        } else {
          v.checks = { ...v.checks, letter: true };
        }
        verdicts.set(key(a), v);
      }
    }

    for (const a of empty) {
      await db.from("answers").update({ status: "empty", reason: "Sin respuesta.", checks: null })
        .match({ round_id, user_id: a.user_id, category: a.category }).eq("status", "pending");
    }
    for (const a of filled) {
      const v = verdicts.get(key(a));
      if (!v) continue; // queda pendiente → la validación básica la completa si hace falta
      await db.from("answers").update({ status: v.status, reason: v.reason, checks: v.checks })
        .match({ round_id, user_id: a.user_id, category: a.category }).eq("status", "pending");
    }

    const { count } = await db.from("answers").select("*", { count: "exact", head: true })
      .eq("round_id", round_id).eq("status", "pending");
    if ((count ?? 0) > 0) return json({ status: "partial" }, 502);

    const { error: e2 } = await db.rpc("_finish_validation", { p_round: round_id, p_ai: true });
    if (e2) throw e2;
    return json({ status: "ok", evaluated: unique.length });
  } catch (err) {
    console.error(err);
    return json({ error: String(err) }, 500);
  }
});
