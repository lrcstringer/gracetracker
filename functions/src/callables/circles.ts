import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import {
  db,
  circlesCol,
  inviteCodesCol,
  membersCol,
  gratitudesCol,
  sosRequestsCol,
  heatmapEntriesCol,
  milestonesCol,
  metaDoc,
  Timestamp,
} from '../lib/firestore';
import { sendPushToUsers } from '../lib/fcm';

// ── Constants ─────────────────────────────────────────────────────────────────

const MAX_CIRCLE_MEMBERS = 10_000;
const GIVING_DAY_THRESHOLDS = [100, 500, 1_000, 2_500, 5_000];
const HOUR_THRESHOLDS = [10, 100, 500, 1_000];
const GRATITUDE_DAY_THRESHOLDS = [100, 500, 1_000];

function generateInviteCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 8; i++) code += chars[Math.floor(Math.random() * chars.length)];
  return code;
}

// ── circleCreate ──────────────────────────────────────────────────────────────

export const circleCreate = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const { name, description = '' } = request.data as { name: string; description?: string };
    if (!name?.trim()) throw new HttpsError('invalid-argument', 'Name is required');

    const uid = request.auth.uid;
    const displayName = (request.auth.token.name as string | undefined) ?? undefined;
    const circleId = crypto.randomUUID();
    const inviteCode = generateInviteCode();

    const batch = db.batch();
    batch.set(circlesCol().doc(circleId), {
      id: circleId, name: name.trim(), description,
      creatorId: uid, inviteCode, memberCount: 1, createdAt: Timestamp.now(),
    });
    batch.set(inviteCodesCol().doc(inviteCode), {
      circleId, circleName: name.trim(), createdAt: Timestamp.now(),
    });
    batch.set(membersCol(circleId).doc(uid), {
      userId: uid, role: 'admin', joinedAt: Timestamp.now(), sosContactIds: [],
      ...(displayName ? { displayName } : {}),
    });
    await batch.commit();

    return { id: circleId, name: name.trim(), inviteCode };
  }
);

// ── circleJoin ────────────────────────────────────────────────────────────────

export const circleJoin = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const { inviteCode } = request.data as { inviteCode: string };
    const code = inviteCode?.toUpperCase();
    if (!code) throw new HttpsError('invalid-argument', 'Invite code required');

    const uid = request.auth.uid;
    const displayName = (request.auth.token.name as string | undefined) ?? undefined;
    const codeSnap = await inviteCodesCol().doc(code).get();
    if (!codeSnap.exists) {
      throw new HttpsError('not-found', 'No prayer circle found with that invite code');
    }

    const circleId = codeSnap.data()!.circleId as string;
    const [circleSnap, memberSnap] = await Promise.all([
      circlesCol().doc(circleId).get(),
      membersCol(circleId).doc(uid).get(),
    ]);

    if (!circleSnap.exists) throw new HttpsError('not-found', 'Circle no longer exists');
    const circle = circleSnap.data()!;

    if (memberSnap.exists) {
      return { id: circleId, name: circle.name as string, alreadyMember: true };
    }

    if ((circle.memberCount as number) >= MAX_CIRCLE_MEMBERS) {
      throw new HttpsError('resource-exhausted', 'This prayer circle has reached its maximum capacity');
    }

    const batch = db.batch();
    batch.set(membersCol(circleId).doc(uid), {
      userId: uid, role: 'member', joinedAt: Timestamp.now(), sosContactIds: [],
      ...(displayName ? { displayName } : {}),
    });
    batch.update(circlesCol().doc(circleId), { memberCount: FieldValue.increment(1) });
    await batch.commit();

    // Notify all admins that a new member joined (best-effort)
    const membersSnap = await membersCol(circleId).where('role', '==', 'admin').get();
    const adminIds = membersSnap.docs
      .map((d) => d.data()['userId'] as string)
      .filter((id) => id !== uid);
    if (adminIds.length > 0) {
      const joinerDoc = await db.collection('users').doc(uid).get();
      const joinerName = (joinerDoc.data()?.['displayName'] as string | undefined) ?? 'Someone';
      sendPushToUsers(adminIds, {
        title: circle.name as string,
        body: `${joinerName} joined the circle`,
        data: { type: 'circle_member_joined', circleId },
        channelId: 'circles',
      }).catch(() => { /* non-fatal */ });
    }

    return { id: circleId, name: circle.name as string, alreadyMember: false };
  }
);

// ── circleLeave ───────────────────────────────────────────────────────────────

export const circleLeave = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const { circleId } = request.data as { circleId: string };
    if (!circleId) throw new HttpsError('invalid-argument', 'circleId required');

    const uid = request.auth.uid;
    const batch = db.batch();
    batch.delete(membersCol(circleId).doc(uid));
    batch.update(circlesCol().doc(circleId), { memberCount: FieldValue.increment(-1) });
    await batch.commit();

    return { success: true };
  }
);

// ── circleSendSOS ─────────────────────────────────────────────────────────────

