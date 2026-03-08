import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

/* -------------------------------------------------------------------------- */
/*                                   CORS                                     */
/* -------------------------------------------------------------------------- */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type, apikey",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

/* -------------------------------------------------------------------------- */
/*                                   UTILS                                    */
/* -------------------------------------------------------------------------- */

function normalizeUnit(unit?: string) {
  const u = (unit || "g").toLowerCase();
  if (u === "kg") return 1000;
  if (u === "ml") return 1;
  if (u === "piece" || u === "pièce" || u === "pcs") return 50;
  return 1;
}

const EMPTY_TOTALS = {
  kcal: 0,
  protein: 0,
  carbs: 0,
  fat: 0,
};

function normalizeFoodName(name: string): string {
  const s = (name || "").trim().toLowerCase();

  // Nettoyage léger (garde les espaces)
  const cleaned = s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9\s-]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  // Mapping simple CIQUAL-friendly
  const ALIASES: Record<string, string> = {
    "poulet": "blanc de poulet",
    "blanc de poulet": "blanc de poulet",
    "riz": "riz cuit",
    "riz blanc": "riz cuit",
    "pates": "pâtes cuites",
    "pâtes": "pâtes cuites",
    "steak": "steak haché",
    "viande hachee": "steak haché",
    "oeuf": "œuf",
    "œufs": "œuf",
    "fromage": "fromage (aliment moyen)",
    "yaourt": "yaourt nature",
    "banane": "banane (aliment moyen)",
    "pomme": "pomme (aliment moyen)",
  };

  // remplacements de mots-clés (contains)
  for (const [k, v] of Object.entries(ALIASES)) {
    if (cleaned === k || cleaned.includes(k)) return v;
  }

  return cleaned;
}

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n));
}

function clampQuantity(qty: number, unit?: string): number {
  const u = (unit || "g").toLowerCase();

  if (u === "piece" || u === "pièce" || u === "pcs") {
    // ½ pièce → 4 pièces max
    return clamp(qty, 0.5, 4);
  }

  // grammes / ml
  return clamp(qty, 5, 600);
}

/* -------------------------------------------------------------------------- */
/*                                  HANDLER                                   */
/* -------------------------------------------------------------------------- */

