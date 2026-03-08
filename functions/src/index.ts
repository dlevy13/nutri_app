// functions/src/index.ts
import * as admin from "firebase-admin";
import axios from "axios";

// Gen 2
import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import { defineSecret } from "firebase-functions/params";

// Initialise Firebase Admin (une seule fois)
admin.initializeApp();

// ---------- Secrets (Gen2) ----------
const STRAVA_CLIENT_ID     = defineSecret("STRAVA_CLIENT_ID");
const STRAVA_CLIENT_SECRET = defineSecret("STRAVA_CLIENT_SECRET");
const MISTRAL_API_KEY      = defineSecret("MISTRAL_API_KEY");
const FS_CLIENT_ID         = defineSecret("FS_CLIENT_ID");
const FS_CLIENT_SECRET     = defineSecret("FS_CLIENT_SECRET");

// ---------- FatSecret token cache ----------
let FS_TOKEN: string | null = null;
let FS_EXPIRY: number | null = null; // epoch ms

async function getFsToken(clientId: string, clientSecret: string): Promise<string> {
  const now = Date.now();
  if (FS_TOKEN && FS_EXPIRY && now < FS_EXPIRY - 30_000) return FS_TOKEN;

  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const resp = await axios.post(
    "https://oauth.fatsecret.com/connect/token",
    "grant_type=client_credentials&scope=basic",
    {
      headers: {
        Authorization: `Basic ${basic}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      timeout: 30000,
    }
  );

  const data = resp.data as { access_token: string; expires_in: number };
  FS_TOKEN = data.access_token;
  FS_EXPIRY = now + Math.max(60, (data.expires_in ?? 3600) - 60) * 1000; // marge 60s
  return FS_TOKEN!;
}


// ---------- CORS helper ----------
function setCors(res: any) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
}

// ---------- OpenFoodFacts proxy (V2) ----------
export const proxyV2 = onRequest(
  { region: "us-central1", timeoutSeconds: 60 },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    try {
      const q = new URLSearchParams((req.query as Record<string, string>) || {}).toString();
      const url = `http://world.openfoodfacts.org/cgi/search.pl?${q}`;
      res.redirect(url);
    } catch (err) {
      logger.error("proxyV2 error", err as any);
      res.status(500).send("Erreur proxy OFF");
    }
  }
);

// ---------- Garmin Calendar proxy (V2) ----------
export const garminCalendarV2 = onRequest(
  { region: "us-central1", timeoutSeconds: 60 },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    try {
      const GARMIN_URL = "https://connect.garmin.com/modern/calendar/export/c99d3fa28b14447d9ad44c23877fad60";
      const resp = await axios.get(GARMIN_URL);
      res.set("Content-Type", "text/calendar");
      res.send(resp.data);
    } catch (err) {
      logger.error("garminCalendarV2 error", err as any);
      res.status(500).send("Erreur serveur Garmin");
    }
  }
);

// ---------- Strava OAuth: token exchange (V2) ----------
const DEFAULT_REDIRECT_URI = "https://us-central1-nutriapp-4ea20.cloudfunctions.net/stravaTokenExchangeV2";
export const stravaTokenExchangeV2 = onRequest(
  { region: "us-central1", timeoutSeconds: 60, secrets: [STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET] },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    try {
      const code = (req.query.code as string) || (req.body?.code as string) || "";
      const redirectUri = (req.query.redirect_uri as string) || (req.body?.redirect_uri as string) || DEFAULT_REDIRECT_URI;

      if (!code) {
        res.status(400).json({ error: "Code manquant" });
        return;
      }
      if (!redirectUri) {
        res.status(400).json({ error: "redirect_uri manquant" });
        return;
      }

      const clientId = STRAVA_CLIENT_ID.value();
      const clientSecret = STRAVA_CLIENT_SECRET.value();
      if (!clientId || !clientSecret) {
        res.status(500).json({ error: "Secrets Strava manquants" });
        return;
      }

      // ⚠️ Strava attend du x-www-form-urlencoded
      const form = new URLSearchParams({
        client_id: String(clientId),
        client_secret: String(clientSecret),
        code,
        grant_type: "authorization_code",
        redirect_uri: redirectUri,
      });

      const response = await axios.post("https://www.strava.com/oauth/token", form.toString(), {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        timeout: 30000,
      });

      res.status(200).send(response.data);
    } catch (err: any) {
      // On renvoie le détail Strava pour comprendre
      const status = err?.response?.status ?? 500;
      const data = err?.response?.data ?? { message: String(err) };
      logger.error("stravaTokenExchangeV2 error", { status, data });
      res.status(status).send({ error: "strava_token_exchange_failed", detail: data });
    }
  }
);

