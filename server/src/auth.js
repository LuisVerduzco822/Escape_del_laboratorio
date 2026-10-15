const crypto = require('crypto');
const { promisify } = require('util');
const { pool } = require('./db');

const scrypt = promisify(crypto.scrypt);
const TOKEN_DAYS = 30;

const newSalt = () => crypto.randomBytes(16).toString('hex');
const newToken = () => crypto.randomBytes(32).toString('hex');
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

async function hashPassword(password, salt) {
  return (await scrypt(password, salt, 64)).toString('hex');
}

function safeEqual(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

function validateCredentials(username, password) {
  if (typeof username !== 'string' || !/^[A-Za-z0-9_]{3,16}$/.test(username)) {
    return 'Usuario: 3 a 16 letras, números o _';
  }
  if (typeof password !== 'string' || password.length < 6 || password.length > 32) {
    return 'Contraseña: 6 a 32 caracteres';
  }
  return null;
}

async function issueToken(userId) {
  const token = newToken();
  await pool.query(
    `INSERT INTO auth_tokens (token_hash, user_id, expires_at)
     VALUES ($1, $2, now() + ($3 || ' days')::interval)`,
    [sha256(token), userId, String(TOKEN_DAYS)]
  );
  return token;
}

async function requireUser(req, res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) return res.status(401).json({ error: 'Sesión no válida' });
    const { rows } = await pool.query(
      `SELECT u.id, u.username
         FROM auth_tokens t JOIN users u ON u.id = t.user_id
        WHERE t.token_hash = $1 AND t.expires_at > now()`,
      [sha256(token)]
    );
    if (rows.length === 0) return res.status(401).json({ error: 'Sesión caducada' });
    req.user = rows[0];
    req.tokenHash = sha256(token);
    next();
  } catch (err) {
    next(err);
  }
}

function requireAdmin(req, res, next) {
  const expected = process.env.ADMIN_PASSWORD || 'cambia_esta_clave';
  const given = req.headers['x-admin-key'] || '';
  if (!safeEqual(given, expected)) {
    return res.status(401).json({ error: 'Clave de administrador incorrecta' });
  }
  next();
}

const attempts = new Map();
function tooManyAttempts(key) {
  const now = Date.now();
  const list = (attempts.get(key) || []).filter((t) => now - t < 5 * 60 * 1000);
  attempts.set(key, list);
  return list.length >= 8;
}
function registerFailure(key) {
  const list = attempts.get(key) || [];
  list.push(Date.now());
  attempts.set(key, list);
}
function clearFailures(key) {
  attempts.delete(key);
}

module.exports = {
  newSalt,
  hashPassword,
  safeEqual,
  validateCredentials,
  issueToken,
  requireUser,
  requireAdmin,
  tooManyAttempts,
  registerFailure,
  clearFailures,
};
