import * as admin from 'firebase-admin';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

async function sendPushToUser(userId: string, title: string, body: string): Promise<void> {
  const userDoc = await db.collection('users').doc(userId).get();
  const token = userDoc.get('fcm_token') as string | undefined;

  if (!token) {
    return;
  }

  await messaging.send({
    token,
    notification: { title, body },
    data: { userId, title, body },
  });
}

export const onApplicantAccepted = onDocumentUpdated('carpool_applicants/{applicantId}', async (event) => {
  const beforeStatus = event.data?.before.data()?.status;
  const afterData = event.data?.after.data();

  if (beforeStatus === afterData?.status || afterData?.status !== 'accepted') {
    return;
  }

  const acceptedUserId = afterData?.user_id as string | undefined;
  if (!acceptedUserId) {
    return;
  }

  await sendPushToUser(acceptedUserId, 'Application accepted', 'Your carpool application has been accepted.');
});

export const onRideCompleted = onDocumentUpdated('carpool_requests/{requestId}', async (event) => {
  const beforeStatus = event.data?.before.data()?.status;
  const afterData = event.data?.after.data();

  if (beforeStatus === afterData?.status || afterData?.status !== 'completed') {
    return;
  }

  const requestId = event.params.requestId as string;
  const groupDoc = await db.collection('carpool_groups').doc(requestId).get();
  const memberIds = (groupDoc.get('member_ids') as string[] | undefined) ?? [];

  await Promise.all(
    memberIds.map((memberId) =>
      sendPushToUser(memberId, 'Payment pending', 'Your carpool ride is complete. Please settle payment.'),
    ),
  );
});

export const sendFCMNotification = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const userId = request.data?.userId as string | undefined;
  const title = request.data?.title as string | undefined;
  const body = request.data?.body as string | undefined;

  if (!userId || !title || !body) {
    throw new HttpsError('invalid-argument', 'userId, title, and body are required.');
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

export const copyPayeeBankDetails = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const payeeId = request.data?.payeeId as string | undefined;
  const paymentCollection = request.data?.paymentCollection as string | undefined;
  const paymentId = request.data?.paymentId as string | undefined;

  if (!payeeId || !paymentCollection || !paymentId) {
    throw new HttpsError(
      'invalid-argument',
      'payeeId, paymentCollection, and paymentId are required.',
    );
  }

  if (!ALLOWED_PAYMENT_COLLECTIONS.includes(paymentCollection)) {
    throw new HttpsError('invalid-argument', 'Unknown payment collection.');
  }

  const paymentRef = db.collection(paymentCollection).doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) {
    throw new HttpsError('not-found', 'Payment document not found.');
  }

  const bankDoc = await db.collection('bank_details').doc(payeeId).get();
  const bankData = bankDoc.exists ? bankDoc.data() : null;

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