// ---------- Strava OAuth: refresh token (V2) ----------
export const stravaRefreshTokenV2 = onRequest(
  { region: "us-central1", timeoutSeconds: 60, secrets: [STRAVA_CLIENT_ID, STRAVA_CLIENT_SECRET] },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    // ✅ En prod, préfère POST. GET toléré pour debug.
    if (!["POST", "GET"].includes(req.method)) {
      res.status(405).json({ error: "Method Not Allowed. Use POST." });
      return;
    }

    try {
      // 🔎 Récupération multi‑source
      const refreshToken =
        (req.query.refresh_token as string) ||
        (req.body?.refresh_token as string) ||
        "";

      const uid =
        (req.query.uid as string) ||
        (req.body?.uid as string) ||
        "";

      if (!refreshToken || !uid) {
        logger.warn("Missing fields on refresh", {
          uid_present: Boolean(uid),
          rt_present: Boolean(refreshToken),
          method: req.method,
          ct: req.get("content-type") || "",
          hasBody: !!req.body,
          hasQuery: Object.keys(req.query || {}).length > 0,
        });
        res.status(400).json({ error: "refresh_token manquant ou uid manquant" });
        return;
      }

      const clientId = STRAVA_CLIENT_ID.value();
      const clientSecret = STRAVA_CLIENT_SECRET.value();
      if (!clientId || !clientSecret) {
        res.status(500).json({ error: "Secrets Strava manquants" });
        return;
      }

      const form = new URLSearchParams({
        client_id: String(clientId),
        client_secret: String(clientSecret),
        refresh_token: refreshToken,
        grant_type: "refresh_token",
      });

      const response = await axios.post(
        "https://www.strava.com/oauth/token",
        form.toString(),
        {
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          timeout: 30000,
        }
      );

      const payload = response.data;

      // ⚠️ Strava renvoie un NOUVEAU refresh_token : renvoie-le au client
      res.status(200).json({
        access_token: payload?.access_token,
        refresh_token: payload?.refresh_token,
        expires_at: payload?.expires_at,
        token_type: payload?.token_type,
        scope: payload?.scope,
      });

    } catch (err: any) {
      const status = err?.response?.status ?? 500;
      const data = err?.response?.data ?? { message: String(err) };
      const outStatus = [400, 401, 403].includes(status) ? status : 500;

      logger.error("stravaRefreshTokenV2 error", {
        status,
        outStatus,
        providerData: data,
      });

      res.status(outStatus).json({
        error: "strava_refresh_failed",
        detail: data,
      });
    }
  }
);
// ---------- Analyse IA Mistral (V2) ----------
export const analyzeMealsV2 = onRequest(
  { region: "us-central1", timeoutSeconds: 60, memory: "512MiB", secrets: [MISTRAL_API_KEY] },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    if (req.method !== "POST") { res.status(405).send("Method Not Allowed"); return; }

    const KEY = MISTRAL_API_KEY.value();
    if (!KEY) { res.status(500).json({ error: "Clé API Mistral manquante (MISTRAL_API_KEY)" }); return; }

    try {
      const { data } = req.body || {};
      if (!data) { res.status(400).json({ error: "Données 'data' manquantes" }); return; }

      const payload = {
        model: "mistral-small-latest",
        temperature: 0.6,
        max_tokens: 700,
        messages: [
          { role: "system",
            content:
              "Tu es un coach nutrition rigoureux. Tu DOIS analyser l’ENSEMBLE des repas fournis. " +
              "Commence toujours par 'Couverture' (total + par type). Réponds en 10–12 lignes, ton clair." },
          { role: "user",
            content: JSON.stringify(data) +
              "\n\nFormat:\n1) Couverture\n2) Résumé (3 phrases)\n3) Conseils (3 puces)\n4) Déséquilibres" },
        ],
      };

      const response = await axios.post(
        "https://api.mistral.ai/v1/chat/completions",
        payload,
        { headers: { Authorization: `Bearer ${KEY}` }, timeout: 45000 }
      );

      const analysisText = response.data?.choices?.[0]?.message?.content?.trim() || "";
      if (!analysisText) { res.status(502).json({ error: "Analyse vide du fournisseur IA" }); return; }
      res.json({ analysis: analysisText });
    } catch (err) {
      logger.error("analyzeMealsV2 error", err as any);
      res.status(500).json({ error: "Erreur du fournisseur IA" });
    }
  }
);