serve(async (req) => {
  try {
    /* ----------------------------- CORS ----------------------------- */
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 200, headers: corsHeaders });
    }

    if (req.method !== "POST") {
      return json(
        {
          ok: false,
          ingredients: [],
          totals: EMPTY_TOTALS,
          error: "Method Not Allowed",
        },
        405
      );
    }

    /* ----------------------------- ENV ------------------------------ */
    const MISTRAL_API_KEY = Deno.env.get("MISTRAL_API_KEY");
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_SERVICE_ROLE_KEY =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!MISTRAL_API_KEY || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({
        ok: false,
        ingredients: [],
        totals: EMPTY_TOTALS,
        error: "Missing env variables",
      });
    }

    const supabase = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY
    );

    /* ----------------------------- BODY ----------------------------- */
    let body: any;
    try {
      body = await req.json();
    } catch {
      return json({
        ok: false,
        ingredients: [],
        totals: EMPTY_TOTALS,
        error: "Invalid JSON body",
      });
    }

    const description = String(body.description ?? body.text ?? "").trim();
    const servings = Number(body.servings ?? 1);

    if (!description) {
      return json({
        ok: false,
        ingredients: [],
        totals: EMPTY_TOTALS,
        error: "Missing description",
      });
    }

    /* ------------------------- MISTRAL IA ---------------------------- */
    const mistralResp = await fetch(
      "https://api.mistral.ai/v1/chat/completions",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${MISTRAL_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "mistral-small-latest",
          temperature: 0.2,
          max_tokens: 700,
          messages: [
            {
              role: "system",
              content:
                "Tu es un expert en nutrition et en bases de données alimentaires françaises (CIQUAL). " +
                "Ta mission est de décomposer un plat en ingrédients simples et génériques, " +
                "compatibles avec une base nutritionnelle standard.\n\n" +

                "RÈGLES STRICTES :\n" +
                "- Réponds UNIQUEMENT en JSON valide\n" +
                "- Aucun texte hors JSON\n" +
                "- Format EXACT attendu :\n" +
                "{ ingredients: [{ name: string, quantity: number, unit: \"g\" | \"ml\" | \"piece\" }] }\n\n" +

                "CONTRAINTES IMPORTANTES :\n" +
                "- Utiliser des ingrédients simples et génériques (ex: \"riz cuit\", \"pâtes cuites\", \"blanc de poulet\")\n" +
                "- Ne jamais inclure de marque\n" +
                "- Ne jamais dupliquer un ingrédient\n" +
                "- Quantités réalistes pour 1 portion adulte\n" +
                "- Ne pas inventer d’ingrédient non mentionné\n" +
                "- Éviter épices, herbes, huiles si non explicitement citées\n" +
                "- Préférer sous-décomposer plutôt que sur-décomposer\n\n" +

                "EXEMPLES :\n" +
                "Entrée: poulet riz\n" +
                "Sortie:\n" +
                "{\"ingredients\":[{\"name\":\"blanc de poulet\",\"quantity\":150,\"unit\":\"g\"}," +
                "{\"name\":\"riz cuit\",\"quantity\":180,\"unit\":\"g\"}]}\n\n" +

                "Entrée: pâtes bolognaise\n" +
                "Sortie:\n" +
                "{\"ingredients\":[{\"name\":\"pâtes cuites\",\"quantity\":180,\"unit\":\"g\"}," +
                "{\"name\":\"sauce bolognaise\",\"quantity\":120,\"unit\":\"g\"}]}" +

                "IMPORTANT :\n" +
                "Ne jamais utiliser de mots génériques comme \“plat\”, \“sauce\”, \“accompagnement\”." +
                "Toujours préférer un ingrédient CIQUAL-compatible"

            },
            { role: "user", content: description },
          ],
        }),
      }
    );

    if (!mistralResp.ok) {
      const detail = await mistralResp.text();
      return json({
        ok: false,
        ingredients: [],
        totals: EMPTY_TOTALS,
        error: "Mistral API error",
        detail,
      });
    }

    const mistralJson = await mistralResp.json();
    const content =
      mistralJson?.choices?.[0]?.message?.content ?? "";

    let items: { name: string; quantity: number; unit?: string }[] =
      [];

    try {
      const match = content.match(/\{[\s\S]*\}/);
      if (!match) throw new Error("No JSON found");
      const parsed = JSON.parse(match[0]);
      items = parsed.ingredients ?? [];
    } catch {
      return json({
        ok: false,
        ingredients: [],
        totals: EMPTY_TOTALS,
        error: "Invalid IA JSON",
        raw: content,
      });
    }

    if (!items.length) {
      return json({
        ok: true,
        dish_normalized: description,
        servings,
        ingredients: [],
        totals: EMPTY_TOTALS,
      });
    }

    /* ---------------------- CIQUAL MATCHING -------------------------- */
    const ingredients: any[] = [];
    const totals = { ...EMPTY_TOTALS };

    for (const it of items) {
  try {
    const rawQty = Number(it?.quantity ?? 0);
    if (!rawQty || rawQty <= 0) continue;

    const clampedQty = clampQuantity(rawQty, it.unit);
    const grams = clampedQty * normalizeUnit(it.unit);
    if (!grams || grams <= 0) continue;

    const normalizedName = normalizeFoodName(it.name);
    if (!normalizedName) continue;

    const { data, error } = await supabase.rpc("search_ciqual", {
      q: normalizedName,
      limit_n: 1,
    });

    if (error || !data?.length) continue;

    const food = data[0];
    if (food.score < 0.45) continue;

    const f = grams / 100;

    const macros = {
      kcal: +(food.calories * f).toFixed(1),
      protein: +(food.protein * f).toFixed(1),
      carbs: +(food.carbs * f).toFixed(1),
      fat: +(food.fat * f).toFixed(1),
    };

    totals.kcal += macros.kcal;
    totals.protein += macros.protein;
    totals.carbs += macros.carbs;
    totals.fat += macros.fat;

    ingredients.push({
      name: food.name,
      quantity: +grams.toFixed(1),
      unit: "g",
      confidence: +food.score.toFixed(2),
      ...macros,
    });
  } catch (e) {
    console.error("❌ ingredient loop error", it, e);
    continue;
  }
}


    /* ---------------------------- RESULT ----------------------------- */
    return json({
      ok: true,
      impl: "supabase-ciqual-complete",
      dish_normalized: description,
      servings,
      ingredients,
      totals,
    });
  } catch (e) {
    console.error("❌ UNCAUGHT EDGE ERROR", e);

    return json(
      {
        ok: false,
        ingredients: [],
        totals: EMPTY_TOTALS,
        error: "Internal server error",
        detail: String(e),
      },
      500
    );
  }
});
