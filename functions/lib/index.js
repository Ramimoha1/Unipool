"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.copyPayeeBankDetails = exports.sendFCMNotification = exports.onRideCompleted = exports.onApplicantAccepted = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();
async function sendPushToUser(userId, title, body) {
    const userDoc = await db.collection('users').doc(userId).get();
    const token = userDoc.get('fcm_token');
    if (!token) {
        return;
    }
    await messaging.send({
        token,
        notification: { title, body },
        data: { userId, title, body },
    });
}
exports.onApplicantAccepted = (0, firestore_1.onDocumentUpdated)('carpool_applicants/{applicantId}', async (event) => {
    const beforeStatus = event.data?.before.data()?.status;
    const afterData = event.data?.after.data();
    if (beforeStatus === afterData?.status || afterData?.status !== 'accepted') {
        return;
    }
    const acceptedUserId = afterData?.user_id;
    if (!acceptedUserId) {
        return;
    }
    await sendPushToUser(acceptedUserId, 'Application accepted', 'Your carpool application has been accepted.');
});
exports.onRideCompleted = (0, firestore_1.onDocumentUpdated)('carpool_requests/{requestId}', async (event) => {
    const beforeStatus = event.data?.before.data()?.status;
    const afterData = event.data?.after.data();
    if (beforeStatus === afterData?.status || afterData?.status !== 'completed') {
        return;
    }
    const requestId = event.params.requestId;
    const groupDoc = await db.collection('carpool_groups').doc(requestId).get();
    const memberIds = groupDoc.get('member_ids') ?? [];
    await Promise.all(memberIds.map((memberId) => sendPushToUser(memberId, 'Payment pending', 'Your carpool ride is complete. Please settle payment.')));
});
exports.sendFCMNotification = (0, https_1.onCall)({ invoker: 'public' }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    const userId = request.data?.userId;
    const title = request.data?.title;
    const body = request.data?.body;
    if (!userId || !title || !body) {
        throw new https_1.HttpsError('invalid-argument', 'userId, title, and body are required.');
    }
    await sendPushToUser(userId, title, body);
    return { success: true };
});
// Copies a payee's bank/QR details onto a payment document, server-side.
// This is the ONLY place that reads another user's bank_details doc — it
// runs with admin privileges and bypasses Firestore rules by design. The
// client never reads bank_details/{otherUid} directly; it calls this
// function instead, right after creating a payment document.
const ALLOWED_PAYMENT_COLLECTIONS = ['ride_payments', 'delivery_payments'];
exports.copyPayeeBankDetails = (0, https_1.onCall)({ invoker: 'public' }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    const payeeId = request.data?.payeeId;
    const paymentCollection = request.data?.paymentCollection;
    const paymentId = request.data?.paymentId;
    if (!payeeId || !paymentCollection || !paymentId) {
        throw new https_1.HttpsError('invalid-argument', 'payeeId, paymentCollection, and paymentId are required.');
    }
    if (!ALLOWED_PAYMENT_COLLECTIONS.includes(paymentCollection)) {
        throw new https_1.HttpsError('invalid-argument', 'Unknown payment collection.');
    }
    const paymentRef = db.collection(paymentCollection).doc(paymentId);
    const paymentSnap = await paymentRef.get();
    if (!paymentSnap.exists) {
        throw new https_1.HttpsError('not-found', 'Payment document not found.');
    }
    const bankDoc = await db.collection('bank_details').doc(payeeId).get();
    let bankData = bankDoc.exists ? bankDoc.data() : null;
    if (!bankData) {
        const userDoc = await db.collection('users').doc(payeeId).get();
        const userData = userDoc.data();
        const legacyBankDetails = userData?.bankDetails;
        if (legacyBankDetails) {
            bankData = legacyBankDetails;
        }
        else {
            const legacyQr = userData?.qr_code_url ??
                userData?.qrCodeUrl;
            if (legacyQr) {
                bankData = { qrCodeUrl: legacyQr };
            }
        }
    }
    await paymentRef.update({
        payee_bank_snapshot: bankData
            ? {
                bankName: bankData.bankName ?? '',
                accountHolderName: bankData.accountHolderName ?? '',
                accountNumber: bankData.accountNumber ?? '',
                qrCodeUrl: bankData.qrCodeUrl ?? '',
            }
            : null,
    });
    return { success: true, hasBankDetails: bankData !== null };
});
