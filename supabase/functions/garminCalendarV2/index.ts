import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  // Gestion du CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Si vous voulez pouvoir tester facilement, autorisez aussi le GET
  if (req.method !== "POST" && req.method !== "GET") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

const GARMIN_URL =
"https://connect.garmin.com/modern/calendar/export/c99d3fa28b14447d9ad44c23877fad60";

  try {
    const response = await fetch(GARMIN_URL, {
      method: "GET",
      headers: {
        // TRÈS IMPORTANT : Simuler un vrai navigateur
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/calendar,text/plain,*/*",
        "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
        "Referer": "https://connect.garmin.com/modern/calendar",
        "Cache-Control": "no-cache",
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("Garmin error body:", errorText);
      return new Response(`Garmin error: ${response.status}`, {
        status: response.status,
        headers: corsHeaders,
      });
    }

    const calendarText = await response.text();

    // Vérification de sécurité pour éviter de renvoyer du HTML
    if (calendarText.includes("<!DOCTYPE html>") || calendarText.includes("login")) {
      console.error("DEBUG: Garmin a détecté le bot et demande une connexion.");
      return new Response(
        JSON.stringify({ error: "Garmin blocked the request. Try regenerating the link." }), 
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(calendarText, {
      status: 200,
      headers: {
        ...corsHeaders,
        "Content-Type": "text/calendar; charset=utf-8",
      },
    });
  } catch (error) {
    console.error("Fetch error:", error);
    return new Response("Internal Server Error", { status: 500, headers: corsHeaders });
  }
});