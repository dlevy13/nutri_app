const express = require('express');
const axios = require('axios');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();

// Proxy Garmin avec axios
app.get('/garmin-calendar', async (req, res) => {
  try {
    const response = await axios.get('https://connect.garmin.com/modern/calendar/export/c99d3fa28b14447d9ad44c23877fad60');
    res.set('Content-Type', 'text/calendar');
    res.set('Access-Control-Allow-Origin', '*');
    res.send(response.data);
  } catch (err) {
    console.error('Erreur Garmin:', err.message);
    res.status(500).send('Erreur serveur Garmin');
  }
});

// Proxy OpenFoodFacts (déjà présent)
app.use('/off', createProxyMiddleware({
  target: 'https://world.openfoodfacts.org',
  changeOrigin: true,
  pathRewrite: { '^/off': '' },
  onProxyRes: proxyRes => {
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
    proxyRes.headers['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,OPTIONS';
    proxyRes.headers['Access-Control-Allow-Headers'] = '*';
  }
}));



// Page racine
app.get('/', (_, res) => res.send('✅ Proxy Nutri + Garmin actif'));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Proxy actif sur http://localhost:${port}`));
