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
