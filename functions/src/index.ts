import * as admin from 'firebase-admin';
import Stripe from 'stripe';

import { auth as authV1 } from 'firebase-functions/v1';
import { onCall, HttpsError, onRequest } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentUpdated } from 'firebase-functions/v2/firestore';
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

/* ---------------- SELLER RATING AGGREGATION ---------------- */

export const onTransactionReviewed = onDocumentUpdated(
  {
    region: REGION,
    document: 'transactions/{id}',
  },
  async (event) => {
    const before = event.data?.before?.data() as any | undefined;
    const after = event.data?.after?.data() as any | undefined;
    if (!after) return;

    const beforeRating = typeof before?.rating === 'number' ? before.rating : null;
    const afterRating = typeof after.rating === 'number' ? after.rating : null;
    const beforeStatus = typeof before?.status === 'string' ? before.status : null;
    const afterStatus = typeof after.status === 'string' ? after.status : null;

    // Only react when a review was newly submitted / changed.
    const becameReviewed = beforeStatus !== 'reviewed' && afterStatus === 'reviewed';
    const ratingChanged = beforeRating !== afterRating && afterRating != null;
    if (!becameReviewed && !ratingChanged) return;

    const sellerId = after.sellerId as string | undefined;
    if (!sellerId) return;

    // Recompute seller rating from reviewed transactions.
    const snap = await db
      .collection('transactions')
      .where('sellerId', '==', sellerId)
      .where('status', '==', 'reviewed')
      .get();

    let sum = 0;
    let count = 0;
    for (const doc of snap.docs) {
      const data = doc.data() as any;
      const r = data.rating;
      if (typeof r === 'number' && r > 0) {
        sum += r;
        count += 1;
      }
    }

    const avg = count > 0 ? sum / count : 0;

    await db
      .collection('users')
      .doc(sellerId)
      .set(
        {
          rating: Number(avg.toFixed(2)),
          reviewCount: count,
          ratingUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
  }
);

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

/* ---------------- STRIPE CONNECTED ACCOUNT BALANCE ---------------- */

export const getStripeBalance = onCall(
  {
    region: REGION,
    secrets: [stripeSecret],
  },
  async (request) => {
    const uid =
      (request.auth && request.auth.uid) ||
      (typeof request.data?.userId === 'string' ? (request.data.userId as string) : null);

    if (!uid) {
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userSnap = await db.collection('users').doc(uid).get();
    const userData = userSnap.data() ?? {};
    const stripeAccountId = userData.stripeAccountId as string | undefined;

    if (!stripeAccountId) {
      throw new HttpsError(
        'failed-precondition',
        'Stripe口座が未連携です（出金にはStripe連携が必要です）'
      );
    }

    const stripe = new Stripe(stripeSecret.value(), {
      apiVersion: '2025-02-24.acacia',
    });

    const balance = await stripe.balance.retrieve({ stripeAccount: stripeAccountId });

    const available = (balance.available && balance.available[0]) || null;
    const pending = (balance.pending && balance.pending[0]) || null;

    return {
      stripeAccountId,
      availableAmount: available?.amount ?? 0,
      availableCurrency: available?.currency ?? 'jpy',
      pendingAmount: pending?.amount ?? 0,
      pendingCurrency: pending?.currency ?? 'jpy',
      raw: balance,
    };
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

    const {
      amount,
      currency = 'jpy',
      serviceId,
      sellerId,
      requestId,
      requestType,
      requestTitle,
      // Optional: platform fee in smallest currency unit (e.g. JPY).
      // If omitted, fee is 0.
      applicationFeeAmount = 0.1,
    } = request.data;

    if (!amount || amount <= 0 || !serviceId || !sellerId) {
      throw new HttpsError('invalid-argument', 'Invalid parameters');
    }

    const buyerId = request.auth.uid;

    const stripe = new Stripe(stripeSecret.value(), {
      apiVersion: '2025-02-24.acacia',
    });

    try {
      const sellerSnap = await db.collection('users').doc(sellerId).get();
      const sellerData = sellerSnap.data() as { stripeAccountId?: string } | undefined;
      const sellerStripeAccountId = sellerData?.stripeAccountId;
      if (!sellerStripeAccountId) {
        throw new HttpsError(
          'failed-precondition',
          'Seller has not connected Stripe account'
        );
      }

      const fee =
        typeof applicationFeeAmount === 'number' && applicationFeeAmount > 0 ? Math.floor(applicationFeeAmount) : 0;

      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency,
        capture_method: 'manual',
        // Connect: route the captured funds to the seller (destination charge).
        transfer_data: { destination: sellerStripeAccountId },
        ...(fee > 0 ? { application_fee_amount: fee } : {}),
        transfer_group: `tx_${serviceId}_${buyerId}_${sellerId}`,
        metadata: {
          serviceId,
          buyerId,
          sellerId,
          ...(requestId ? { requestId: String(requestId) } : {}),
          ...(requestType ? { requestType: String(requestType) } : {}),
        },
      });

      const txRef = await db.collection('transactions').add({
        serviceId,
        ...(requestId ? { requestId } : {}),
        ...(requestType ? { requestType } : {}),
        ...(requestTitle ? { requestTitle } : {}),
        buyerId,
        sellerId,
        sellerStripeAccountId,
        price: amount,
        currency,
        applicationFeeAmount: fee,
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

    if (tx.status !== 'inProgress' && tx.status !== 'paid') {
      throw new HttpsError(
        'failed-precondition',
        'Transaction is not ready to be completed'
      );
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

    try {
      const stripe = new Stripe(stripeSecret.value(), {
        apiVersion: '2025-02-24.acacia',
      });

      // Create a payout from the connected account balance to the seller's bank.
      await stripe.payouts.create(
        {
          amount,
          currency: 'jpy',
          metadata: { userId },
        },
        {
          stripeAccount: stripeAccountId,
        }
      );

      // Decrease in-app wallet balance only after payout creation succeeds.
      await db.runTransaction(async (t) => {
        const userRef = db.collection('users').doc(userId as string);
        const userSnap = await t.get(userRef);
        const userData = userSnap.data() || {};
        const current = Number(userData.walletBalance ?? 0);
        const next = Math.max(0, current - Number(amount ?? 0));
        t.set(
          userRef,
          {
            walletBalance: next,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        t.update(snap.ref, {
          status: 'completed',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
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
            const txRef = txSnap.docs[0].ref;

            // Idempotent credit: Stripe webhooks can retry.
            await db.runTransaction(async (t) => {
              const txDoc = await t.get(txRef);
              if (!txDoc.exists) return;
              const tx = txDoc.data() as any;

              const alreadyCredited = tx.walletCredited === true;
              const sellerId = tx.sellerId as string | undefined;
              const price = Number(tx.price ?? 0);
              const fee = Number(tx.applicationFeeAmount ?? 0);
              const net = Math.max(0, Math.floor(price - fee));

              if (!alreadyCredited && sellerId && net > 0) {
                const sellerRef = db.collection('users').doc(sellerId);
                t.set(
                  sellerRef,
                  {
                    walletBalance: admin.firestore.FieldValue.increment(net),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                  },
                  { merge: true }
                );
              }

              t.update(txRef, {
                status: 'completed',
                stripeStatus: paymentIntent.status,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                completedAt: admin.firestore.FieldValue.serverTimestamp(),
                ...(alreadyCredited ? {} : { walletCredited: true, walletCreditedAt: admin.firestore.FieldValue.serverTimestamp() }),
              });
            });
          }

          break;
        }

        // ---------------- Payout lifecycle (bank transfer from connected account) ----------------
        case 'payout.created':
        case 'payout.paid':
        case 'payout.failed':
        case 'payout.canceled': {
          const payout = event.data.object as Stripe.Payout;
          const connectedAccountId = event.account as string | undefined;

          if (!connectedAccountId) {
            console.warn('Payout event without connected account:', payout.id);
            break;
          }

          // Find our app user by stripeAccountId
          const userSnap = await db
            .collection('users')
            .where('stripeAccountId', '==', connectedAccountId)
            .limit(1)
            .get();

          if (userSnap.empty) {
            console.warn('No user found for payout account:', connectedAccountId);
            break;
          }

          const userRef = userSnap.docs[0].ref;
          const payoutRef = userRef.collection('payouts').doc(payout.id);

          await payoutRef.set(
            {
              amount: payout.amount,
              currency: payout.currency,
              status: payout.status,
              arrivalDate: payout.arrival_date ? admin.firestore.Timestamp.fromMillis(payout.arrival_date * 1000) : null,
              method: payout.method,
              type: payout.type,
              balanceTransaction: payout.balance_transaction,
              failureCode: (payout as any).failure_code ?? null,
              failureMessage: (payout as any).failure_message ?? null,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              stripeAccountId: connectedAccountId,
              raw: payout,
            },
            { merge: true }
          );

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
      return { sent: false, reason: 'user_not_found' };
    }

    // Respect user notification settings.
    const pushEnabled = userDoc.data()?.pushEnabled;
    if (pushEnabled === false) {
      return { sent: false, reason: 'push_disabled' };
    }

    const rawTokens = userDoc.data()?.fcmTokens;
    const tokens = Array.isArray(rawTokens) ? rawTokens.filter((t: unknown): t is string => typeof t === 'string' && t.trim().length > 0) : [];

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

    const safeData: Record<string, string> = {};
    if (type != null) {
      safeData.type = String(type);
    }
    if (extraData && typeof extraData === 'object') {
      for (const [k, v] of Object.entries(extraData as Record<string, unknown>)) {
        if (!k) continue;
        safeData[k] = typeof v === 'string' ? v : JSON.stringify(v);
      }
    }

    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: { title, body },
      android: {
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
      data: {
        ...safeData,
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);
    const invalidTokens: string[] = [];
    response.responses.forEach((r, i) => {
      if (r.success) return;
      const code = r.error?.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(tokens[i]);
      }
    });
    if (invalidTokens.length > 0) {
      await db.collection('users').doc(userId).set(
        {
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    return {
      sent: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    };
  }
);