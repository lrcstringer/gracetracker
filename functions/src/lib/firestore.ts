import { db } from './admin';
import { Timestamp } from 'firebase-admin/firestore';

// ── Existing ──────────────────────────────────────────────────────────────────
export const usersCol = () => db.collection('users');
export const inviteCodesCol = () => db.collection('inviteCodes');
export const circlesCol = () => db.collection('circles');
export const membersCol = (circleId: string) => db.collection(`circles/${circleId}/members`);
export const gratitudesCol = (circleId: string) => db.collection(`circles/${circleId}/gratitudes`);
export const sosRequestsCol = (circleId: string) => db.collection(`circles/${circleId}/sosRequests`);
export const partnershipsCol = () => db.collection('accountability_partnerships');
export const partnerMessagesCol = (partnershipId: string) =>
  db.collection(`accountability_partnerships/${partnershipId}/partner_messages`);
export const heatmapEntriesCol = (circleId: string) => db.collection(`circles/${circleId}/heatmapEntries`);
export const milestonesCol = (circleId: string) => db.collection(`circles/${circleId}/milestones`);
export const metaDoc = (circleId: string) => db.doc(`circles/${circleId}/meta/totals`);
export const userSeenGratitudeDoc = (circleId: string, userId: string) =>
  db.doc(`circles/${circleId}/userSeenGratitude/${userId}`);
export const sosContactsDoc = (circleId: string, userId: string) =>
  db.doc(`circles/${circleId}/sosContacts/${userId}`);

// ── Feature sub-collections ───────────────────────────────────────────────────
export const prayerRequestsCol = (circleId: string) =>
  db.collection(`circles/${circleId}/prayer_requests`);
export const scriptureFocusCol = (circleId: string) =>
  db.collection(`circles/${circleId}/scripture_focus`);
export const reflectionsCol = (circleId: string, weekId: string) =>
  db.collection(`circles/${circleId}/scripture_focus/${weekId}/reflections`);
export const circleHabitsCol = (circleId: string) =>
  db.collection(`circles/${circleId}/circle_habits`);
export const habitCompletionsCol = (circleId: string, habitId: string) =>
  db.collection(`circles/${circleId}/circle_habits/${habitId}/completions`);
export const habitDailySummaryCol = (circleId: string, habitId: string) =>
  db.collection(`circles/${circleId}/circle_habits/${habitId}/daily_summary`);
export const encouragementsCol = (circleId: string) =>
  db.collection(`circles/${circleId}/encouragements`);
export const milestoneSharesCol = (circleId: string) =>
  db.collection(`circles/${circleId}/milestone_shares`);
export const weeklyPulseCol = (circleId: string) =>
  db.collection(`circles/${circleId}/weekly_pulse`);
export const pulseResponsesCol = (circleId: string, weekId: string) =>
  db.collection(`circles/${circleId}/weekly_pulse/${weekId}/responses`);
export const eventsCol = (circleId: string) =>
  db.collection(`circles/${circleId}/events`);
export const circleHabitMilestonesCol = (circleId: string) =>
  db.collection(`circles/${circleId}/circle_habit_milestones`);

// ── User notifications ────────────────────────────────────────────────────────
export const userNotificationsCol = (uid: string) =>
  db.collection(`users/${uid}/notifications`);

// ── Week ID helper (Sun-based, YYYY-WW, matches Dart WeekIdService) ───────────
export function weekId(dt: Date = new Date()): string {
  const day = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate());
  const daysSinceSunday = day.getDay(); // 0=Sun
  const sunday = new Date(day.getTime() - daysSinceSunday * 86_400_000);
  const jan1 = new Date(sunday.getFullYear(), 0, 1);
  const dayOfYear = Math.floor((sunday.getTime() - jan1.getTime()) / 86_400_000);
  const weekNum = Math.floor(dayOfYear / 7);
  return `${sunday.getFullYear()}-${String(weekNum).padStart(2, '0')}`;
}

export function weekStart(dt: Date = new Date()): Date {
  const day = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate());
  const daysSinceSunday = day.getDay();
  return new Date(day.getTime() - daysSinceSunday * 86_400_000);
}

export function dateStr(dt: Date = new Date()): string {
  const y = dt.getFullYear();
  const m = String(dt.getMonth() + 1).padStart(2, '0');
  const d = String(dt.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export { Timestamp, db };
