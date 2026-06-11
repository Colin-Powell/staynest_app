const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
// Ensure you have your serviceAccountKey.json in the config folder
const serviceAccount = require("../config/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

/**
 * Sends a push notification to a specific user via their FCM token
 * @param {string} fcmToken - The target device's FCM token
 * @param {string} title - Title of the notification
 * @param {string} body - Body text of the notification
 * @param {Object} data - Metadata to send with the notification (e.g., chatId, senderId)
 */
const sendPushNotification = async (fcmToken, title, body, data = {}) => {
  if (!fcmToken) return;

  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      ...data,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'high_importance_channel',
      },
    },
    apns: {
      payload: {
        aps: {
          contentAvailable: true,
        },
      },
    },
    token: fcmToken,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    return response;
  } catch (error) {
    if (error.code === 'messaging/registration-token-not-registered') {
      console.error('FCM Token is no longer valid. Update user record in database.');
      // Example: await User.updateOne({ fcmToken }, { $set: { fcmToken: null } });
    } else {
      console.error('Error sending message:', error);
    }
    throw error;
  }
};

/**
 * Updates the FCM token for a user in the database
 * @param {string} userId 
 * @param {string} token 
 */
const updateUserFCMToken = async (userId, token) => {
  // Logic to save the token for the user record
  // Example: await User.findByIdAndUpdate(userId, { fcmToken: token });
  console.log(`Updated FCM token for user ${userId}`);
};

module.exports = { sendPushNotification, updateUserFCMToken };