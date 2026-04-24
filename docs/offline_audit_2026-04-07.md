# GraceWay — Offline Capabilities Audit
**Date:** 2026-04-07  
**Scope:** Full codebase — data layer, providers, presentation layer, services  
**Purpose:** Identify what works offline, what doesn't, and what is needed to achieve full offline capability (where legally/technically possible)

---

## INFRASTRUCTURE: What's Already in Place

Before detailing gaps, the following offline infrastructure already exists and is working:

| Infrastructure | Status | Details |
|---|---|---|
| Firestore offline persistence | ✅ Enabled | `persistenceEnabled: true`, `cacheSizeBytes: CACHE_SIZE_UNLIMITED` (`main.dart:76-79`) |
| Media upload queue | ✅ Robust | `MediaUploadService` — SharedPrefs-persisted queue, retries on reconnect, survives app restart |
| Notification action queue | ✅ Implemented | `PendingActionQueueService` — queues notification response actions (pray/im_here), retries on reconnect |
| Notification send queue | ✅ Implemented | `PendingNotificationSendQueue` — queues outbound sends (SOS, encouragement, announcements, prayer requests as notifications), SharedPrefs-persisted, retries on reconnect |
| User preferences cache | ✅ Sync cache | `FirestoreUserPreferencesRepository` — reads from SharedPreferences, writes to both |
| Bible data | ✅ Fully local | SQLite DB (`bible_web.db`), 31,102 WEB verses, built from asset on first launch |
| Auth state persistence | ✅ Persisted | Firebase Auth keychain/keystore + SharedPreferences profile cache |
| FCM offline fix | ✅ Done | `getToken()` is fire-and-forget; no longer blocks startup (`main.dart:92`) |
| Encryption | ✅ Local | AES-256 encryption/decryption is pure local computation |
| Sign-in offline banner | ✅ Done | Orange banner + settings link; sign-in button disabled offline (`sign_in_screen.dart:39-48`) |
| Journal offline read/write | ✅ Done | Stream-based (`watchEntries()`), fire-and-forget writes, Firestore queues offline |
| BibleProject offline guard | ✅ Done | `openOrPrompt()` static method — dialog offering settings or local Bible fallback |
| Video offline UX | ✅ Done | `_hasError` flag in video cards; shows "unavailable offline" state |
| Scripture threads | ✅ Stream | Uses `.snapshots()`, direct Firestore writes — works offline |

---

## FEATURE-BY-FEATURE OFFLINE STATUS

### ✅ FULLY OFFLINE (No action needed)

| Feature | Why |
|---|---|
| **Bible reading** | Local SQLite, no network calls at any point |
| **Progress view** | All calculations from cached provider data |
| **Today view** | Reads from HabitProvider (cached) |
| **Habit viewing & check-in** | HabitProvider reads from Firestore cache; writes queue via Firestore offline persistence |
| **Journal read/write** | Stream from Firestore cache; fire-and-forget writes queue locally |
| **User preferences** | Synchronous reads from SharedPreferences |
| **Notifications (read)** | `.snapshots()` stream — serves from cache |
| **Kingdom Life text screens** | All static content/assets (Parables, I Am Sayings, Women of Valor, etc.) |
| **Fruit feature** | All static/asset content; habit creation queues locally |
| **Scripture threads** | Direct Firestore writes + stream — queues and serves from cache |
| **Circle habit completions** | Direct Firestore `.set()` — queues locally |
| **Bookmarks** | `.snapshots()` stream + fire-and-forget writes |
| **Pending invite codes** | SharedPreferences only |

---

### ⚠️ PARTIALLY OFFLINE (Works with degradation or gaps)

---

#### 1. Journal Entry Image Display
**Gap:** Images are displayed via `Image.network(url)` (`journal_entry_detail_view.dart:443, 458`). Once a journal entry's images have been uploaded to Firebase Storage, viewing them offline shows a broken image icon. The `errorBuilder` handles the failure (shows `Icons.broken_image_outlined`) but this is poor UX.

**Root cause:** No image caching library is in use. Flutter's `Image.network` does not cache to disk.

**Fix:** Add `cached_network_image` package. Replace `Image.network(url)` calls with `CachedNetworkImage(imageUrl: url, ...)`. Images are then cached to disk on first load and served locally thereafter.

**Effort:** Low. One package addition + ~5 call sites in `journal_entry_detail_view.dart`.

