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

type LineProfile = {
  userId: string;
  displayName?: string;
  pictureUrl?: string;
  statusMessage?: string;
};

async function createLineCustomTokenFromAccessToken(accessToken: string): Promise<string> {
  const res = await fetch('https://api.line.me/v2/profile', {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) {
    throw new Error('Invalid LINE access token');
  }
  const profile = (await res.json()) as LineProfile;
  const lineUserId = profile?.userId;
  if (!lineUserId) {
    throw new Error('LINE profile missing userId');
  }
  const firebaseUid = `line_${lineUserId}`;

  // Save LINE profile to Firestore so user document has displayName, photo, bio (statusMessage).
  const userRef = db.collection('users').doc(firebaseUid);
  await userRef.set(
    {
      displayName: profile.displayName ?? null,
      photoURL: profile.pictureUrl ?? null,
      bio: profile.statusMessage ?? null,
      lineId: lineUserId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return admin.auth().createCustomToken(firebaseUid);
}

/** Callable: requires App Check. Use lineCustomTokenHttp when App Check fails (e.g. emulator). */
export const createLineCustomToken = onCall(
  { region: REGION },
  async (request) => {
    const accessToken = request.data?.accessToken;
    if (typeof accessToken !== 'string' || !accessToken) {
      throw new HttpsError('invalid-argument', 'Missing or invalid accessToken');
    }
    const customToken = await createLineCustomTokenFromAccessToken(accessToken);
    return { customToken };
  }
);

/** HTTP: no App Check. Use for LINE login when App Check attestation fails (e.g. Android emulator). */
export const lineCustomTokenHttp = onRequest(
  { region: REGION },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }
    let body: { accessToken?: string } = {};
    const parsed = typeof req.body === 'object' && req.body !== null ? req.body : null;
    if (parsed && typeof (parsed as Record<string, unknown>).accessToken === 'string') {
      body = parsed as { accessToken?: string };
    } else {
      const raw = (req as { rawBody?: Buffer }).rawBody;
      const rawStr = raw && raw.length > 0 ? raw.toString() : null;
      if (rawStr) {
        try {
          body = JSON.parse(rawStr) as { accessToken?: string };
        } catch {
          res.status(400).json({ error: 'Invalid JSON' });
          return;
        }
      }
    }
    const accessToken = body.accessToken;
    if (typeof accessToken !== 'string' || !accessToken) {
      res.status(400).json({ error: 'Missing or invalid accessToken' });
      return;
    }
    try {
      const customToken = await createLineCustomTokenFromAccessToken(accessToken);
      res.status(200).json({ customToken });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Invalid LINE access token';
      console.error('lineCustomTokenHttp error:', err);
      res.status(401).json({ error: message });
    }
  }
);

/* ---------------- STRIPE CONNECT (SELLER ONBOARDING) ---------------- */

const STRIPE_CONNECT_RETURN_URL =
  'https://wanty-d606b.web.app/stripe-connect-return';
const STRIPE_CONNECT_REFRESH_URL =
  'https://wanty-d606b.web.app/stripe-connect-refresh';

async function createStripeConnectAccountLinkForUid(
  uid: string,
  stripe: Stripe,
  returnUrl: string,
  refreshUrl: string
): Promise<{ url: string }> {
  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();
  const userData = userSnap.data() ?? {};
  let stripeAccountId = userData.stripeAccountId as string | undefined;

  if (!stripeAccountId) {
    let email: string | undefined = userData.email as string | undefined;
    if (!email) {
      try {
        const authUser = await admin.auth().getUser(uid);
        email = authUser.email ?? undefined;
      } catch {
        // ignore
      }
    }
    const account = await stripe.accounts.create({
      type: 'express',
      country: 'JP',
      email: email ?? undefined,
    });
    stripeAccountId = account.id;
    await userRef.set(
      {
        stripeAccountId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  const accountLink = await stripe.accountLinks.create({
    account: stripeAccountId,
    type: 'account_onboarding',
    return_url: returnUrl,
    refresh_url: refreshUrl,
  });

  return { url: accountLink.url };
}

export const createStripeConnectAccountLink = onCall(
  {
    region: REGION,
    secrets: [stripeSecret],
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError('unauthenticated', 'Authentication required');
      }
      const secret = stripeSecret.value();
      if (!secret) {
        throw new HttpsError('failed-precondition', 'STRIPE_SECRET_KEY is not configured');
      }
      const stripe = new Stripe(secret, {
        apiVersion: '2025-02-24.acacia',
      });
      const returnUrl =
        (request.data?.return_url as string) || STRIPE_CONNECT_RETURN_URL;
      const refreshUrl =
        (request.data?.refresh_url as string) || STRIPE_CONNECT_REFRESH_URL;
      return await createStripeConnectAccountLinkForUid(
        request.auth.uid,
        stripe,
        returnUrl,
        refreshUrl
      );
    } catch (err: unknown) {
      if (err instanceof HttpsError) throw err;
      const stripeErr = err as { type?: string; message?: string };
      const msg = typeof stripeErr.message === 'string' ? stripeErr.message : '';
      if (
        stripeErr.type === 'StripeInvalidRequestError' &&
        msg.includes('signed up for Connect')
      ) {
        throw new HttpsError(
          'failed-precondition',
          'Stripe Connectが有効になっていません。StripeダッシュボードでConnectを有効にしてください。'
        );
      }
      const message = err instanceof Error ? err.message : String(err);
      console.error('createStripeConnectAccountLink error:', err);
      throw new HttpsError('internal', `Stripe連携の準備に失敗しました: ${message}`);
    }
  }
);

/** HTTP: no App Check. Use when callable fails with "1 out of 2 underlying tasks failed" (e.g. App Check). */
export const createStripeConnectAccountLinkHttp = onRequest(
  {
    region: REGION,
    secrets: [stripeSecret],
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }
    const authHeader = req.headers.authorization;
    const idToken = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!idToken) {
      res.status(401).json({ error: 'Missing or invalid Authorization header' });
      return;
    }
    let decodedToken: admin.auth.DecodedIdToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch {
      res.status(401).json({ error: 'Invalid or expired token' });
      return;
    }
    const uid = decodedToken.uid;
    const secret = stripeSecret.value();
    if (!secret) {
      res.status(503).json({ error: 'Stripe not configured' });
      return;
    }
    try {
      const stripe = new Stripe(secret, {
        apiVersion: '2025-02-24.acacia',
      });
      const result = await createStripeConnectAccountLinkForUid(
        uid,
        stripe,
        STRIPE_CONNECT_RETURN_URL,
        STRIPE_CONNECT_REFRESH_URL
      );
      res.status(200).json(result);
    } catch (err: unknown) {
      console.error('createStripeConnectAccountLinkHttp error:', err);
      const stripeErr = err as { type?: string; message?: string };
      const msg = typeof stripeErr.message === 'string' ? stripeErr.message : '';
      if (
        stripeErr.type === 'StripeInvalidRequestError' &&
        msg.includes('signed up for Connect')
      ) {
        res.status(503).json({
          error:
            'Stripe Connectが有効になっていません。StripeダッシュボードでConnectを有効にしてください。',
          code: 'STRIPE_CONNECT_NOT_ENABLED',
          dashboardUrl: 'https://dashboard.stripe.com/connect',
        });
        return;
      }
      res.status(500).json({
        error: err instanceof Error ? err.message : 'Stripe連携の準備に失敗しました',
      });
    }
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