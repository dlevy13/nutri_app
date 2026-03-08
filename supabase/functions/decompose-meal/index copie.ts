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
      return json({ error: "Method Not Allowed" }, 405);
    }

    /* ----------------------------- ENV ------------------------------ */
    const MISTRAL_API_KEY = Deno.env.get("MISTRAL_API_KEY");
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
    const SUPABASE_SERVICE_ROLE_KEY =
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!MISTRAL_API_KEY) {
      return json({ error: "MISTRAL_API_KEY missing" }, 500);
    }
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return json({ error: "Supabase env missing" }, 500);
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
      return json({ error: "Invalid JSON body" }, 400);
    }

    const description = String(body.description ?? body.text ?? "").trim();
    const servings = Number(body.servings ?? 1);

    if (!description) {
      return json({ error: "Missing description" }, 400);
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
                "Tu es un extracteur d'ingrédients. Réponds STRICTEMENT par un JSON : " +
                "{ ingredients: [{ name: string, quantity: number, unit: string }] }",
            },
            { role: "user", content: description },
          ],
        }),
      }
    );

    if (!mistralResp.ok) {
      const errText = await mistralResp.text();
      console.error("❌ MISTRAL ERROR", mistralResp.status, errText);

      return json(
        {
          error: "Mistral API error",
          status: mistralResp.status,
          detail: errText,
        },
        502
      );
    }

    const mistralJson = await mistralResp.json();
    const content =
      mistralJson?.choices?.[0]?.message?.content ?? "";

    let items: { name: string; quantity: number; unit?: string }[] =
      [];

    try {
      const parsed = JSON.parse(content);
      items = Array.isArray(parsed)
        ? parsed
        : parsed.ingredients ?? [];
    } catch {
      return json({ error: "Invalid IA JSON" }, 502);
    }

    if (!items.length) {
      return json({ error: "Empty IA response" }, 502);
    }

    /* ---------------------- CIQUAL MATCHING -------------------------- */
    const ingredients: any[] = [];
    const totals = { kcal: 0, protein: 0, carbs: 0, fat: 0 };

    for (const it of items) {
      const qty = Number(it.quantity ?? 0);
      if (!qty || !it.name) continue;

      const grams = qty * normalizeUnit(it.unit);
      if (!grams) continue;

      const { data, error } = await supabase.rpc(
        "search_ciqual",
        {
          q: it.name,
          limit_n: 1,
        }
      );

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
    }

    /* ---------------------------- RESULT ----------------------------- */
    return json({
      impl: "supabase-ciqual-complete",
      dish_normalized: description,
      servings,
      ingredients,
      totals: {
        kcal: +totals.kcal.toFixed(1),
        protein: +totals.protein.toFixed(1),
        carbs: +totals.carbs.toFixed(1),
        fat: +totals.fat.toFixed(1),
      },
    });
  } catch (e) {
    console.error("❌ UNCAUGHT EDGE ERROR", e);

    return new Response(
      JSON.stringify({
        error: "Internal server error",
        detail: String(e),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});