**Note:** Images uploaded but not yet viewed will still require network on first load (unavoidable).

---

#### 2. Journal Voice Note Playback
**Gap:** After a voice note is uploaded to Firebase Storage, its URL is a network URL played via `UrlSource(entry.voiceUrl!)` (`journal_entry_detail_view.dart:110`). Playback fails offline once the local temp file has been cleared after successful upload.

**Root cause:** `MediaUploadService` deletes local staged files after successful upload (`media_upload_service.dart:225`). The entry then only has the Storage URL. No local copy is retained.

**Behaviour before upload:** Plays from local staged path — works offline. After upload: network-only.

**Fix:** After upload, keep a copy of the voice file in the app documents directory (e.g., `journal/{entryId}/voice_cache.m4a`). When `voiceUrl` is set, check for local cache file first; fall back to network URL if absent.

**Effort:** Medium. Requires changes to `MediaUploadService` (retain file) and audio playback logic (local-first).

---

#### 3. Android Speech-to-Text (Voice Dictation)
**Gap:** iOS uses `SFSpeechRecognizer` (fully offline). Android uses Google's speech recognition API which requires a network connection. When offline on Android, `_speech.listen()` either silently fails or returns an error with no UI feedback (`journal_entry_composer.dart:155-180`).

**Root cause:** `speech_to_text` package delegates to the platform. No offline detection before enabling the mic button.

**Fix:** On Android, detect connectivity before allowing dictation start. If offline, show a `SnackBar`: "Voice dictation requires an internet connection on Android." The mic button could also show a visual indicator.

**Effort:** Low. One connectivity check in `_toggleDictation()`.

---

#### 4. Habit Writes: User Feedback During Offline Queue
**Gap:** Habit writes (`insertHabit`, `updateHabit`, `upsertEntry`) use `await` on Firestore operations (`firestore_habit_repository.dart:75,83,105`). With offline persistence enabled, Firestore returns immediately from the local cache, but the `await` resolves quickly and then the write is queued. This actually works fine in practice, but if a transactional operation fails its local execution, the error is silently caught in `HabitProvider` (`catch (_) {}`).

**Specific concern — `upsertEntry` transaction:** Uses `runTransaction()` (`firestore_habit_repository.dart:105`). The transaction already uses `FieldValue.increment()` for aggregate fields (lines 120-123), but the overall operation is still wrapped in a transaction because it also reads the existing entry to compute deltas.

