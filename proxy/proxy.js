const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const app = express();

app.use('/off', createProxyMiddleware({
  target: 'https://world.openfoodfacts.org',
  changeOrigin: true,
  pathRewrite: { '^/off': '' },
  onProxyRes: proxyRes => {
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
  }
}));

app.listen(3000, () => console.log('Proxy démarré sur http://localhost:3000/off'));  