const https = require('node:https');

module.exports = {
  '/api': {
    target: process.env.API_UPSTREAM || 'https://localhost:8090',
    secure: true,
    changeOrigin: false,
    // The local backend presents the renewed production-domain certificate.
    agent: new https.Agent({
      servername: process.env.TLS_SERVER_NAME || 'tertiaryverify.dedicated.co.za',
    }),
  },
};
