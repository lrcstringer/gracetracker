import { onRequest } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { IncomingMessage, ServerResponse } from 'http';
import * as admin from 'firebase-admin';
import app from './hono';
export { validateReceipt, appleNotification, googleNotification } from './iap';
export {
  circleCreate,
  circleJoin,
  circleLeave,
  circleShareGratitude,
  circleDeleteGratitude,
  circleSubmitHeatmapData,
  circleUpdateMemberRole,
  circleUpdate,
  circleDelete,
} from './callables/circles';
export {
  prayerRequestCreate,
  prayerPrayFor,
  prayerRequestMarkAnswered,
  expirePrayerRequests,
} from './callables/prayer';
export {
  circleSendEncouragement,
  circleGetEncouragements,
  circleMarkEncouragementRead,
  sendEncouragementPrompts,
} from './callables/encouragement';
export {
  circleShareMilestone,
  circleCelebrateMilestone,
  batchCelebrationNotifications,
} from './callables/milestone_shares';
export {
  circleSubmitPulseResponse,
  circleGetPulseResponses,
  sendPulsePrompts,
} from './callables/pulse';
export {
  circleCreateEvent,
  circleUpdateEvent,
  circleDeleteEvent,
  sendEventReminders,
} from './callables/events';
export { seedHabitCategories } from './callables/habit_categories';
export {
  accountabilityCreateInvite,
  accountabilityAcceptInvite,
  accountabilityDeclineInvite,
  accountabilityNotifyParticipant,
  accountabilityEndForHabit,
} from './callables/accountability';
export { deleteAccount } from './callables/account';

// ── TEMP: Grant premium to all new users (remove before production launch) ──

export const grantTestPremium = onDocumentCreated(
  { document: 'users/{uid}', region: 'us-central1' },
  async (event) => {
    const uid = event.params.uid;
    await admin.firestore()
      .collection('users').doc(uid)
      .collection('subscription').doc('status')
      .set({
        productId: 'lifetimeonetime',
        platform: 'android',
        purchaseId: 'test_grant',
        status: 'active',
        expiresAt: null,
        validatedAt: admin.firestore.Timestamp.now(),
      });
  }
);

// ── Scheduled: purge expired notifications ─────────────────────────────────
import { db, Timestamp } from './lib/firestore';

export const expireNotifications = onSchedule(
  { schedule: 'every 24 hours', region: 'us-central1', memory: '256MiB' },
  async () => {
    const now = Timestamp.now();
    // collectionGroup query across all users' notification subcollections
    const expired = await db
      .collectionGroup('notifications')
      .where('expiresAt', '<=', now)
      .limit(500)
      .get();

    if (expired.empty) return;

    const batch = db.batch();
    expired.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
);

// Convert Firebase's Express-style req/res into a Fetch API Request,
// run it through the Hono app, and pipe the Response back out.
export const api = onRequest(
  { region: 'us-central1', memory: '512MiB', timeoutSeconds: 60 },
  async (req: IncomingMessage & { rawBody?: Buffer; url?: string; method?: string; hostname?: string; headers: Record<string, string | string[] | undefined> }, res: ServerResponse) => {
    const protocol = 'https';
    const host = (req.headers['host'] as string) ?? 'localhost';
    const url = `${protocol}://${host}${req.url ?? '/'}`;

    // Flatten multi-value headers for the Fetch API
    const headers = new Headers();
    for (const [key, value] of Object.entries(req.headers)) {
      if (value === undefined) continue;
      if (Array.isArray(value)) {
        for (const v of value) headers.append(key, v);
      } else {
        headers.set(key, value);
      }
    }

    const isBodyMethod = !['GET', 'HEAD'].includes((req.method ?? 'GET').toUpperCase());
    const fetchReq = new Request(url, {
      method: req.method ?? 'GET',
      headers,
      body: isBodyMethod && req.rawBody ? (req.rawBody as unknown as BodyInit) : undefined,
    });

    const fetchRes = await app.fetch(fetchReq);

    res.statusCode = fetchRes.status;
    fetchRes.headers.forEach((value: string, key: string) => {
      res.setHeader(key, value);
    });

    const body = await fetchRes.text();
    res.end(body);
  }
);