// ---------- Décomposition (déjà en Gen2 dans son fichier) ----------
export { decomposeMeal } from "./decomposeMeal";

// ---------- FatSecret: token (debug) ----------
export const fsTokenV2 = onRequest(
  { region: "us-central1",
    timeoutSeconds: 60,
    secrets: [FS_CLIENT_ID, FS_CLIENT_SECRET],
  vpcConnector: "serverless-conn",
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }
    try {
      const id = FS_CLIENT_ID.value();
      const secret = FS_CLIENT_SECRET.value();
      if (!id || !secret) { res.status(500).json({ error: "Secrets FatSecret manquants" }); return; }

      const token = await getFsToken(String(id), String(secret));
      res.status(200).json({ access_token: token, token_type: "Bearer" });
    } catch (err: any) {
      logger.error("fsTokenV2 error", err);
      res.status(500).json({ error: "fatsecret_token_failed", detail: String(err?.message || err) });
    }
  }
);

// ---------- FatSecret: foods.search ----------
export const fsSearchV2 = onRequest(
  { region: "us-central1", 
    timeoutSeconds: 60, 
    secrets: [FS_CLIENT_ID, FS_CLIENT_SECRET],
    vpcConnector: "serverless-conn",           
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    try {
      const q = (req.query.q as string) || (req.body?.q as string) || "";
      if (!q) { res.status(400).json({ error: "Missing param 'q'" }); return; }

      const id = FS_CLIENT_ID.value();
      const secret = FS_CLIENT_SECRET.value();
      if (!id || !secret) { res.status(500).json({ error: "Secrets FatSecret manquants" }); return; }

      const token = await getFsToken(String(id), String(secret));

      const url = "https://platform.fatsecret.com/rest/server.api";
      const params = new URLSearchParams({
        method: "foods.search",
        search_expression: q,
        format: "json",
      });

      const api = await axios.get(`${url}?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
        timeout: 30000,
        validateStatus: () => true, // on relaie même 4xx
      });

      res.set("Content-Type", "application/json; charset=utf-8");
      res.status(api.status).send(api.data);
    } catch (err: any) {
      const status = err?.response?.status ?? 500;
      const data = err?.response?.data ?? { message: String(err) };
      logger.error("fsSearchV2 error", { status, data });
      res.status(status).json({ error: "fatsecret_search_failed", detail: data });
    }
  }
);

// ---------- Helpers locaux nécessaires ----------
const toNum = (v: any): number => {
  if (v === null || v === undefined) return 0;
  const n = Number(String(v).replace(",", "."));
  return Number.isFinite(n) ? n : 0;
};

function toPer100(serving: any) {
  const isMetricG = (serving?.metric_serving_unit || "").toLowerCase().includes("g");
  const grams = isMetricG ? toNum(serving?.metric_serving_amount) : toNum(serving?.serving_weight_grams);
  const g = grams > 0 ? grams : 100;
  const f = 100 / g;
  return {
    kcal: toNum(serving?.calories) * f,
    protein: toNum(serving?.protein) * f,
    carbs: toNum(serving?.carbohydrate) * f,
    sugars: toNum(serving?.sugar) * f,
    fat: toNum(serving?.fat) * f,
    fibers: toNum(serving?.fiber) * f,
    saturatedFat: toNum(serving?.saturated_fat) * f,
    polyunsaturatedFat: toNum(serving?.polyunsaturated_fat) * f,
    monounsaturatedFat: toNum(serving?.monounsaturated_fat) * f,
  };
}

function pickBestServing(servings: any) {
  const list = Array.isArray(servings) ? servings : (servings ? [servings] : []);
  if (list.length === 0) return null;
  let best = list[0];
  let bestScore = Number.POSITIVE_INFINITY;
  for (const s of list) {
    const isMetricG = (s?.metric_serving_unit || "").toLowerCase().includes("g");
    const grams = isMetricG ? toNum(s?.metric_serving_amount) : toNum(s?.serving_weight_grams);
    const score = Math.abs((grams || 100) - 100);
    if (score < bestScore) { best = s; bestScore = score; }
  }
  return best;
}

function normalizeFoodDetail(food: any) {
  const brand = food?.brand_name ?? null;
  const name = food?.food_name || food?.food_name_fr || food?.food_name_en || "";
  const servingsNode = food?.servings?.serving ?? null;

  const ref = pickBestServing(servingsNode) || {};
  const per100 = toPer100(ref);

  const servingsArr = Array.isArray(servingsNode) ? servingsNode : (servingsNode ? [servingsNode] : []);
  const servingsOut = servingsArr.map((s: any) => {
    const isMetricG = (s?.metric_serving_unit || "").toLowerCase().includes("g");
    const grams = isMetricG ? toNum(s?.metric_serving_amount) : toNum(s?.serving_weight_grams);
    return {
      label: s?.serving_description || s?.measurement_description || `${grams || 100} g`,
      grams: grams || 0,
      kcal: toNum(s?.calories),
      protein: toNum(s?.protein),
      carbs: toNum(s?.carbohydrate),
      sugars: toNum(s?.sugar),
      fat: toNum(s?.fat),
      fibers: toNum(s?.fiber),
    };
  });

  // Arrondis doux: kcal 1 décimale, le reste 2
  (Object.keys(per100) as (keyof typeof per100)[]).forEach(k => {
    // @ts-ignore
    per100[k] = Number((per100[k] || 0).toFixed(k === "kcal" ? 1 : 2));
  });

  return {
    id: String(food?.food_id),
    name,
    brand,
    per100,
    servings: servingsOut,
  };
}

// ---------- FatSecret: foods.search -> items normalisés (per100) ----------
export const fsSearchClean = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    secrets: [FS_CLIENT_ID, FS_CLIENT_SECRET],
    vpcConnector: "serverless-conn",
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    try {
      const q = (req.query.q as string) || (req.body?.q as string) || "";
      const page = Math.max(1, Number(req.query.page || 1));
      const max = Math.max(1, Math.min(15, Number(req.query.max || 10)));

      if (!q) { res.status(400).json({ error: "Missing param 'q'" }); return; }

      const id = FS_CLIENT_ID.value(); const secret = FS_CLIENT_SECRET.value();
      if (!id || !secret) { res.status(500).json({ error: "Secrets FatSecret manquants" }); return; }
      const token = await getFsToken(String(id), String(secret));

      const baseUrl = "https://platform.fatsecret.com/rest/server.api";

      // 1) foods.search (page_number est 0-based)
      const params = new URLSearchParams({
        method: "foods.search",
        search_expression: q,
        format: "json",
        max_results: String(max),
        page_number: String(page - 1),
      });

      const searchResp = await axios.get(`${baseUrl}?${params.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
        timeout: 30000,
        validateStatus: () => true,
      });

      if (searchResp.status !== 200) {
        res.status(searchResp.status).json(searchResp.data);
        return;
      }

      const foods = searchResp.data?.foods?.food ?? [];
      const arr: any[] = Array.isArray(foods) ? foods : (foods ? [foods] : []);

      // 2) pour chaque aliment, récupère le détail et normalise
      const promises = arr.map(async (f) => {
        try {
          // d'abord en v3…
          let p = new URLSearchParams({ method: "food.get.v3", food_id: String(f.food_id), format: "json" });
          let d = await axios.get(`${baseUrl}?${p.toString()}`, {
            headers: { Authorization: `Bearer ${token}` },
            timeout: 20000,
            validateStatus: () => true,
          });

          // …fallback en v2 si besoin
          if (d.status !== 200) {
            p = new URLSearchParams({ method: "food.get", food_id: String(f.food_id), format: "json" });
            d = await axios.get(`${baseUrl}?${p.toString()}`, {
              headers: { Authorization: `Bearer ${token}` },
              timeout: 20000,
              validateStatus: () => true,
            });
            if (d.status !== 200) return null;
          }

          const food = d.data?.food ?? d.data?.foods?.food;
          if (!food) return null;

          const n = normalizeFoodDetail(food);
          if (n.per100.kcal <= 0) return null;

          return {
            id: n.id,
            name: n.name,
            brand: n.brand,
            per100: {
              kcal: n.per100.kcal,
              protein: n.per100.protein,
              carbs: n.per100.carbs,
              sugars: n.per100.sugars,
              fat: n.per100.fat,
              fibers: n.per100.fibers,
            },
          };
        } catch {
          return null;
        }
      });

      const settled = await Promise.all(promises);
      const items = settled.filter(Boolean);

      res.set("Content-Type", "application/json; charset=utf-8");
      res.status(200).json({ items });
    } catch (err: any) {
      const status = err?.response?.status ?? 500;
      const data = err?.response?.data ?? { message: String(err) };
      logger.error("fsSearchClean error", { status, data });
      res.status(status).json({ error: "fatsecret_search_clean_failed", detail: data });
    }
  }
);

