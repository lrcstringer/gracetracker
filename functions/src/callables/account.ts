import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { db, auth } from '../lib/admin';

// ── deleteAccount ─────────────────────────────────────────────────────────────
//
// Permanently deletes all data belonging to the authenticated user:
//   • Removes them from every circle (members sub-doc + memberIds array)
//   • Deletes all accountability partnerships they own or participate in
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

    // 1. Remove user from all circles they belong to.
    //    collectionGroup('members') finds all circles/{id}/members/{uid} docs.
    const memberSnap = await db.collectionGroup('members')
      .where('userId', '==', uid)
      .get();

    if (!memberSnap.empty) {
      // 2 writes per circle (delete member doc + update circle doc) — cap at 200 circles per batch.
      const batchSize = 200;
      for (let i = 0; i < memberSnap.docs.length; i += batchSize) {
        const batch = db.batch();
        for (const memberDoc of memberSnap.docs.slice(i, i + batchSize)) {
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

    // 2. Delete all accountability partnerships where this user is owner or partner.
    const [ownerSnap, partnerSnap] = await Promise.all([
      db.collection('accountability_partnerships').where('ownerId', '==', uid).get(),
      db.collection('accountability_partnerships').where('partnerId', '==', uid).get(),
    ]);
    await Promise.all([
      ...ownerSnap.docs.map((doc) => db.recursiveDelete(doc.ref)),
      ...partnerSnap.docs.map((doc) => db.recursiveDelete(doc.ref)),
    ]);

    // 3. Recursively delete users/{uid} and every subcollection
    //    (habits, entries, journal, memorizations, bookmarks, notifications, state, etc.).
    await db.recursiveDelete(db.collection('users').doc(uid));

    // 5. Delete all journal media from Storage.
    try {
      await getStorage().bucket().deleteFiles({ prefix: `journal/${uid}/` });
    } catch (_) {
      // No files exist or bucket not configured — safe to ignore.
    }

    // 6. Delete the Firebase Auth account.
    //    Admin SDK does not require recent re-authentication.
    await auth.deleteUser(uid);
  }
);
