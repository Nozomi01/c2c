import * as admin from 'firebase-admin';
import Stripe from 'stripe';

import { auth as authV1 } from 'firebase-functions/v1';
import { onCall, HttpsError, onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { defineSecret } from 'firebase-functions/params';

admin.initializeApp();
const db = admin.firestore();

const REGION = 'asia-northeast1';

/* Secrets */
const stripeSecret = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

/* ---------------- USER AUTO CREATION ---------------- */

export const onAuthUserCreate = authV1.user().onCreate(async (user) => {
  const { uid, email, displayName, photoURL, phoneNumber } = user;

  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();

  if (snap.exists) return;

  await userRef.set({
    email: email ?? null,
    displayName: displayName ?? null,
    photoURL: photoURL ?? null,
    phoneNumber: phoneNumber ?? null,
    fcmTokens: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

/* ---------------- LINE LOGIN (custom token) ---------------- */

export const createLineCustomToken = onCall(
  { region: REGION },
  async (request) => {
    const accessToken = request.data?.accessToken;
    if (typeof accessToken !== 'string' || !accessToken) {
      throw new HttpsError('invalid-argument', 'Missing or invalid accessToken');
    }

    const res = await fetch('https://api.line.me/v2/profile', {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!res.ok) {
      throw new HttpsError('unauthenticated', 'Invalid LINE access token');
    }
    const profile = (await res.json()) as { userId: string };
    const lineUserId = profile?.userId;
    if (!lineUserId) {
      throw new HttpsError('internal', 'LINE profile missing userId');
    }

    const firebaseUid = `line_${lineUserId}`;
    const customToken = await admin.auth().createCustomToken(firebaseUid);
    return { customToken };
  }
);

/* ---------------- CREATE ESCROW PAYMENT ---------------- */

export const createEscrowPaymentIntent = onCall(
  {
    region: REGION,
    secrets: [stripeSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const { amount, currency = 'jpy', serviceId, sellerId } = request.data;

    if (!amount || amount <= 0 || !serviceId || !sellerId) {
      throw new HttpsError('invalid-argument', 'Invalid parameters');
    }

    const buyerId = request.auth.uid;

    const stripe = new Stripe(stripeSecret.value(), {
      apiVersion: '2025-02-24.acacia',
    });

    try {
      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency,
        capture_method: 'manual',
        metadata: {
          serviceId,
          buyerId,
          sellerId,
        },
      });

      const txRef = await db.collection('transactions').add({
        serviceId,
        buyerId,
        sellerId,
        price: amount,
        currency,
        status: 'pending',
        paymentIntentId: paymentIntent.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        clientSecret: paymentIntent.client_secret,
        transactionId: txRef.id,
      };
    } catch (err) {
      console.error('PaymentIntent error', err);
      throw new HttpsError('internal', 'Payment creation failed');
    }
  }
);

/* ---------------- RELEASE ESCROW ---------------- */

export const releaseEscrow = onCall(
  {
    region: REGION,
    secrets: [stripeSecret],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const { transactionId } = request.data;

    if (!transactionId) {
      throw new HttpsError('invalid-argument', 'transactionId required');
    }

    const txRef = db.collection('transactions').doc(transactionId);
    const txSnap = await txRef.get();

    if (!txSnap.exists) {
      throw new HttpsError('not-found', 'Transaction not found');
    }

    const tx = txSnap.data();

    if (!tx) {
      throw new HttpsError('internal', 'Transaction data missing');
    }

    if (tx.buyerId !== request.auth.uid) {
      throw new HttpsError(
        'permission-denied',
        'Only buyer can release escrow'
      );
    }

    if (tx.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Transaction not pending');
    }

    const stripe = new Stripe(stripeSecret.value(), {
      apiVersion: '2025-02-24.acacia',
    });

    try {
      await stripe.paymentIntents.capture(tx.paymentIntentId);

      await txRef.update({
        status: 'completed',
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    } catch (err) {
      console.error('Capture error', err);
      throw new HttpsError('internal', 'Failed to capture payment');
    }
  }
);

/* ---------------- SELLER PAYOUT ---------------- */

export const requestPayout = onDocumentCreated(
  {
    region: REGION,
    document: 'payout_requests/{id}',
    secrets: [stripeSecret],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();

    const { userId, amount, stripeAccountId } = data;

    if (!stripeAccountId) {
      console.warn('Missing stripeAccountId', userId);
      return;
    }

    const stripe = new Stripe(stripeSecret.value(), {
      apiVersion: '2025-02-24.acacia',
    });

    try {
      await stripe.transfers.create({
        amount,
        currency: 'jpy',
        destination: stripeAccountId,
        metadata: { userId },
      });

      await snap.ref.update({
        status: 'completed',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      console.error('Transfer failed', err);

      await snap.ref.update({
        status: 'failed',
        error: String(err),
      });
    }
  }
);

/* ---------------- STRIPE WEBHOOK ---------------- */

export const stripeWebhook = onRequest(
  {
    region: REGION,
    secrets: [stripeSecret, stripeWebhookSecret],
  },
  async (req, res) => {
    const stripe = new Stripe(stripeSecret.value(), {
      apiVersion: '2025-02-24.acacia',
    });

    const sig = req.headers['stripe-signature'];

    if (!sig) {
      res.status(400).send('Missing Stripe signature');
      return;
    }

    let event: Stripe.Event;

    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        sig as string,
        stripeWebhookSecret.value()
      );
    } catch (err) {
      console.error('Webhook verification failed', err);
      res.status(400).send('Invalid signature');
      return;
    }

    try {
      switch (event.type) {
        case 'payment_intent.succeeded': {
          const paymentIntent = event.data.object as Stripe.PaymentIntent;

          const txSnap = await db
            .collection('transactions')
            .where('paymentIntentId', '==', paymentIntent.id)
            .limit(1)
            .get();

          if (!txSnap.empty) {
            await txSnap.docs[0].ref.update({
              status: 'completed',
              stripeStatus: paymentIntent.status,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          break;
        }

        case 'payment_intent.payment_failed': {
          const paymentIntent = event.data.object as Stripe.PaymentIntent;

          const txSnap = await db
            .collection('transactions')
            .where('paymentIntentId', '==', paymentIntent.id)
            .limit(1)
            .get();

          if (!txSnap.empty) {
            await txSnap.docs[0].ref.update({
              status: 'failed',
              stripeStatus: paymentIntent.status,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          break;
        }

        default:
          console.log(`Unhandled Stripe event: ${event.type}`);
      }

      res.json({ received: true });
    } catch (err) {
      console.error('Webhook processing error', err);
      res.status(500).send('Webhook handler error');
    }
  }
);

/* ---------------- SEND PUSH NOTIFICATION ---------------- */

export const sendUserNotification = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const { userId, title, body, type, extraData } = request.data;

    if (!userId || !title || !body) {
      throw new HttpsError('invalid-argument', 'Missing fields');
    }

    const userDoc = await db.collection('users').doc(userId).get();

    if (!userDoc.exists) {
      throw new HttpsError('not-found', 'User not found');
    }

    const tokens = (userDoc.data()?.fcmTokens || []).filter((t: string) => !!t);

    if (!tokens.length) {
      return { sent: false, reason: 'no tokens' };
    }

    await db.collection('notifications').add({
      userId,
      title,
      body,
      type: type ?? null,
      read: false,
      data: extraData ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: { title, body },
      data: {
        type: type ?? '',
        ...(extraData || {}),
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    return {
      sent: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  }
);