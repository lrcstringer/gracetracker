import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { db, auth } from '../lib/admin';

// ── deleteAccount ─────────────────────────────────────────────────────────────
//
// Permanently deletes all data belonging to the authenticated user:
//   • Removes them from every circle (members sub-doc + memberIds array)
//   • Deletes per-uid circle sub-docs (userSeenGratitude, sosContacts, heatmapEntries)
//   • Deletes all accountability partnerships they own or participate in
//   • Deletes user-authored circle content (gratitudes, prayer requests,
//     encouragements, milestone shares, weekly pulse responses)
//   • Deletes IAP reverse-lookup tokens (purchaseTokens)
//   • Recursively deletes users/{uid} and every subcollection
//   • Deletes all Firebase Storage files under journal/{uid}/
//   • Deletes the Firebase Auth account (admin SDK, no re-auth required)
//
// The client should call signOut() locally after this returns.

export const deleteAccount = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const uid = request.auth.uid;

    // Delete all docs in a collectionGroup matching a single field value.
    async function deleteByField(collectionId: string, field: string, value: string): Promise<void> {
      const snap = await db.collectionGroup(collectionId).where(field, '==', value).get();
      if (snap.empty) return;
      for (let i = 0; i < snap.docs.length; i += 500) {
        const batch = db.batch();
        snap.docs.slice(i, i + 500).forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }
    }

    // 1. Remove user from all circles they belong to.
    //    Collect circle IDs before any deletes — needed for per-uid sub-docs below.
    const memberSnap = await db.collectionGroup('members')
      .where('userId', '==', uid)
      .get();

    const circleIds = memberSnap.docs.map((doc) => doc.ref.parent.parent!.id);

    if (!memberSnap.empty) {
      // 2 writes per circle (delete member doc + update circle doc) — cap at 200 per batch.
      for (let i = 0; i < memberSnap.docs.length; i += 200) {
        const batch = db.batch();
        for (const memberDoc of memberSnap.docs.slice(i, i + 200)) {
          const circleRef = memberDoc.ref.parent.parent!;
          batch.delete(memberDoc.ref);
          batch.update(circleRef, {
            memberCount: FieldValue.increment(-1),
            memberIds: FieldValue.arrayRemove(uid),
          });
        }
        await batch.commit();
      }
    }

    // 2. Delete per-uid documents in each circle (document path is keyed by uid).
    //    - userSeenGratitude/{uid}  — seen-state tracking
    //    - sosContacts/{uid}        — emergency contacts (PII)
    //    - heatmapEntries/{uid}     — habit heatmap data (doc ID is uid)
    if (circleIds.length > 0) {
      const perUidRefs = circleIds.flatMap((circleId) => [
        db.doc(`circles/${circleId}/userSeenGratitude/${uid}`),
        db.doc(`circles/${circleId}/sosContacts/${uid}`),
        db.doc(`circles/${circleId}/heatmapEntries/${uid}`),
      ]);
      for (let i = 0; i < perUidRefs.length; i += 500) {
        const batch = db.batch();
        perUidRefs.slice(i, i + 500).forEach((ref) => batch.delete(ref));
        await batch.commit();
      }
    }

    // 3. Delete all accountability partnerships where this user is owner or partner.
    const [ownerSnap, partnerSnap] = await Promise.all([
      db.collection('accountability_partnerships').where('ownerId', '==', uid).get(),
      db.collection('accountability_partnerships').where('partnerId', '==', uid).get(),
    ]);
    await Promise.all([
      ...ownerSnap.docs.map((doc) => db.recursiveDelete(doc.ref)),
      ...partnerSnap.docs.map((doc) => db.recursiveDelete(doc.ref)),
    ]);

    // 4. Delete user-authored content across all circles.
    await Promise.all([
      deleteByField('responses', 'userId', uid),         // circles/.../weekly_pulse/.../responses
      deleteByField('gratitudes', 'userId', uid),        // circles/.../gratitudes
      deleteByField('prayer_requests', 'authorId', uid), // circles/.../prayer_requests
      deleteByField('encouragements', 'senderId', uid),  // circles/.../encouragements
      deleteByField('milestone_shares', 'userId', uid),  // circles/.../milestone_shares
    ]);

    // 5. Delete IAP reverse-lookup tokens (keyed by purchase token, contain uid field).
    const tokenSnap = await db.collection('purchaseTokens').where('uid', '==', uid).get();
    if (!tokenSnap.empty) {
      const batch = db.batch();
      tokenSnap.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    // 6. Recursively delete users/{uid} and every subcollection
    //    (habits, entries, journal, memorizations, bookmarks, notifications, state, etc.).
    await db.recursiveDelete(db.collection('users').doc(uid));

    // 7. Delete all journal media from Storage.
    try {
      await getStorage().bucket().deleteFiles({ prefix: `journal/${uid}/` });
    } catch (_) {
      // No files exist or bucket not configured — safe to ignore.
    }

    // 8. Delete the Firebase Auth account.
    //    Admin SDK does not require recent re-authentication.
    await auth.deleteUser(uid);
  }
);
