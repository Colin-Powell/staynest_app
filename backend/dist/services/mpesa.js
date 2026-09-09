import axios from 'axios';
import { env } from '../config.js';
/**
 * M-Pesa Daraja API Integration Service
 * Handles STKPush, payment verification, and transaction callbacks
 */
const DARAJA_BASE = 'https://sandbox.safaricom.co.ke'; // Production: https://api.safaricom.co.ke
const CONSUMER_KEY = env.mpesaConsumerKey || '';
const CONSUMER_SECRET = env.mpesaConsumerSecret || '';
const BUSINESS_SHORT_CODE = env.mpesaBusinessShortCode || '174379'; // Test credentials
const PASS_KEY = env.mpesaPassKey || 'bfb279f9aa9bdbcf158e97dd71a467cd'; // Test passkey
const CALLBACK_URL = `${env.apiBaseUrl || 'http://localhost:3000'}/api/payments/mpesa-callback`;
let cachedAccessToken = null;
/**
 * Get OAuth access token from Daraja API
 */
async function getAccessToken() {
    const now = Date.now();
    if (cachedAccessToken && cachedAccessToken.expiry > now) {
        return cachedAccessToken.token;
    }
    try {
        const auth = Buffer.from(`${CONSUMER_KEY}:${CONSUMER_SECRET}`).toString('base64');
        const response = await axios.get(`${DARAJA_BASE}/oauth/v1/generate?grant_type=client_credentials`, {
            headers: {
                Authorization: `Basic ${auth}`,
            },
        });
        const token = response.data.access_token;
        const expiresIn = response.data.expires_in * 1000; // Convert to milliseconds
        cachedAccessToken = {
            token,
            expiry: now + expiresIn - 30000, // Refresh 30 seconds before expiry
        };
        return token;
    }
    catch (error) {
        console.error('[M-Pesa] Failed to get access token:', error);
        throw new Error('Failed to authenticate with M-Pesa');
    }
}
/**
 * Format phone number to 254XXXXXXXXX format
 */
function formatPhoneNumber(phone) {
    let cleaned = phone.replace(/\D/g, '');
    if (cleaned.startsWith('0')) {
        cleaned = '254' + cleaned.substring(1);
    }
    else if (!cleaned.startsWith('254')) {
        cleaned = '254' + cleaned;
    }
    return cleaned;
}
/**
 * Generate timestamp in the format YYYYMMDDHHMMSS
 */
function getTimestamp() {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    return `${year}${month}${day}${hours}${minutes}${seconds}`;
}
/**
 * Generate M-Pesa password (Base64 encoded BusinessShortCode+PassKey+Timestamp)
 */
function generatePassword(timestamp) {
    const password = `${BUSINESS_SHORT_CODE}${PASS_KEY}${timestamp}`;
    return Buffer.from(password).toString('base64');
}
/**
 * Initiate STKPush for M-Pesa payment
 * Returns CheckoutRequestID to track payment
 */
export async function initiateSTKPush(params) {
    if (!CONSUMER_KEY || !CONSUMER_SECRET) {
        throw new Error('M-Pesa credentials not configured');
    }
    try {
        const formattedPhone = formatPhoneNumber(params.phone);
        const timestamp = getTimestamp();
        const password = generatePassword(timestamp);
        const accessToken = await getAccessToken();
        const payload = {
            BusinessShortCode: BUSINESS_SHORT_CODE,
            Password: password,
            Timestamp: timestamp,
            TransactionType: 'CustomerPayBillOnline',
            Amount: Math.round(params.amount), // Must be integer
            PartyA: formattedPhone,
            PartyB: BUSINESS_SHORT_CODE,
            PhoneNumber: formattedPhone,
            CallBackURL: CALLBACK_URL,
            AccountReference: params.reference.substring(0, 12), // Max 12 chars
            TransactionDesc: params.description.substring(0, 13), // Max 13 chars
            Remark: 'StayNest Payment',
        };
        const response = await axios.post(`${DARAJA_BASE}/mpesa/stkpush/v1/processrequest`, payload, {
            headers: {
                Authorization: `Bearer ${accessToken}`,
            },
        });
        if (response.data.ResponseCode !== '0') {
            throw new Error(response.data.ResponseDescription || 'STKPush failed');
        }
        return response.data;
    }
    catch (error) {
        console.error('[M-Pesa] STKPush error:', error.response?.data || error.message);
        throw error;
    }
}
/**
 * Query STK Push transaction status
 */
export async function querySTKStatus(checkoutRequestId) {
    try {
        const timestamp = getTimestamp();
        const password = generatePassword(timestamp);
        const accessToken = await getAccessToken();
        const payload = {
            BusinessShortCode: BUSINESS_SHORT_CODE,
            Password: password,
            Timestamp: timestamp,
            CheckoutRequestID: checkoutRequestId,
        };
        const response = await axios.post(`${DARAJA_BASE}/mpesa/stkpushquery/v1/query`, payload, {
            headers: {
                Authorization: `Bearer ${accessToken}`,
            },
        });
        return response.data;
    }
    catch (error) {
        console.error('[M-Pesa] STK Query error:', error.response?.data || error.message);
        throw error;
    }
}
/**
 * Handle M-Pesa callback from Daraja
 * Verify and process payment result
 */
export function parseCallback(callbackData) {
    const callback = callbackData.Body.stkCallback;
    const items = callback.CallbackMetadata?.Item || [];
    const parseItem = (name) => {
        const item = items.find((i) => i.Name === name);
        return item?.Value;
    };
    const resultCode = callback.ResultCode;
    const success = resultCode === 0;
    const mpesaReceipt = parseItem('MpesaReceiptNumber');
    const amount = parseItem('Amount');
    const transactionDate = parseItem('TransactionDate');
    return {
        success,
        checkoutRequestId: callback.CheckoutRequestID,
        resultCode,
        resultDesc: callback.ResultDesc,
        ...(success && {
            amount: typeof amount === 'number' ? amount : Number(amount),
            mpesaReceiptNumber: String(mpesaReceipt),
            transactionDate: String(transactionDate),
        }),
    };
}
/**
 * Verify payment signature for security
 * Uses the expected format from M-Pesa callback
 */
export function verifyCallbackSignature(callbackData) {
    // M-Pesa doesn't require signature verification in sandbox
    // In production, implement proper signature validation if required by your provider
    const stkCallback = callbackData.Body.stkCallback;
    return !!(stkCallback &&
        stkCallback.CheckoutRequestID &&
        stkCallback.ResultCode !== undefined);
}
export default {
    initiateSTKPush,
    querySTKStatus,
    parseCallback,
    verifyCallbackSignature,
};
//# sourceMappingURL=mpesa.js.map