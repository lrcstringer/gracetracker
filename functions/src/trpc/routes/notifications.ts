import * as z from 'zod';
import { TRPCError } from '@trpc/server';
import { createTRPCRouter, protectedProcedure } from '../create-context';
import {
  db,
  membersCol,
  circlesCol,
  userNotificationsCol,
  Timestamp,
} from '../../lib/firestore';
import { sendPushToUsers } from '../../lib/fcm';

const NOTIFICATION_TTL_DAYS = 30;

function expiresAt(): FirebaseFirestore.Timestamp {
  const d = new Date();
  d.setDate(d.getDate() + NOTIFICATION_TTL_DAYS);
  return Timestamp.fromDate(d);
}

// ── Helper: resolve all member UIDs of a circle ───────────────────────────────

async function getCircleMemberIds(circleId: string): Promise<string[]> {
  const snap = await membersCol(circleId).get();
  return snap.docs.map((d) => d.id);
}

// ── Helper: resolve display name for the caller ───────────────────────────────

async function getSenderName(uid: string): Promise<string> {
  const doc = await db.collection('users').doc(uid).get();
  return (doc.data()?.displayName as string | undefined) ?? 'A circle member';
}

// ── Helper: get circle name ───────────────────────────────────────────────────

async function getCircleName(circleId: string): Promise<string> {
  const doc = await circlesCol().doc(circleId).get();
  return (doc.data()?.name as string | undefined) ?? 'Your circle';
}

// ── Helper: write a notification doc to each recipient's inbox ────────────────

async function fanOutNotifications(
  recipientIds: string[],
  payload: {
    type: 'sos' | 'prayer_request' | 'announcement';
    circleId: string;
    circleName: string;
    senderUid: string;
    senderName: string;
    message: string;
    suppressActions: boolean;
  }
): Promise<string> {
  const notifId = crypto.randomUUID();
  const now = Timestamp.now();
  const exp = expiresAt();

  // Use a batch for atomicity. Firestore batch limit is 500 ops;
  // the sendPrayerRequest cap of 50 and the member-count guard keep us well under it.
  const batch = db.batch();
  for (const uid of recipientIds) {
    batch.set(userNotificationsCol(uid).doc(notifId), {
      id: notifId,
      type: payload.type,
      circleId: payload.circleId,
      circleName: payload.circleName,
      senderUid: payload.senderUid,
      senderName: payload.senderName,
      message: payload.message,
      createdAt: now,
      expiresAt: exp,
      isRead: false,
      actionTaken: null,
      suppressActions: payload.suppressActions,
    });
  }
  await batch.commit();
  return notifId;
}

// ── Router ────────────────────────────────────────────────────────────────────

