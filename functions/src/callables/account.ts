import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as functionsV1 from 'firebase-functions/v1';
import { FieldValue } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { db, auth } from '../lib/admin';

// ── purgeUserData ─────────────────────────────────────────────────────────────
//
// Removes every Firestore + Storage artefact belonging to a user. Safe to call
// when the user no longer exists in Firebase Auth (cleanup-on-delete) or before
// deleting the Auth user (deleteAccount callable). Idempotent — calling twice
// is a no-op on the second run.
async function purgeUserData(uid: string): Promise<void> {
  // 1. Remove user from all circles they belong to.
  const memberSnap = await db.collectionGroup('members')
    .where('userId', '==', uid)
    .get();

  if (!memberSnap.empty) {
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

  // 3. Recursively delete users/{uid} and every subcollection.
  await db.recursiveDelete(db.collection('users').doc(uid));

  // 4. Delete all journal media from Storage.
  try {
    await getStorage().bucket().deleteFiles({ prefix: `journal/${uid}/` });
  } catch (_) {
    // No files exist or bucket not configured — safe to ignore.
  }
}

// ── deleteAccount (callable) ─────────────────────────────────────────────────
//
// Permanent self-service account deletion. The client invokes this; we wipe
// every Firestore/Storage artefact then delete the Firebase Auth account.
// The client should call signOut() locally after this returns.

export const deleteAccount = onCall(
  { region: 'us-central1' },
  async (request) => {
    if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in required');
    const uid = request.auth.uid;

    await purgeUserData(uid);

    // Delete the Firebase Auth account. Admin SDK does not require recent
    // re-authentication.
    await auth.deleteUser(uid);
  }
);

// ── onAuthUserDeleted (Auth onDelete trigger) ────────────────────────────────
//
// Fires whenever a Firebase Auth user is deleted via *any* path — Firebase
// Console, Admin SDK, Identity Toolkit API, or our own deleteAccount callable.
// Ensures the orphaned Firestore + Storage data is cleaned up so a future
// sign-in with the same email never inherits a stale `users/{oldUid}` doc.
//
// (Firebase Functions v2 has no `onUserDeleted` trigger yet, so we use the
// still-supported v1 import. v1 auth triggers coexist with v2 functions.)

export const onAuthUserDeleted = functionsV1
  .region('us-central1')
  .auth.user()
  .onDelete(async (user) => {
    await purgeUserData(user.uid);
  });
