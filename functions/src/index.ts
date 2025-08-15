import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";

// Initialisation de Firebase Admin
admin.initializeApp();
// const db = admin.firestore();

// =======================================================================
// == Middlewares et Helpers
// =======================================================================

/**
 * Applique les en-têtes CORS nécessaires à une réponse.
 * @param {functions.Response} res L'objet réponse.
 */
function setCors(res: functions.Response) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");
}


// =======================================================================
// == Proxies Simples
// =======================================================================

// Proxy vers OpenFoodFacts
export const proxy = functions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  // L'URL est construite dynamiquement, donc pas besoin de fetch ici
  // C'est un simple proxy qui forwarde la requête.
  res.redirect(`http://world.openfoodfacts.org/cgi/search.pl?${new URLSearchParams(req.query as Record<string, string>).toString()}`);
});


// Proxy vers Garmin Calendar
export const garminCalendar = functions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  const GARMIN_URL = "https://connect.garmin.com/modern/calendar/export/c99d3fa28b14447d9ad44c23877fad60";
  try {
    const response = await axios.get(GARMIN_URL);
    res.set("Content-Type", "text/calendar");
    res.send(response.data);
  } catch (error) {
    console.error("Erreur Garmin:", error);
    res.status(500).send("Erreur serveur Garmin");
  }
});


// =======================================================================
// == Logique Strava
// =======================================================================

// Récupère les clés Strava depuis la configuration sécurisée
const stravaConfig = functions.config().strava || {};
const STRAVA_CLIENT_ID = stravaConfig.client_id || process.env.STRAVA_CLIENT_ID;
const STRAVA_CLIENT_SECRET = stravaConfig.client_secret || process.env.STRAVA_CLIENT_SECRET;

// Proxy pour l'échange de token OAuth
export const stravaTokenExchange = functions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  try {
    const code = req.query.code as string;
    if (!code) {
      res.status(400).send({error: "Code manquant"});
      return;
    }
    const response = await axios.post("https://www.strava.com/oauth/token", null, {
      params: {
        client_id: STRAVA_CLIENT_ID,
        client_secret: STRAVA_CLIENT_SECRET,
        code: code,
        grant_type: "authorization_code",
      },
    });
    res.status(response.status).send(response.data);
  } catch (err) {
    console.error("Erreur proxy Strava OAuth :", err);
    res.status(500).send({error: "Erreur interne serveur"});
  }
});

// Proxy pour le rafraîchissement de token
export const stravaRefreshToken = functions.https.onRequest(async (req, res) => {
  setCors(res);
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }
  try {
    const refreshToken = req.query.refresh_token as string;
    if (!refreshToken) {
      res.status(400).send({error: "refresh_token manquant"});
      return;
    }
    const response = await axios.post("https://www.strava.com/oauth/token", null, {
      params: {
        client_id: STRAVA_CLIENT_ID,
        client_secret: STRAVA_CLIENT_SECRET,
        refresh_token: refreshToken,
        grant_type: "refresh_token",
      },
    });
    res.status(response.status).send(response.data);
  } catch (err) {
    console.error("Erreur proxy Strava refresh :", err);
    res.status(500).send({error: "Erreur interne serveur"});
  }
});


// =======================================================================
// == Analyse IA
// =======================================================================

// Récupère les clés IA depuis la configuration sécurisée
const MISTRAL_KEY = functions.config().mistral?.key || process.env.MISTRAL_API_KEY;

export const analyzeMeals = functions
    .runWith({timeoutSeconds: 60, memory: "512MB"})
    .https.onRequest(async (req, res) => {
      setCors(res);
      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      if (!MISTRAL_KEY) {
        res.status(500).json({error: "Clé API Mistral manquante"});
        return;
      }

      try {
        const {data} = req.body;
        if (!data) {
          res.status(400).json({error: "Données 'data' manquantes dans le corps de la requête"});
          return;
        }

        const payload = {
          model: "mistral-small-latest",
          temperature: 0.6,
          max_tokens: 700,
          messages: [
            {
              role: "system",
              content: "Tu es un coach nutrition rigoureux. Tu DOIS analyser l’ENSEMBLE des repas fournis. Commence toujours par une section 'Couverture' listant le nombre de repas par type. Réponds en 10–12 lignes max, ton clair et opérationnel.",
            },
            {
              role: "user",
              content: JSON.stringify(data) + "\n\nRappels de format :\n1) Couverture : total repas + par type\n2) Résumé (3 phrases)\n3) Conseils (3 puces)\n4) Déséquilibres (protéines/glucides/lipides)",
            },
          ],
        };

        const response = await axios.post("https://api.mistral.ai/v1/chat/completions", payload, {
          headers: {"Authorization": `Bearer ${MISTRAL_KEY}`},
          timeout: 45000,
        });

        const analysisText = response.data?.choices?.[0]?.message?.content?.trim() || "";
        if (!analysisText) {
          res.status(502).json({error: "Analyse vide reçue du fournisseur IA"});
          return;
        }
        res.json({analysis: analysisText});
      } catch (err) {
        console.error("Erreur analyzeMeals :", err);
        res.status(500).json({error: "Erreur du fournisseur IA"});
      }
    });