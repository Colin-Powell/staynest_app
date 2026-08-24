import { initializeApp, getApps, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { env } from '../config.js';
import { query } from '../db.js';
import fs from 'fs';
function initFirebase() {
    if (getApps().length > 0)
        return;
    if (env.firebaseServiceAccount) {
        try {
            let serviceAccount;
            if (env.firebaseServiceAccount.startsWith('{')) {
                serviceAccount = JSON.parse(env.firebaseServiceAccount);
            }
            else if (env.firebaseServiceAccount.endsWith('.json')) {
                serviceAccount = JSON.parse(fs.readFileSync(env.firebaseServiceAccount, 'utf8'));
            }
            else {
                serviceAccount = JSON.parse(Buffer.from(env.firebaseServiceAccount, 'base64').toString('utf8'));
            }
            initializeApp({
                credential: cert(serviceAccount),
            });
            console.log('Firebase Admin initialized successfully.');
        }
        catch (e) {
            console.error('Failed to initialize Firebase Admin SDK:', e);
        }
    }
    else {
        console.warn('FIREBASE_SERVICE_ACCOUNT is not set. Push notifications will be disabled.');
    }
}
initFirebase();
export async function sendPushToUser(userId, title, body, data) {
    if (getApps().length === 0)
        return false;
    try {
        const userRes = await query('SELECT fcm_token, settings FROM users WHERE id = $1', [userId]);
        const user = userRes.rows[0];
        if (!user || !user.fcm_token)
            return false;
        // Check if the user has opted out of push notifications
        if (user.settings && typeof user.settings === 'object') {
            const settings = user.settings;
            if (settings.push === false)
                return false;
        }
        await getMessaging().send({
            token: user.fcm_token,
            notification: { title, body },
            data,
        });
        return true;
    }
    catch (error) {
        console.error(`Failed to send push to user ${userId}:`, error);
        return false;
    }
}
export async function sendPushToTopic(topic, title, body, data) {
    if (getApps().length === 0)
        return false;
    try {
        await getMessaging().send({
            topic,
            notification: { title, body },
            data,
        });
        return true;
    }
    catch (error) {
        console.error(`Failed to send push to topic ${topic}:`, error);
        return false;
    }
}
//# sourceMappingURL=firebase.js.map