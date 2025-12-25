// this is for favorite functionality

// backend/firebaseAdmin.js
import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import path from 'path';

// Load the service account key file
const serviceAccountPath = path.resolve('./serviceAccountKey.json');
const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

export { admin };
