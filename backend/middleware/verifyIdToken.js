// backend/middlewares/verifyIdToken.js
import { admin } from '../connection/firebaseAdmin.js';

export async function verifyIdToken(req, res, next) {
  try {
    const hdr = req.get('Authorization') || '';
    const token = hdr.startsWith('Bearer ') ? hdr.slice(7) : null;
    if (!token) return res.status(401).json({ error: 'Missing ID token' });

    const decoded = await admin.auth().verifyIdToken(token);
    req.user = decoded; // { uid, email, ... }
    next();
  } catch (e) {
    res.status(401).json({ error: 'Invalid ID token' });
  }
}
