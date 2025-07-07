import * as functions from "firebase-functions";
const fetch = require("node-fetch");

export const proxy = functions.https.onRequest(async (req, res) => {
  const query = req.query;
  const upstreamUrl = new URL("http://world.openfoodfacts.org/cgi/search.pl");
  Object.entries(query).forEach(([key, value]) =>
    upstreamUrl.searchParams.append(key, String(value))
  );

  try {
    const response = await fetch(upstreamUrl.toString());
    const data = await response.json();
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Content-Type", "application/json");
    res.send(data);
  } catch (e) {
    res.status(500).send({ error: "Proxy failed", details: String(e) });
  }
});
