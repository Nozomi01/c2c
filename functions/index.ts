import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

admin.initializeApp();

const db = admin.firestore();

// Set from environment: functions.config().stripe.secret
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY ?? '', {
  apiVersion: '2024-06-20',
});

// Create PaymentIntent for escrow
export const createEscrowPaymentIntent = functions.https.onCall(
  async (data, context) => {
    const { amount, currency, serviceId, buyerId, sellerId } = data;

    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required',
      );
    }

    if (!amount || !currency || !serviceId || !buyerId || !sellerId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Missing required fields',
      );
    }

    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency,
      capture_method: 'manual', // hold payment
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
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      clientSecret: paymentIntent.client_secret,
      transactionId: txRef.id,
    };
  },
);

// Release funds after completion confirmation
export const releaseEscrow = functions.https.onCall(
  async (data, context) => {
    const { transactionId } = data;
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Authentication required',
      );
    }

    const txSnap = await db.collection('transactions').doc(transactionId).get();
    if (!txSnap.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Transaction not found',
      );
    }
    const tx = txSnap.data()!;
    const paymentIntentId = tx.paymentIntentId as string | undefined;
    if (!paymentIntentId) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'No payment intent attached',
      );
    }

    await stripe.paymentIntents.capture(paymentIntentId);

    await txSnap.ref.update({
      status: 'completed',
    });

    return { success: true };
  },
);

// Payout request – transfer to seller via Connect
export const requestPayout = functions.firestore
  .document('payout_requests/{id}')
  .onCreate(async (snap) => {
    const data = snap.data();
    const { userId, amount, stripeAccountId } = data;

    if (!stripeAccountId) {
      console.warn('No stripeAccountId for user', userId);
      return;
    }

    await stripe.transfers.create({
      amount,
      currency: 'jpy',
      destination: stripeAccountId,
      metadata: { userId },
    });

    await snap.ref.update({
      status: 'completed',
    });
  });