// ---------- FatSecret: food.get(.v3) -> détail normalisé ----------
export const fsFoodV2 = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 60,
    secrets: [FS_CLIENT_ID, FS_CLIENT_SECRET],
    vpcConnector: "serverless-conn",
    vpcConnectorEgressSettings: "ALL_TRAFFIC",
  },
  async (req, res) => {
    setCors(res);
    if (req.method === "OPTIONS") { res.status(204).send(""); return; }

    try {
      const idParam = (req.query.id as string) || (req.body?.id as string);
      if (!idParam) { res.status(400).json({ error: "Missing param 'id'" }); return; }

      const id = FS_CLIENT_ID.value(); const secret = FS_CLIENT_SECRET.value();
      if (!id || !secret) { res.status(500).json({ error: "Secrets FatSecret manquants" }); return; }
      const token = await getFsToken(String(id), String(secret));

      const baseUrl = "https://platform.fatsecret.com/rest/server.api";

      // essai v3, fallback v2
      let p = new URLSearchParams({ method: "food.get.v3", food_id: String(idParam), format: "json" });
      let api = await axios.get(`${baseUrl}?${p.toString()}`, {
        headers: { Authorization: `Bearer ${token}` },
        timeout: 20000,
        validateStatus: () => true,
      });
      if (api.status !== 200) {
        p = new URLSearchParams({ method: "food.get", food_id: String(idParam), format: "json" });
        api = await axios.get(`${baseUrl}?${p.toString()}`, {
          headers: { Authorization: `Bearer ${token}` },
          timeout: 20000,
          validateStatus: () => true,
        });
        if (api.status !== 200) { res.status(api.status).json(api.data); return; }
      }

      const food = api.data?.food ?? api.data?.foods?.food;
      if (!food) { res.status(404).json({ error: "Not found" }); return; }

      const n = normalizeFoodDetail(food);

      res.set("Content-Type", "application/json; charset=utf-8");
      res.status(200).json(n);
    } catch (err: any) {
      const status = err?.response?.status ?? 500;
      const data = err?.response?.data ?? { message: String(err) };
      logger.error("fsFoodV2 error", { status, data });
      res.status(status).json({ error: "fatsecret_food_failed", detail: data });
    }
  }
);

