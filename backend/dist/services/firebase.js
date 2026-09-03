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
    try {
        console.log(`[Push] requested userId=${userId} title=${JSON.stringify(title)}`);
        // Always save to database for the in-app notifications tab, EVEN IF Firebase is disabled
        try {
            await query(`INSERT INTO notifications (user_id, title, body, data) VALUES ($1, $2, $3, $4)`, [userId, title, body, data ? JSON.stringify(data) : null]);
            console.log(`[Push] in-app notification saved userId=${userId}`);
        }
        catch (dbErr) {
            console.error(`Failed to save notification to DB for user ${userId}:`, dbErr);
        }
        // If Firebase isn't initialized, we gracefully stop here but return true because in-app alerts worked
        if (getApps().length === 0) {
            console.warn(`[Push] Firebase unavailable; in-app notification only userId=${userId}`);
            return true;
        }
        const userRes = await query('SELECT fcm_token, settings FROM users WHERE id = $1', [userId]);
        const user = userRes.rows[0];
        if (!user) {
            console.warn(`[Push] user not found userId=${userId}`);
            return false;
        }
        // Skip actual push if no token
        if (!user.fcm_token) {
            console.warn(`[Push] no FCM token; in-app notification only userId=${userId}`);
            return true;
        }
        // Check if the user has opted out of push notifications
        if (user.settings && typeof user.settings === 'object') {
            const settings = user.settings;
            if (settings.push === false || settings.notifications?.push_messages === false) {
                console.log(`[Push] disabled by user settings userId=${userId}`);
                return true;
            }
        }
        const messageId = await getMessaging().send({
            token: user.fcm_token,
            notification: { title, body },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'high_importance_channel',
                    sound: 'default',
                },
            },
            data,
        });
        console.log(`[Push] FCM sent userId=${userId} messageId=${messageId}`);
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