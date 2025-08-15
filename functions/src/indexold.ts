// functions/src/index.ts
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";
import type { Request, Response } from "express";

admin.initializeApp();

/* ------------------------------ Helpers/CORS ------------------------------ */
function setCors(res: Response): void {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  res.set("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
}

/** Récupère les creds Strava depuis la config (avec cast/trim). */
function getStravaCreds(): { client_id: number; client_secret: string } | null {
  const cfg = (functions.config().strava ?? {}) as { client_id?: unknown; client_secret?: unknown };
  const client_id = Number(String(cfg.client_id ?? ""));
  const client_secret = String(cfg.client_secret ?? "").trim();
  if (!client_id || !client_secret) return null;
  return { client_id, client_secret };
}

/* ------------------------------ OpenFoodFacts ----------------------------- */
export const proxy = functions
  .region("us-central1")
  .https.onRequest(async (req: Request, res: Response): Promise<void> => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    try {
      const upstreamUrl = new URL("https://world.openfoodfacts.org/cgi/search.pl");
      for (const [k, v] of Object.entries(req.query)) {
        upstreamUrl.searchParams.append(k, String(v));
      }
      const r = await axios.get(upstreamUrl.toString(), { validateStatus: () => true });
      res.set("Content-Type", "application/json");
      res.status(r.status).send(r.data);
      return;
    } catch (e: any) {
      console.error("Proxy OFF error:", e?.message || e);
      res.status(500).send({ error: "Proxy failed" });
      return;
    }
  });

/* --------------------------------- Garmin -------------------------------- */
export const garminCalendar = functions
  .region("us-central1")
  .https.onRequest(async (_req: Request, res: Response): Promise<void> => {
    setCors(res);
    if (_req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    try {
      const GARMIN_URL =
        "https://connect.garmin.com/modern/calendar/export/c99d3fa28b14447d9ad44c23877fad60";
      const r = await axios.get(GARMIN_URL, { validateStatus: () => true });
      res.set("Content-Type", "text/calendar");
      res.status(r.status).send(r.data);
      return;
    } catch (e: any) {
      console.error("Erreur Garmin:", e?.message || e);
      res.status(500).send("Erreur serveur Garmin");
      return;
    }
  });

/* ------------------------------ Strava OAuth ------------------------------ */
export const stravaTokenExchange = functions
  .region("us-central1")
  .https.onRequest(async (req: Request, res: Response): Promise<void> => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    try {
      // accepte body JSON ET query
      const code = (req.body?.code as string | undefined) ?? (req.query.code as string | undefined);
      if (!code) {
        res.status(400).json({ error: "Code manquant" });
        return;
      }

      const creds = getStravaCreds();
      if (!creds) {
        res.status(500).json({ error: "Identifiants Strava manquants" });
        return;
      }

      console.log("stravaTokenExchange using client_id:", creds.client_id);

      // Strava préfère form-encoded
      const body = new URLSearchParams({
        client_id: String(creds.client_id),
        client_secret: creds.client_secret,
        code,
        grant_type: "authorization_code",
      }).toString();

      const r = await axios.post("https://www.strava.com/oauth/token", body, {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        validateStatus: () => true,
      });

      res.status(r.status).json(r.data);
      return;
    } catch (e: any) {
      console.error("Erreur proxy Strava OAuth :", e?.message || e);
      res.status(500).json({ error: "Erreur interne serveur" });
      return;
    }
  });

export const stravaRefreshToken = functions
  .region("us-central1")
  .https.onRequest(async (req: Request, res: Response): Promise<void> => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    try {
      const refresh_token =
        (req.body?.refresh_token as string | undefined) ??
        (req.query.refresh_token as string | undefined);
      if (!refresh_token) {
        res.status(400).json({ error: "Missing refresh_token" });
        return;
      }

      const creds = getStravaCreds();
      if (!creds) {
        res.status(500).json({ error: "Identifiants Strava manquants" });
        return;
      }

      console.log("stravaRefreshToken using client_id:", creds.client_id);

      const body = new URLSearchParams({
        client_id: String(creds.client_id),
        client_secret: creds.client_secret,
        grant_type: "refresh_token",
        refresh_token,
      }).toString();

      const r = await axios.post("https://www.strava.com/oauth/token", body, {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        validateStatus: () => true,
      });

      res.status(r.status).json(r.data);
      return;
    } catch (e: any) {
      console.error("Erreur proxy Strava Refresh :", e?.message || e);
      res.status(500).json({ error: "Erreur interne serveur" });
      return;
    }
  });

/* ------------------------------ (ex) Mistral ------------------------------ */
// Si tu utilises encore analyzeMeals, garde ceci. Sinon, supprime.
const MISTRAL_KEY =
  (functions.config().mistral?.key as string | undefined) || process.env.MISTRAL_API_KEY || "";

export const analyzeMeals = functions
  .region("us-central1")
  .https.onRequest(async (req: Request, res: Response): Promise<void> => {
    setCors(res);
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }
    try {
      if (!MISTRAL_KEY) {
        res.status(500).json({ error: "MISTRAL_API_KEY manquant" });
        return;
      }
      const { messages } = req.body ?? {};
      const payload = {
        model: "mistral-large-latest",
        messages: messages ?? [{ role: "user", content: "Hello" }],
      };
      const r = await axios.post("https://api.mistral.ai/v1/chat/completions", payload, {
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${MISTRAL_KEY}`,
        },
        validateStatus: () => true,
      });
      res.status(r.status).json(r.data);
      return;
    } catch (e: any) {
      console.error("analyzeMeals error:", e?.message || e);
      res.status(500).json({ error: "Erreur interne serveur" });
      return;
    }
  });