export const circleSendSOS = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const { circleId, message, recipientIds } = request.data as {
      circleId: string; message: string; recipientIds: string[];
    };
    if (!circleId || !message) throw new HttpsError('invalid-argument', 'circleId and message required');

    const uid = request.auth.uid;
    const memberSnap = await membersCol(circleId).doc(uid).get();
    if (!memberSnap.exists) throw new HttpsError('permission-denied', 'Not a member of this circle');

    const sosRef = sosRequestsCol(circleId).doc();
    await sosRef.set({
      id: sosRef.id, senderId: uid, circleId, message,
      recipientIds: recipientIds ?? [], createdAt: Timestamp.now(),
    });

    // Send push notifications (best-effort — failure does not block the SOS)
    if (recipientIds?.length > 0) {
      const preview = message.length > 80 ? message.substring(0, 80) + '…' : message;
      sendPushToUsers(recipientIds, {
        title: 'SOS Prayer Request',
        body: preview,
        data: { type: 'sos', circleId },
      }).catch(() => { /* non-fatal */ });
    }

    return { success: true };
  }
);

// ── circleShareGratitude ──────────────────────────────────────────────────────

export const circleShareGratitude = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const { circleIds, gratitudeText, isAnonymous, displayName } = request.data as {
      circleIds: string[]; gratitudeText: string; isAnonymous: boolean; displayName?: string;
    };
    if (!circleIds?.length || !gratitudeText) {
      throw new HttpsError('invalid-argument', 'circleIds and gratitudeText required');
    }

    const uid = request.auth.uid;
    const batch = db.batch();

    for (const circleId of circleIds) {
      const ref = gratitudesCol(circleId).doc();
      batch.set(ref, {
        id: ref.id, userId: uid, gratitudeText,
        isAnonymous, displayName: isAnonymous ? null : (displayName ?? null),
        sharedAt: Timestamp.now(), deleted: false,
      });
    }
    await batch.commit();

    // Update gratitude milestone counters (best-effort)
    for (const circleId of circleIds) {
      _incrementGratitudeMilestones(circleId).catch(() => { /* non-fatal */ });
    }

    return { success: true };
  }
);

// ── circleDeleteGratitude ─────────────────────────────────────────────────────

export const circleDeleteGratitude = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const { circleId, gratitudeId } = request.data as { circleId: string; gratitudeId: string };
    if (!circleId || !gratitudeId) throw new HttpsError('invalid-argument', 'circleId and gratitudeId required');

    const uid = request.auth.uid;
    const ref = gratitudesCol(circleId).doc(gratitudeId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError('not-found', 'Gratitude not found');
    if (snap.data()!.userId !== uid) throw new HttpsError('permission-denied', 'Not your gratitude');

    await ref.update({ deleted: true });
    return { success: true };
  }
);

// ── circleSubmitHeatmapData ───────────────────────────────────────────────────

export const circleSubmitHeatmapData = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const { circleId, weekData } = request.data as {
      circleId: string;
      weekData: Array<{ date: string; score: number }>;
    };
    if (!circleId || !weekData) throw new HttpsError('invalid-argument', 'circleId and weekData required');

    const uid = request.auth.uid;
    const memberSnap = await membersCol(circleId).doc(uid).get();
    if (!memberSnap.exists) throw new HttpsError('permission-denied', 'Not a member of this circle');

    await heatmapEntriesCol(circleId).doc(uid).set({
      userId: uid, circleId, weekData, submittedAt: Timestamp.now(),
    });

    await db.runTransaction(async (tx) => {
      const totalsRef = metaDoc(circleId);
      const totalsSnap = await tx.get(totalsRef);
      const prev = totalsSnap.data() ?? { totalGivingDays: 0, totalHours: 0, totalGratitudeDays: 0 };

      const newStrongDays = weekData.filter((d) => d.score >= 0.5).length;
      const newHours = weekData.reduce((sum, d) => sum + (d.score >= 0.5 ? d.score : 0), 0);

      const next = {
        totalGivingDays: (prev.totalGivingDays as number) + newStrongDays,
        totalHours: (prev.totalHours as number) + newHours,
        totalGratitudeDays: prev.totalGratitudeDays as number,
        lastUpdated: Timestamp.now(),
      };
      tx.set(totalsRef, next);

      for (const threshold of GIVING_DAY_THRESHOLDS) {
        if ((prev.totalGivingDays as number) < threshold && next.totalGivingDays >= threshold) {
          tx.set(milestonesCol(circleId).doc(`givingDays_${threshold}`), {
            id: `givingDays_${threshold}`,
            title: `${threshold} Giving Days Together`,
            message: `Your circle has shared ${threshold} strong days together. That's faithfulness at scale.`,
            metric: 'givingDays', threshold, achievedAt: Timestamp.now(),
          });
        }
      }

      for (const threshold of HOUR_THRESHOLDS) {
        if ((prev.totalHours as number) < threshold && next.totalHours >= threshold) {
          tx.set(milestonesCol(circleId).doc(`hours_${threshold}`), {
            id: `hours_${threshold}`,
            title: `${threshold} Hours Together`,
            message: `Together your circle has given ${threshold} hours to God.`,
            metric: 'hours', threshold, achievedAt: Timestamp.now(),
          });
        }
      }
    });

    return { success: true };
  }
);

