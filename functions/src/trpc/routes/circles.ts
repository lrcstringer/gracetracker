import * as z from 'zod';
import { TRPCError } from '@trpc/server';
import { FieldValue } from 'firebase-admin/firestore';
import { createTRPCRouter, protectedProcedure } from '../create-context';
import {
  db,
  circlesCol,
  inviteCodesCol,
  membersCol,
  heatmapEntriesCol,
  milestonesCol,
  metaDoc,
  Timestamp,
} from '../../lib/firestore';

const MAX_CIRCLE_MEMBERS = 10_000;

const GIVING_DAY_THRESHOLDS = [100, 500, 1_000, 2_500, 5_000];
const HOUR_THRESHOLDS = [10, 100, 500, 1_000];
const GRATITUDE_DAY_THRESHOLDS = [100, 500, 1_000];

interface HeatmapEntry {
  userId: string;
  circleId: string;
  weekData: Array<{ date: string; score: number }>;
  submittedAt: FirebaseFirestore.Timestamp;
}

function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 8; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

export const circlesRouter = createTRPCRouter({
  create: protectedProcedure
    .input(
      z.object({
        name: z.string().min(1).max(100),
        description: z.string().max(500).optional().default(''),
      })
    )
    .mutation(async ({ ctx, input }) => {
      const circleId = crypto.randomUUID();
      const inviteCode = generateInviteCode();

      const batch = db.batch();
      batch.set(circlesCol().doc(circleId), {
        id: circleId,
        name: input.name,
        description: input.description,
        creatorId: ctx.userId,
        inviteCode,
        memberCount: 1,
        createdAt: Timestamp.now(),
      });
      batch.set(inviteCodesCol().doc(inviteCode), {
        circleId,
        circleName: input.name,
        createdAt: Timestamp.now(),
      });
      batch.set(membersCol(circleId).doc(ctx.userId), {
        userId: ctx.userId,
        role: 'admin',
        joinedAt: Timestamp.now(),
        sosContactIds: [],
        ...(ctx.displayName ? { displayName: ctx.displayName } : {}),
      });
      await batch.commit();

      return { id: circleId, name: input.name, inviteCode };
    }),

  join: protectedProcedure
    .input(z.object({ inviteCode: z.string() }))
    .mutation(async ({ ctx, input }) => {
      const code = input.inviteCode.toUpperCase();
      const codeSnap = await inviteCodesCol().doc(code).get();
      if (!codeSnap.exists) {
        throw new TRPCError({ code: 'NOT_FOUND', message: 'No prayer circle found with that invite code' });
      }

      const circleId = codeSnap.data()!.circleId as string;
      const circleSnap = await circlesCol().doc(circleId).get();
      if (!circleSnap.exists) {
        throw new TRPCError({ code: 'NOT_FOUND', message: 'Circle no longer exists' });
      }

      const circle = circleSnap.data()!;
      if (circle.memberCount >= MAX_CIRCLE_MEMBERS) {
        throw new TRPCError({ code: 'FORBIDDEN', message: 'This prayer circle has reached its maximum capacity' });
      }

      const memberSnap = await membersCol(circleId).doc(ctx.userId).get();
      if (memberSnap.exists) {
        return { id: circleId, name: circle.name as string, alreadyMember: true };
      }

      const batch = db.batch();
      batch.set(membersCol(circleId).doc(ctx.userId), {
        userId: ctx.userId,
        role: 'member',
        joinedAt: Timestamp.now(),
        sosContactIds: [],
        ...(ctx.displayName ? { displayName: ctx.displayName } : {}),
      });
      batch.update(circlesCol().doc(circleId), { memberCount: FieldValue.increment(1) });
      await batch.commit();

      return { id: circleId, name: circle.name as string, alreadyMember: false };
    }),

  list: protectedProcedure.query(async ({ ctx }) => {
    const memberSnaps = await db.collectionGroup('members').where('userId', '==', ctx.userId).get();
    if (memberSnaps.empty) return [];

    const circleIds = memberSnaps.docs.map((d) => d.ref.parent.parent!.id);
    const circleSnaps = await Promise.all(circleIds.map((id) => circlesCol().doc(id).get()));

    return circleSnaps
      .filter((s) => s.exists)
      .map((s) => {
        const c = s.data()!;
        const membership = memberSnaps.docs.find((m) => m.ref.parent.parent!.id === s.id)?.data();
        return {
          id: s.id,
          name: c.name as string,
          description: c.description as string,
          memberCount: c.memberCount as number,
          role: membership?.role ?? 'member',
          inviteCode: c.inviteCode as string,
        };
      });
  }),

  getDetail: protectedProcedure
    .input(z.object({ circleId: z.string() }))
    .query(async ({ ctx, input }) => {
      const [circleSnap, memberSnap, allMembersSnap] = await Promise.all([
        circlesCol().doc(input.circleId).get(),
        membersCol(input.circleId).doc(ctx.userId).get(),
        membersCol(input.circleId).get(),
      ]);

      if (!circleSnap.exists) throw new TRPCError({ code: 'NOT_FOUND', message: 'Circle not found' });
      if (!memberSnap.exists) throw new TRPCError({ code: 'FORBIDDEN', message: 'You are not a member of this circle' });

      const c = circleSnap.data()!;
      return {
        id: circleSnap.id,
        name: c.name as string,
        description: c.description as string,
        memberCount: c.memberCount as number,
        inviteCode: c.inviteCode as string,
        createdAt: (c.createdAt as FirebaseFirestore.Timestamp).toDate().toISOString(),
        members: allMembersSnap.docs.map((m) => {
          const d = m.data();
          return {
            userId: d.userId as string,
            role: d.role as string,
            joinedAt: (d.joinedAt as FirebaseFirestore.Timestamp).toDate().toISOString(),
          };
        }),
      };
    }),

  leave: protectedProcedure
    .input(z.object({ circleId: z.string() }))
    .mutation(async ({ ctx, input }) => {
      const batch = db.batch();
      batch.delete(membersCol(input.circleId).doc(ctx.userId));
      batch.update(circlesCol().doc(input.circleId), { memberCount: FieldValue.increment(-1) });
      await batch.commit();
      return { success: true };
    }),

  submitHeatmapData: protectedProcedure
    .input(
      z.object({
        circleId: z.string(),
        weekData: z.array(z.object({ date: z.string(), score: z.number().min(0).max(1) })),
      })
    )
    .mutation(async ({ ctx, input }) => {
      const memberSnap = await membersCol(input.circleId).doc(ctx.userId).get();
      if (!memberSnap.exists) throw new TRPCError({ code: 'FORBIDDEN', message: 'Not a member' });

      // Write heatmap entry
      await heatmapEntriesCol(input.circleId).doc(ctx.userId).set({
        userId: ctx.userId,
        circleId: input.circleId,
        weekData: input.weekData,
        submittedAt: Timestamp.now(),
      });

      // Update aggregate totals and check milestones in a transaction
      await db.runTransaction(async (tx) => {
        const totalsRef = metaDoc(input.circleId);
        const totalsSnap = await tx.get(totalsRef);
        const prev = totalsSnap.data() ?? { totalGivingDays: 0, totalHours: 0, totalGratitudeDays: 0 };

        const newStrongDays = input.weekData.filter((d) => d.score >= 0.5).length;
        // Approximate hours: strong days * avg daily giving time (assume ~1hr/strong day)
        const newHours = input.weekData.reduce((sum, d) => sum + (d.score >= 0.5 ? d.score : 0), 0);

        const next = {
          totalGivingDays: (prev.totalGivingDays as number) + newStrongDays,
          totalHours: (prev.totalHours as number) + newHours,
          totalGratitudeDays: prev.totalGratitudeDays as number,
          lastUpdated: Timestamp.now(),
        };

        tx.set(totalsRef, next);

        // Check giving day thresholds
        for (const threshold of GIVING_DAY_THRESHOLDS) {
          if ((prev.totalGivingDays as number) < threshold && next.totalGivingDays >= threshold) {
            tx.set(milestonesCol(input.circleId).doc(`givingDays_${threshold}`), {
              id: `givingDays_${threshold}`,
              title: `${threshold} Giving Days Together`,
              message: `Your circle has shared ${threshold} strong days together. That's faithfulness at scale.`,
              metric: 'givingDays',
              threshold,
              achievedAt: Timestamp.now(),
            });
          }
        }

        // Check hour thresholds
        for (const threshold of HOUR_THRESHOLDS) {
          if ((prev.totalHours as number) < threshold && next.totalHours >= threshold) {
            tx.set(milestonesCol(input.circleId).doc(`hours_${threshold}`), {
              id: `hours_${threshold}`,
              title: `${threshold} Hours Together`,
              message: `Together your circle has given ${threshold} hours to God.`,
              metric: 'hours',
              threshold,
              achievedAt: Timestamp.now(),
            });
          }
        }
      });

      return { success: true };
    }),

  getHeatmap: protectedProcedure
    .input(
      z.object({
        circleId: z.string(),
        weekCount: z.number().min(1).max(52).default(1),
      })
    )
    .query(async ({ ctx, input }) => {
      const memberSnap = await membersCol(input.circleId).doc(ctx.userId).get();
      if (!memberSnap.exists) throw new TRPCError({ code: 'FORBIDDEN', message: 'Not a member' });

      const entrySnaps = await heatmapEntriesCol(input.circleId).get();
      const totalMembers = Math.max(entrySnaps.size, 1);

      // Compute date cutoff
      const now = new Date();
      const cutoff = new Date(now);
      cutoff.setDate(cutoff.getDate() - input.weekCount * 7);
      const cutoffStr = cutoff.toISOString().split('T')[0];

      // Aggregate: count members with score >= 0.5 per date ("strong day")
      const strongCount: Record<string, number> = {};
      const seenCount: Record<string, number> = {};

      for (const snap of entrySnaps.docs) {
        const entry = snap.data() as HeatmapEntry;
        for (const day of entry.weekData) {
          if (day.date < cutoffStr) continue;
          seenCount[day.date] = (seenCount[day.date] ?? 0) + 1;
          if (day.score >= 0.5) strongCount[day.date] = (strongCount[day.date] ?? 0) + 1;
        }
      }

      const days = Object.keys(seenCount)
        .sort()
        .map((date) => ({
          date,
          intensity: (strongCount[date] ?? 0) / totalMembers,
        }));

      return { circleId: input.circleId, weekCount: input.weekCount, days };
    }),

  getMilestones: protectedProcedure
    .input(z.object({ circleId: z.string() }))
    .query(async ({ ctx, input }) => {
      const memberSnap = await membersCol(input.circleId).doc(ctx.userId).get();
      if (!memberSnap.exists) throw new TRPCError({ code: 'FORBIDDEN', message: 'Not a member' });

      const [totalsSnap, milestonesSnap] = await Promise.all([
        metaDoc(input.circleId).get(),
        milestonesCol(input.circleId).orderBy('achievedAt', 'asc').get(),
      ]);

      const totals = totalsSnap.data() ?? { totalGivingDays: 0, totalHours: 0, totalGratitudeDays: 0 };

      const milestones = milestonesSnap.docs.map((d) => {
        const data = d.data();
        return {
          id: data.id as string,
          title: data.title as string,
          message: data.message as string,
          achievedAt: (data.achievedAt as FirebaseFirestore.Timestamp).toDate().toISOString(),
        };
      });

      return {
        circleId: input.circleId,
        totalGivingDays: (totals.totalGivingDays as number) ?? 0,
        totalHours: (totals.totalHours as number) ?? 0,
        totalGratitudeDays: (totals.totalGratitudeDays as number) ?? 0,
        milestones,
      };
    }),

  getSundaySummary: protectedProcedure
    .input(z.object({ circleId: z.string() }))
    .query(async ({ ctx, input }) => {
      const memberSnap = await membersCol(input.circleId).doc(ctx.userId).get();
      if (!memberSnap.exists) throw new TRPCError({ code: 'FORBIDDEN', message: 'Not a member' });

      const [circleSnap, entrySnaps] = await Promise.all([
        circlesCol().doc(input.circleId).get(),
        heatmapEntriesCol(input.circleId).get(),
      ]);

      let activeCount = 0;
      let totalScore = 0;

      for (const snap of entrySnaps.docs) {
        const entry = snap.data() as HeatmapEntry;
        if (entry.weekData.length > 0) {
          activeCount++;
          const avg = entry.weekData.reduce((sum, d) => sum + d.score, 0) / entry.weekData.length;
          totalScore += avg;
        }
      }

      return {
        circleId: input.circleId,
        weekOf: new Date().toISOString(),
        totalMembers: (circleSnap.data()?.memberCount as number) ?? 0,
        activeMembers: activeCount,
        averageScore: activeCount > 0 ? totalScore / activeCount : 0,
        topStreaks: [] as Array<{ userId: string; streak: number }>,
      };
    }),
});

// Gratitude day threshold checker — called from gratitudes router
export async function checkGratitudeMilestones(circleId: string): Promise<void> {
  await db.runTransaction(async (tx) => {
    const totalsRef = metaDoc(circleId);
    const totalsSnap = await tx.get(totalsRef);
    const prev = totalsSnap.data() ?? { totalGivingDays: 0, totalHours: 0, totalGratitudeDays: 0 };
    const newTotal = (prev.totalGratitudeDays as number) + 1;

    tx.set(totalsRef, { ...prev, totalGratitudeDays: newTotal, lastUpdated: Timestamp.now() });

    for (const threshold of GRATITUDE_DAY_THRESHOLDS) {
      if ((prev.totalGratitudeDays as number) < threshold && newTotal >= threshold) {
        tx.set(milestonesCol(circleId).doc(`gratitudeDays_${threshold}`), {
          id: `gratitudeDays_${threshold}`,
          title: `${threshold} Days of Gratitude Together`,
          message: `Your circle has given thanks together ${threshold} times. Let the peace of God guard your hearts.`,
          metric: 'gratitudeDays',
          threshold,
          achievedAt: Timestamp.now(),
        });
      }
    }
  });
}
