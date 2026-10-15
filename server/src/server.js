require('dotenv').config();
const path = require('path');
const express = require('express');
const { init } = require('./db');
const game = require('./game');
const admin = require('./admin');

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '256kb' }));
app.use('/api/admin', admin);
app.use('/api', game);
app.use(express.static(path.join(__dirname, '..', 'public')));

app.use((req, res) => res.status(404).json({ error: 'No encontrado' }));
app.use((err, req, res, next) => {
  if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'JSON inválido' });
  console.error(err);
  res.status(500).json({ error: 'Error interno del servidor' });
});

const port = Number(process.env.PORT) || 3000;

if (require.main === module) {
  init()
    .then(() => {
      app.listen(port, () => {
        console.log(`Servidor listo en http://localhost:${port}`);
        if (!process.env.ADMIN_PASSWORD) {
          console.warn('Aviso: define ADMIN_PASSWORD en .env (se usa un valor por defecto).');
        }
      });
    })
    .catch((err) => {
      console.error('No se pudo conectar con PostgreSQL:', err.message);
      process.exit(1);
    });
}

module.exports = app;