// ── circleUpdateMemberRole ────────────────────────────────────────────────────

export const circleUpdateMemberRole = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');

    const { circleId, targetUserId, role } = request.data as {
      circleId: string;
      targetUserId: string;
      role: 'admin' | 'member';
    };

    if (!circleId?.trim()) throw new HttpsError('invalid-argument', 'circleId required');
    if (!targetUserId?.trim()) throw new HttpsError('invalid-argument', 'targetUserId required');
    if (!['admin', 'member'].includes(role)) throw new HttpsError('invalid-argument', 'role must be admin or member');

    const uid = request.auth.uid;
    if (uid === targetUserId) throw new HttpsError('invalid-argument', 'You cannot change your own role');

    // Verify caller is admin.
    const callerSnap = await membersCol(circleId).doc(uid).get();
    if (!callerSnap.exists || callerSnap.data()!['role'] !== 'admin') {
      throw new HttpsError('permission-denied', 'Only admins can change member roles');
    }

    // Verify target is a member.
    const targetSnap = await membersCol(circleId).doc(targetUserId).get();
    if (!targetSnap.exists) throw new HttpsError('not-found', 'Member not found in this circle');

    await membersCol(circleId).doc(targetUserId).update({ role });

    return { success: true };
  }
);

// ── circleUpdate ──────────────────────────────────────────────────────────────

export const circleUpdate = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');

    const { circleId, name, description } = request.data as {
      circleId: string;
      name?: string;
      description?: string;
    };

    if (!circleId?.trim()) throw new HttpsError('invalid-argument', 'circleId required');

    const uid = request.auth.uid;
    const memberSnap = await membersCol(circleId).doc(uid).get();
    if (!memberSnap.exists) throw new HttpsError('permission-denied', 'Not a member of this circle');
    if (memberSnap.data()!['role'] !== 'admin') {
      throw new HttpsError('permission-denied', 'Only admins can edit circle details');
    }

    const updates: Record<string, unknown> = {};
    if (name !== undefined) {
      const trimmed = name.trim();
      if (!trimmed) throw new HttpsError('invalid-argument', 'Name cannot be empty');
      updates['name'] = trimmed;
      // Keep invite code index in sync
      const circleSnap = await circlesCol().doc(circleId).get();
      const inviteCode = circleSnap.data()?.['inviteCode'] as string | undefined;
      if (inviteCode) {
        await inviteCodesCol().doc(inviteCode).update({ circleName: trimmed });
      }
    }
    if (description !== undefined) updates['description'] = description;

    if (Object.keys(updates).length === 0) return { success: true };

    await circlesCol().doc(circleId).update(updates);
    return { success: true };
  }
);

// ── circleDelete ──────────────────────────────────────────────────────────────

export const circleDelete = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');

    const { circleId } = request.data as { circleId: string };
    if (!circleId?.trim()) throw new HttpsError('invalid-argument', 'circleId required');

    const uid = request.auth.uid;
    const memberSnap = await membersCol(circleId).doc(uid).get();
    if (!memberSnap.exists) throw new HttpsError('permission-denied', 'Not a member of this circle');
    if (memberSnap.data()!['role'] !== 'admin') {
      throw new HttpsError('permission-denied', 'Only admins can delete a circle');
    }

    // Remove invite code index first so no one can join mid-delete
    const circleSnap = await circlesCol().doc(circleId).get();
    const inviteCode = circleSnap.data()?.['inviteCode'] as string | undefined;
    if (inviteCode) {
      await inviteCodesCol().doc(inviteCode).delete();
    }

    // Recursively delete the entire circle document tree
    await db.recursiveDelete(circlesCol().doc(circleId));

    return { success: true };
  }
);

// ── Internal helpers ──────────────────────────────────────────────────────────

async function _incrementGratitudeMilestones(circleId: string): Promise<void> {
  await db.runTransaction(async (tx) => {
    const totalsRef = metaDoc(circleId);
    const snap = await tx.get(totalsRef);
    const prev = snap.data() ?? { totalGivingDays: 0, totalHours: 0, totalGratitudeDays: 0 };
    const newTotal = (prev.totalGratitudeDays as number) + 1;

    tx.set(totalsRef, { ...prev, totalGratitudeDays: newTotal, lastUpdated: Timestamp.now() });

    for (const threshold of GRATITUDE_DAY_THRESHOLDS) {
      if ((prev.totalGratitudeDays as number) < threshold && newTotal >= threshold) {
        tx.set(milestonesCol(circleId).doc(`gratitudeDays_${threshold}`), {
          id: `gratitudeDays_${threshold}`,
          title: `${threshold} Days of Gratitude Together`,
          message: `Your circle has given thanks together ${threshold} times. Let the peace of God guard your hearts.`,
          metric: 'gratitudeDays', threshold, achievedAt: Timestamp.now(),
        });
      }
    }
  });
}
