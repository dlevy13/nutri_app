import * as fs from "fs";
import * as path from "path";
import axios from "axios";


// ✅ Gen 2 imports
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

import { defineSecret } from "firebase-functions/params";
const MISTRAL_API_KEY = defineSecret("MISTRAL_API_KEY");

// ----- Options globales Gen 2 (CPU, mémoire, région, timeout)
type FFMatch<T> = { item: T; score: number };

// --- Types simples
type FoodRow = {
  name: string;       // libellé CIQUAL (FR)
  calories: number;   // kcal /100g
  protein: number;    // g /100g
  carbs: number;      // g /100g
  fat: number;        // g /100g
};

type LlmItem = { name: string; quantity: number; unit?: string };

// --- Clé Mistral via env (.env en local ou vars de déploiement)
const MISTRAL_KEY = process.env.MISTRAL_API_KEY;

// --- Helpers
function normalizeLabel(s: string): string {
  return (s || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9 ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function toGrams(qty: number, unit?: string): number {
  const u = (unit || "g").toLowerCase();
  if (u === "g" || u === "grammes" || u === "gramme") return qty;
  if (u === "kg") return qty * 1000;
  if (u === "ml") return qty; // densité 1 g/ml par défaut
  if (u === "piece" || u === "pièce" || u === "pcs") return qty * 50;
  return qty;
}

function per100ToTotals(per100: FoodRow, grams: number) {
  const f = grams / 100;
  return {
    kcal: +(per100.calories * f).toFixed(1),
    protein: +(per100.protein * f).toFixed(1),
    carbs: +(per100.carbs * f).toFixed(1),
    fat: +(per100.fat * f).toFixed(1),
  };
}

// --- Charge la table CIQUAL (place le JSON dans functions/assets/)
const FOOD_PATH = path.join(process.cwd(), "assets", "food_data.json"); // ✅ Gen2 runtime cwd = functions/
if (!fs.existsSync(FOOD_PATH)) {
  logger.error("❌ assets/food_data.json manquant. Place le fichier dans functions/assets/food_data.json");
}
const RAW_FOOD: unknown = fs.existsSync(FOOD_PATH)
  ? JSON.parse(fs.readFileSync(FOOD_PATH, "utf8"))
  : [];

function isFoodRow(x: any): x is FoodRow {
  return x && typeof x.name === "string";
}

function sanitizeFood(rows: unknown): FoodRow[] {
  if (!Array.isArray(rows)) return [];
  const seen = new Set<string>();
  const out: FoodRow[] = [];
  for (const r of rows) {
    if (!isFoodRow(r)) continue;
    const name = (r.name || "").trim();
    if (!name) continue;
    const key = name.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({
      name,
      calories: Number((r as any).calories || 0),
      protein: Number((r as any).protein || 0),
      carbs: Number((r as any).carbs || 0),
      fat: Number((r as any).fat || 0),
    });
  }
  return out;
}

const CIQUAL: FoodRow[] = sanitizeFood(RAW_FOOD);

// ----- Handler Gen 2
export const decomposeMeal = onRequest(
  {
    region: "us-central1",
    cpu: 1,            // ✅ Gen 2
    memory: "512MiB",    // ✅ Gen 2
    timeoutSeconds: 60,
    secrets: [MISTRAL_API_KEY],
    // cors: true // (si tu veux que la lib gère le CORS automatiquement)
  },
  async (req, res) => {
    const { search } = await import("fast-fuzzy");
  // CORS
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  logger.info("[decomposeMeal TS v2] start", { bodyKeys: Object.keys(req.body || {}) });

  if (!MISTRAL_KEY) {
    res.status(500).json({ error: "Clé API Mistral manquante (MISTRAL_API_KEY)" });
    return;
  }
  if (!CIQUAL.length) {
    res.status(500).json({ error: "Base CIQUAL vide (functions/assets/food_data.json non chargé)" });
    return;
  }

  try {
    // ✅ accepte 'description' OU 'text'
    const body = req.body || {};
    const desc: string = (body.description ?? body.text ?? "").toString().trim();
    const servings: number = Number(body.servings ?? 1);

    if (!desc) {
      res.status(400).json({ error: "Missing 'description' or 'text'" });
      return;
    }

    // 1) Appel Mistral — prompt robuste
    const payload = {
      model: "mistral-small-latest",
      temperature: 0.2,
      max_tokens: 700,
      messages: [
        {
          role: "system",
          content:
            "Tu es un extracteur d'ingrédients. Réponds STRICTEMENT par un tableau JSON (et rien d'autre). " +
            "Schéma: [{\"name\": string, \"quantity\": number, \"unit\": \"g\"|\"ml\"|\"piece\"}]. " +
            "Décompose les plats composés en ingrédients de base. Le 'name' doit être concis en FR.",
        },
        {
          role: "user",
          content:
            "Exemples de réponse attendue (tu ne dois renvoyer que le tableau, sans texte autour) :\n" +
            "Entrée: \"pates bolo\"\n" +
            "[{\"name\":\"Pâtes cuites\",\"quantity\":180,\"unit\":\"g\"},{\"name\":\"Sauce bolognaise\",\"quantity\":120,\"unit\":\"g\"}]\n\n" +
            "Entrée: \"salade verte avec vinaigrette\"\n" +
            "[{\"name\":\"Salade verte\",\"quantity\":80,\"unit\":\"g\"},{\"name\":\"Vinaigrette\",\"quantity\":15,\"unit\":\"g\"}]",
        },
        { role: "user", content: desc },
      ],
    };

    const r = await axios.post(
      "https://api.mistral.ai/v1/chat/completions",
      payload,
      {
        headers: {
          Authorization: `Bearer ${MISTRAL_KEY}`,
          "Content-Type": "application/json",
        },
        timeout: 45000,
      }
    );

    const content = r.data?.choices?.[0]?.message?.content ?? "";
    let items: LlmItem[] = [];

    // 2) Parsing tolérant
    try {
      const trimmed = (content || "").trim();

      if ((trimmed.startsWith("[") && trimmed.endsWith("]")) ||
          (trimmed.startsWith("{") && trimmed.endsWith("}"))) {
        const parsed = JSON.parse(trimmed);
        if (Array.isArray(parsed)) {
          items = parsed as LlmItem[];
        } else if (parsed && Array.isArray((parsed as any).ingredients)) {
          items = (parsed as any).ingredients as LlmItem[];
        }
      }

      if (!items.length) {
        const arrMatch = content.match(/\[[\s\S]*\]/);
        if (arrMatch) {
          const parsed = JSON.parse(arrMatch[0]);
          if (Array.isArray(parsed)) items = parsed as LlmItem[];
        }
      }

      // Nettoyage
      items = (items || []).map(x => ({
        name: String(x?.name ?? "").trim(),
        quantity: Number(x?.quantity ?? 0),
        unit: (x?.unit ?? "g") as string,
      })).filter(x => x.name && Number.isFinite(x.quantity) && x.quantity > 0);

      if (!items.length) {
        logger.error("❌ LLM sans items utilisables", { preview: content.slice(0, 200) });
        res.status(502).json({ error: "Réponse IA vide ou invalide" });
        return;
      }
    } catch (e) {
      logger.error("❌ Parsing JSON LLM", e as any);
      res.status(502).json({ error: "Réponse IA invalide (non-JSON)" });
      return;
    }

    // 3) Normalisation CIQUAL + calcul
    const ingredients: any[] = [];
    const totals = { kcal: 0, protein: 0, carbs: 0, fat: 0 };

    for (const it of items) {
      const qty = Number(it?.quantity ?? 0);
      if (!Number.isFinite(qty) || qty <= 0) continue;

      const unit = (it?.unit || "g").toLowerCase();
      const grams = toGrams(qty, unit);
      if (grams <= 0) continue;

      const query = (it?.name || "").toString().trim();
      if (!query) continue;

      const qNorm = normalizeLabel(query);
      const results = search(qNorm, CIQUAL, {
        keySelector: (row: FoodRow) => normalizeLabel(row.name),
        threshold: 0.5,
        ignoreCase: true,
        returnMatchData: true,
      }) as FFMatch<FoodRow>[];

      const best = results[0];
      if (!best) continue;

      const matchedItem = best.item;
      const score = best.score;
      if (score < 0.45) continue;

      const macros = per100ToTotals(matchedItem, grams);

      totals.kcal += macros.kcal;
      totals.protein += macros.protein;
      totals.carbs += macros.carbs;
      totals.fat += macros.fat;

      ingredients.push({
        name: matchedItem.name,
        quantity: +grams.toFixed(1),
        unit: "g",
        confidence: +Math.min(1, Math.max(0, score)).toFixed(2),
        ...macros,
      });
    }

    res.json({
      impl: "ts-v2",  // ✅ marqueur clair
      dish_normalized: desc,
      servings,
      ingredients,
      totals: {
        kcal: +totals.kcal.toFixed(1),
        protein: +totals.protein.toFixed(1),
        carbs: +totals.carbs.toFixed(1),
        fat: +totals.fat.toFixed(1),
      },
    });
  } catch (err) {
    logger.error("Erreur decomposeMeal:", err as any);
    res.status(500).json({ error: "Erreur interne (IA ou CIQUAL)" });
  }
});
