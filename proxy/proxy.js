const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const app = express();

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

app.get('/', (_, res) => res.send('✅ Proxy Nutri actif'));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Proxy actif sur http://localhost:${port}`));