Firestore transactions have stricter offline semantics than simple writes: a transaction performs a read inside its body (`tx.get(entryRef)` at line 106). If that document is NOT in the local cache (e.g., a new day's entry that has never been fetched), the transaction will fail offline rather than queueing.

For entries that HAVE been loaded previously (within the last 28 days, which is the fetch window in `loadHabits()`), the document exists in cache and the transaction should work. Edge case: first check-in of the day (entry doc doesn't exist yet) — the `tx.get()` returns non-existent but cached, so this is actually fine.

**Risk level:** Low in practice. Most check-ins involve documents already in cache.

**Root cause:** Transaction semantics require a read before write; offline read of non-cached doc fails.

**Fix:** Replace transaction with two separate fire-and-forget writes: (1) `set()` the entry doc directly, (2) `update()` the habit doc with `FieldValue.increment()`. Remove the read-compute-delta pattern; instead pass the delta from the caller. Since Firestore local cache handles both writes, this is fully offline-safe.

**Effort:** Medium. Requires rethinking how the caller computes previous completion state to calculate delta.

---

#### 5. Circle Provider State Leak on Sign-Out
**Gap:** Circle-related providers (`CircleEventsProvider`, `CircleHabitsProvider`, `PrayerListProvider`, `GroupPrayerListProvider`, `EncouragementProvider`, `MilestoneShareProvider`, `WeeklyPulseProvider`) do **not** clear their state when the user signs out. Data from the previous user session remains in memory.

**Root cause:** None of these providers have an `_onAuthChanged` listener. They use per-circle loading guards (Map-based) that persist across auth changes.

**Risk:** On a shared/family device, user A's circle data may briefly appear when user B signs in. Also increases memory usage for multi-circle users who sign out.

**Fix:** Add `AuthService.shared.addListener(_onAuthChanged)` to each circle provider. On sign-out, call `_clearAll()` (clear all maps, lists, error state, loading flags).

**Effort:** Low-Medium. Boilerplate change across ~7 providers.

---

#### 6. ~~Weekly Pulse: Optimistic State Without Rollback~~ — NOT A GAP (VERIFIED)
**Status:** ✅ Code is correct. `WeeklyPulseProvider.submit()` places the optimistic update **inside** the `try` block, after `await _repo.submitPulseResponse()` (`weekly_pulse_provider.dart:64-112`). If the server call throws, execution jumps to `catch` — the optimistic state is never applied. No fix needed.

---

### ❌ NETWORK-REQUIRED (Cannot function offline; some have acceptable reasons, others need queuing)

---

#### 7. Circle Write Operations via Cloud Functions
**Gap:** All major circle write operations go through Firebase Cloud Callable Functions (`firestore_circle_repository.dart:95` — `_call()` helper). Callable functions make an HTTPS request and **fail immediately** when offline with no queuing.

**Affected operations:**

| Operation | Mechanism | Offline Status |
|---|---|---|
| Send SOS | `_sendQueue.enqueue()` → `PendingNotificationSendQueue` | ✅ **Already queued** |
| Send encouragement | `_sendQueue.enqueue()` → `PendingNotificationSendQueue` | ✅ **Already queued** |
| Create circle | `_call('circleCreate')` | ❌ Fails offline |
| Join circle | `_call('circleJoin')` | ❌ Fails offline |
| Leave circle | `_call('circleLeave')` | ❌ Fails offline |
| Share gratitude | `_call('circleShareGratitude')` | ❌ Fails offline |
| Delete gratitude | `_call('circleDeleteGratitude')` | ❌ Fails offline |
| Respond to gratitude | `_call('circleGratitudeResponse')` | ❌ Fails offline |
| Create prayer request | `_call('prayerRequestCreate')` | ❌ Fails offline |
| Pray for request | `_call('prayerPrayFor')` | ❌ Fails offline (has optimistic update) |
| Mark prayer answered | `_call('prayerRequestMarkAnswered')` | ❌ Fails offline |
| Create circle event | `_call('circleCreateEvent')` | ❌ Fails offline |
| Update circle event | `_call('circleUpdateEvent')` | ❌ Fails offline |
| Delete circle event | `_call('circleDeleteEvent')` | ❌ Fails offline |
| Create circle habit | `_call('circleHabitCreate')` | ❌ Fails offline |
| Delete circle habit | `_call('circleHabitDelete')` | ❌ Fails offline |
| Share milestone | `_call('milestoneShare')` | ❌ Fails offline |
| Celebrate milestone | `_call('milestoneCelebrate')` | ❌ Fails offline (has optimistic update) |
| Submit weekly pulse | `_call('weeklyPulseRespond')` | ❌ Fails offline |
| Mark encouragement read | `_call('circleMarkEncouragementRead')` | ❌ Fails offline |

**Root cause:** Using Cloud Functions centralises server-side logic (server-side validation, push notifications on write, etc.) but makes all writes network-synchronous.

**Note:** SOS and encouragement are already offline-queued via `PendingNotificationSendQueue` — no action needed for those.

**Fix options for remaining callable operations:**

**Option A — Show clear offline error with retry** (Minimal effort, improves UX) — RECOMMENDED
- Catch `FirebaseFunctionsException` or check connectivity before calling
- Show targeted message: "This action requires an internet connection."
- User retries when online. Appropriate for social interactions (gratitude, prayer requests, etc.) where stale queued data has reduced value

**Option B — Full offline queue for all callable functions** (High effort, Backlog)
- Generic `CallableFunctionQueue` in SharedPreferences
- Queues `{functionName, payload, timestamp}` entries  
- Flushes on reconnect
- Risk: Some functions have server-side preconditions (circle must exist before joining, etc.) — ordering matters
- This is Gap P3-B

---

#### 8. Embedded BibleProject Videos
**Gap:** Two screens embed streaming videos from Mux CDN:
- Beatitudes view: `https://stream.mux.com/83STGVxtcO01902cUvy...` (`beatitudes_view.dart:334`)
- How to Pray view: `https://stream.mux.com/Ok02b3DgDhHj1pqIXld...` (`how_to_pray_view.dart:265`)

Both now have `_hasError` state and show an offline UI (`_buildOffline()`) when `VideoPlayerController.initialize()` fails. The current offline state shows an icon but the UX could be improved.

**Constraint:** BibleProject Terms of Service prohibit local storage/caching of their video content. No download solution is permissible.

**Current state:** `_hasError = true` → `_buildOffline()` renders. Verified actual content: black container + `Icons.wifi_off_rounded` (30% opacity) + text "Video unavailable offline" (45% opacity). No link or action.

**Gap remaining:** 
1. No link to BibleProject online — user has no way to navigate there from the error state
2. No textual fallback for the teaching content (e.g., a brief original-writing summary of the Beatitudes / Lord's Prayer topic — not BibleProject IP)

**Fix:** 
1. Add a "Watch online" `TextButton` inside `_buildOffline()` that calls `BibleProjectBrowserView.openOrPrompt(context)` — this handles the offline guard and falls back to local Bible if still offline
2. Add a static text outline below the video card as fallback content (optional, Medium effort)

**Effort:** Low for UX polish; Medium if adding text fallbacks.

---

#### 9. Circle Detail: First-Load Offline Failure
**Gap:** `circle_detail_view.dart` loads circle data via direct Firestore calls (`getCircleDetail`, `getCircleHeatmap`, `getCircleMilestones` at lines 90, 100, 110). On **first ever load** of a circle with no prior cache, these fail offline with a generic "Failed to load" error.

After first successful online load, Firestore's local cache serves these on subsequent offline visits. But a user who installs the app offline and navigates to circles will see errors.

**Root cause:** Circle detail uses `Future<>` fetches (`.get()`), not streams. The generic error handler (`lines 87-95`) shows a non-specific error.

**Fix:**
1. **Short-term:** Add connectivity check to error handler — show "You're offline. Connect to load circle data." with a settings link
2. **Medium-term:** Convert circle detail reads to `.snapshots()` streams (same pattern as journal), so cached data is served immediately offline

**Effort:** Low for error message improvement; Medium for stream conversion.

---

#### 10. Prayer List & Group Prayer: Write Operations Block Offline
**Gap:** `PrayerListProvider` and `GroupPrayerListProvider` use `await` on callable function writes with no fallback. If offline:
- Creating a prayer request: blocks, eventually throws, user sees generic error
- Answering a prayer: blocks, eventually throws (but `prayForRequest` has optimistic update — correct)
- Group prayer list CRUD: all block and throw

**Fix:** Connectivity check before attempting write → clear offline message → no data lost (action attempted when back online at user's discretion).

**Effort:** Low.

---

#### 11. Events Tab: Write Operations Block Offline
**Gap:** `CircleEventsProvider.createEvent()` and `updateEvent()` (`circle_events_provider.dart:51-88`) await repo calls with no offline fallback. The event management form will submit and then show an error.

**Fix:** Same as prayer list — connectivity check + clear message.

**Effort:** Low.

---

#### 12. Push Notifications: Cold-Start Delivery
**Gap:** If a user receives a push notification while offline and taps it to open the app, the notification action (deep link) is queued in `PendingActionQueueService`. However, some notification actions (e.g., navigating to a specific circle) may try to load data that is only available online.

**Status:** This is partially handled. The queue service retries API calls. Deep link navigation may still fail if the target screen hasn't been cached.

**Fix:** Navigation targets should check connectivity and show appropriate loading state with retry. Lower priority.

---

## WHAT CANNOT BE MADE OFFLINE (Acceptable Constraints)

| Feature | Why it can't be offline | Notes |
|---|---|---|
| **Initial sign-in** | Firebase Auth requires network for first authentication | Correct — session persists once signed in |
| **BibleProject video streaming** | BibleProject ToS prohibits local caching | Error state shown; can't offer download |
| **Circle invites (deep link + join)** | Server must validate and grant membership | Queuing possible but high complexity |
| **In-app purchases** | Store validation requires network | StoreKit/Play Billing requirement |
| **FCM push token registration** | FCM service requires network | Fire-and-forget; `onTokenRefresh` handles eventual delivery |
| **Circle creation/join/leave** | Admin setup + member management requires server-side Cloud Function | Could be queued but complex precondition ordering |
| **Social media sharing** | External systems require network | Out of scope |
| **SOS sending** | ✅ Already offline-queued via `PendingNotificationSendQueue` — NOT a constraint | Included here for completeness |
| **Encouragement sending** | ✅ Already offline-queued via `PendingNotificationSendQueue` — NOT a constraint | Included here for completeness |

---

## PRIORITISED GAPS SUMMARY

### Priority 1 — High Impact, Low Effort (Do Soon)

| # | Gap | Files | Effort |
|---|---|---|---|
| P1-A | Journal image display — add `cached_network_image` | `journal_entry_detail_view.dart`, `pubspec.yaml` | Low |
| P1-B | Circle offline error messages (not generic "Failed") | `circle_detail_view.dart`, `prayer_list_tab.dart`, `events_tab.dart` | Low |
| P1-C | Android speech-to-text: show offline message | `journal_entry_composer.dart` | Low |
| ~~P1-D~~ | ~~Weekly pulse optimistic rollback~~ | ~~`weekly_pulse_provider.dart`~~ | ~~RESOLVED — not a bug~~ |
| ~~P1-E~~ | ~~SOS offline queue~~ | ~~already implemented via `PendingNotificationSendQueue`~~ | ~~RESOLVED~~ |

### Priority 2 — Medium Impact, Medium Effort (Plan for Next Sprint)

| # | Gap | Files | Effort |
|---|---|---|---|
| P2-A | Circle provider sign-out state leak | All 7 circle providers | Low-Medium |
| P2-B | Circle detail stream conversion (`.get()` → `.snapshots()`) | `firestore_circle_repository.dart`, `circle_detail_view.dart` | Medium |
| P2-C | Video offline UX polish (text fallback/link) | `beatitudes_view.dart`, `how_to_pray_view.dart` | Low-Medium |
| P2-D | Circle write operations — connectivity guard + user message | All circle providers | Medium |
| P2-E | Habit `upsertEntry` — replace transaction with `FieldValue.increment()` | `firestore_habit_repository.dart` | Medium |

### Priority 3 — Lower Impact or Higher Effort (Backlog)

| # | Gap | Files | Effort |
|---|---|---|---|
| P3-A | Journal voice note local cache retention | `media_upload_service.dart`, `journal_entry_detail_view.dart` | Medium |
| P3-B | Generic callable function offline queue | New service + all circle providers | High |
| P3-C | Deep-link navigation offline handling | Notification handling code | Medium |

---

## FILES REQUIRING CHANGES (Grouped by Priority)

**Priority 1:**
- `lib/presentation/views/journal/journal_entry_detail_view.dart` — image caching
- `lib/presentation/views/circles/circle_detail_view.dart` — offline error messaging
- `lib/presentation/views/circles/prayer_list_tab.dart` — offline error messaging
- `lib/presentation/views/circles/events_tab.dart` — offline error messaging
- `lib/presentation/views/journal/journal_entry_composer.dart` — Android STT offline check
- `pubspec.yaml` — add `cached_network_image`

**Priority 2:**
- `lib/data/repositories/firestore_circle_repository.dart` — stream conversions for circle detail reads
- `lib/presentation/providers/circle_events_provider.dart` — state leak + connectivity guard
- `lib/presentation/providers/circle_habits_provider.dart` — state leak + connectivity guard
- `lib/presentation/providers/prayer_list_provider.dart` — state leak + connectivity guard
- `lib/presentation/providers/group_prayer_list_provider.dart` — state leak + connectivity guard
- `lib/presentation/providers/encouragement_provider.dart` — state leak
- `lib/presentation/providers/milestone_share_provider.dart` — state leak
- `lib/data/repositories/firestore_habit_repository.dart` — transaction → increment
- `lib/presentation/views/kingdom_life/beatitudes_view.dart` — offline UX polish
- `lib/presentation/views/kingdom_life/how_to_pray_view.dart` — offline UX polish

**Priority 3:**
- `lib/data/services/media_upload_service.dart` — voice note cache retention
- New: `lib/data/services/callable_function_queue_service.dart` (if P3-B approved)

---

## VERIFICATION / TESTING APPROACH

For each fix, test against this matrix:

| Test | Method |
|---|---|
| Start app offline (fresh install) | Enable airplane mode before first launch |
| Start app offline (returning user) | Sign in online, close app, enable airplane mode, relaunch |
| Go offline mid-session | Sign in online, navigate to feature, enable airplane mode, attempt action |
| Restore connectivity | While offline, re-enable wifi; confirm queued operations fire |
| Sign out / sign in different account | Confirm no data leaks from first account in providers |
| Image display offline | View journal entries with images while offline |
| Voice dictation offline (Android) | Enable airplane mode, open journal composer, tap mic |

---

## DOCUMENT SAVE LOCATION

This document should be saved as:
`docs/offline_audit_2026-04-07.md`

And referenced in `memory/MEMORY.md`.