export const notificationsRouter = createTRPCRouter({

  // Send a circle announcement (admin only)
  sendAnnouncement: protectedProcedure
    .input(
      z.object({
        circleId: z.string(),
        message: z.string().min(1).max(500),
      })
    )
    .mutation(async ({ ctx, input }) => {
      const memberDoc = await membersCol(input.circleId).doc(ctx.userId).get();
      if (!memberDoc.exists) throw new TRPCError({ code: 'FORBIDDEN', message: 'Not a member' });
      const role = memberDoc.data()?.role as string | undefined;
      if (role !== 'admin') throw new TRPCError({ code: 'FORBIDDEN', message: 'Admins only' });

      const [memberIds, senderName, circleName] = await Promise.all([
        getCircleMemberIds(input.circleId),
        getSenderName(ctx.userId),
        getCircleName(input.circleId),
      ]);

      const recipients = memberIds.filter((id) => id !== ctx.userId);

      const notifId = await fanOutNotifications(recipients, {
        type: 'announcement',
        circleId: input.circleId,
        circleName,
        senderUid: ctx.userId,
        senderName,
        message: input.message,
        suppressActions: false,
      });

      sendPushToUsers(recipients, {
        title: `${circleName} — Announcement`,
        body: input.message,
        data: { notifId, type: 'announcement', circleId: input.circleId },
        channelId: 'circles',
      }).catch(() => undefined);

      return { notifId, recipientCount: recipients.length };
    }),

  // Send a help/prayer request (any member, to chosen recipients, 2/day limit for non-admins)
  sendPrayerRequest: protectedProcedure
    .input(
      z.object({
        circleId: z.string(),
        message: z.string().min(1).max(500),
        recipientIds: z.array(z.string()).min(1).max(50),
      })
    )
    .mutation(async ({ ctx, input }) => {
      const memberDoc = await membersCol(input.circleId).doc(ctx.userId).get();
      if (!memberDoc.exists) throw new TRPCError({ code: 'FORBIDDEN', message: 'Not a member' });

      const role = memberDoc.data()?.role as string | undefined;
      const isAdmin = role === 'admin';

      // Rate limit: non-admins may send at most 2 prayer requests per calendar day (UTC).
      const today = new Date().toISOString().slice(0, 10); // "YYYY-MM-DD"
      let todayCount = 0;
      if (!isAdmin) {
        const lastDate = memberDoc.data()?.prayerRequestDate as string | undefined;
        todayCount = lastDate === today ? ((memberDoc.data()?.prayerRequestCount as number) ?? 0) : 0;
        if (todayCount >= 2) {
          throw new TRPCError({
            code: 'TOO_MANY_REQUESTS',
            message: 'You can send up to 2 prayer requests per day.',
          });
        }
      }

      // Verify all requested recipients are actual members of this circle.
      const actualMemberIds = await getCircleMemberIds(input.circleId);
      const memberSet = new Set(actualMemberIds);
      const invalidRecipients = input.recipientIds.filter((id) => !memberSet.has(id));
      if (invalidRecipients.length > 0) {
        throw new TRPCError({ code: 'BAD_REQUEST', message: 'One or more recipients are not members of this circle' });
      }

      const [senderName, circleName] = await Promise.all([
        getSenderName(ctx.userId),
        getCircleName(input.circleId),
      ]);

      const recipients = input.recipientIds.filter((id) => id !== ctx.userId);

      const notifId = await fanOutNotifications(recipients, {
        type: 'prayer_request',
        circleId: input.circleId,
        circleName,
        senderUid: ctx.userId,
        senderName,
        message: input.message,
        suppressActions: false,
      });

      sendPushToUsers(recipients, {
        title: `${senderName} needs prayer`,
        body: input.message,
        data: { notifId, type: 'prayer_request', circleId: input.circleId },
        channelId: 'circles',
      }).catch(() => undefined);

      // Increment daily counter for non-admins (fire-and-forget — a missed write at
      // worst permits one extra send, which is acceptable for a faith app).
      if (!isAdmin) {
        membersCol(input.circleId).doc(ctx.userId).update({
          prayerRequestDate: today,
          prayerRequestCount: todayCount + 1,
        }).catch(() => undefined);
      }

      return { notifId, recipientCount: recipients.length };
    }),

  // Record an action (Pray / I'm Here) against a notification
  recordAction: protectedProcedure
    .input(
      z.object({
        notifId: z.string(),
        action: z.enum(['pray', 'im_here']),
      })
    )
    .mutation(async ({ ctx, input }) => {
      const ref = userNotificationsCol(ctx.userId).doc(input.notifId);
      const doc = await ref.get();
      if (!doc.exists) throw new TRPCError({ code: 'NOT_FOUND' });

      await ref.update({ actionTaken: input.action, isRead: true });
      return { notifId: input.notifId, action: input.action };
    }),

  // Mark a single notification as read
  markRead: protectedProcedure
    .input(z.object({ notifId: z.string() }))
    .mutation(async ({ ctx, input }) => {
      await userNotificationsCol(ctx.userId).doc(input.notifId).update({ isRead: true });
      return { notifId: input.notifId };
    }),

  // Fetch the caller's full notification inbox (newest first).
  // NOTE: onlyUnread filters in-memory to avoid a composite index requirement.
  getInbox: protectedProcedure
    .input(
      z.object({
        limit: z.number().min(1).max(100).optional().default(50),
        onlyUnread: z.boolean().optional().default(false),
      })
    )
    .query(async ({ ctx, input }) => {
      // Always query by createdAt only (single-field index, no composite needed).
      // If unread-only is requested, fetch a larger set and filter in-memory so
      // we can still return up to `limit` unread items without a composite index.
      const fetchLimit = input.onlyUnread ? Math.min(input.limit * 4, 400) : input.limit;
      const snap = await userNotificationsCol(ctx.userId)
        .orderBy('createdAt', 'desc')
        .limit(fetchLimit)
        .get();
      const allDocs = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: data.id as string,
          type: data.type as 'sos' | 'prayer_request' | 'announcement',
          circleId: data.circleId as string,
          circleName: data.circleName as string,
          senderUid: data.senderUid as string,
          senderName: data.senderName as string,
          message: data.message as string,
          createdAt: (data.createdAt as FirebaseFirestore.Timestamp).toDate().toISOString(),
          isRead: data.isRead as boolean,
          actionTaken: (data.actionTaken as string | null) ?? null,
          suppressActions: data.suppressActions as boolean,
        };
      });
      if (input.onlyUnread) {
        return allDocs.filter((n) => !n.isRead).slice(0, input.limit);
      }
      return allDocs;
    }),

  // Unread count (for badge)
  getUnreadCount: protectedProcedure
    .query(async ({ ctx }) => {
      const snap = await userNotificationsCol(ctx.userId)
        .where('isRead', '==', false)
        .count()
        .get();
      return { count: snap.data().count };
    }),
});
