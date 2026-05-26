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