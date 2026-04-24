# GraceWay — App Overview

**Version:** 2.0.0 | **Bundle ID:** `com.graceway.faith` | **Deep link domain:** `graceway.faith`

---

## What It Is

GraceWay is a faith-based personal habit tracking app built in Flutter (iOS and Android), backed by Firebase. The core premise is that spiritual growth is a *walk* — a daily, disciplined act of faithfulness — and the app gives that walk structure, accountability, and community. Every feature is built around a Christian worldview: habits are acts of offering ("giving to God"), progress is framed in terms of Scripture, and failure is met with grace rather than punishment.

---

## Technical Architecture

**Stack:**
- **Frontend:** Flutter (Dart), targeting iOS and Android
- **Backend:** Firebase — Firestore (database), Firebase Auth (authentication), Cloud Functions v2 (TypeScript, Node.js 22, Hono/tRPC)
- **In-App Purchases:** StoreKit (iOS) / Google Play Billing, with server-side receipt validation
- **Push notifications:** `flutter_local_notifications` for scheduled local notifications; FCM via Cloud Functions for remote push
- **Deep links:** `app_links` package handles `graceway://join?code=XXXX` (custom scheme) and `https://graceway.faith/join?code=XXXX` (HTTPS App Links / Universal Links)

**Architecture:** Clean Architecture — three layers:
- `data/` — Firestore repositories, Cloud Function callables, Firebase Auth service
- `domain/` — Pure Dart entities, repository interfaces, domain services (stateless logic)
- `presentation/` — Flutter views, Providers (state management)

**State management:** Provider pattern throughout. All Providers are registered at the root `MultiProvider` in `main.dart` and consume repository interfaces, keeping views decoupled from Firebase.

**Fonts:** DM Serif Display (headings) + Inter (body) via Google Fonts. Dark theme throughout — charcoal `#1E1E2E` background, warm gold `#D4A843` accent.

---

## Authentication & Onboarding

Sign-in supports **Apple Sign In** and **Google Sign In**. A new user goes through a 14-step animated onboarding sequence:

| Step | Screen | Purpose |
|---|---|---|
| 0 | Welcome | Animated logo reveal with breathing glow effect |
| 1 | Sign In | Apple / Google authentication |
| 2 | Identity | "Who are you becoming?" — user writes a personal identity statement |
| 3 | Reframe | Reframes discipline as an act of worship rather than willpower |
| 4 | First Gratitude | User logs their first gratitude entry immediately |
| 5 | Habit Selection | Choose a habit category |
| 6 | Habit Setup | Configure tracking type, target, schedule, purpose statement, trigger, coping plan |
| 7 | Habit Summary | Confirmation of the first habit |
| 8 | Fruit Intro | Introduction to the Fruit of the Spirit framework |
| 9 | Fruit Tagging | Assign spiritual fruits to the habit |
| 10 | Core Mechanics | Explains how the daily log and week cycle work |
| 11 | Notification Preferences | Set up reminder times |
| 12 | Paywall | Premium subscription offer (skippable) |
| 13 | Dedication Ceremony | Dedicate the week to God; transitions into the main app |

Onboarding completion is persisted to Firestore via `UserPreferencesRepository` so it syncs across devices.

---

## Main Navigation

After onboarding, the app shows a bottom navigation bar with six tabs:

| Tab | Icon | Purpose |
|---|---|---|
| **Give** | 🎁 | Today's habits — the primary daily screen |
| **Week** | 📅 | This week's score and per-habit grid |
| **Journey** | 📊 | Lifetime stats, milestones, heatmap |
| **Fruit** | 🌿 | Fruit of the Spirit portfolio |
| **Circles** | 👥 | Prayer circles (community) — badged when new gratitudes arrive |
| **Settings** | ⚙️ | Account, subscription, notifications |

---

## Core Feature: Personal Habits

### Habit Tracking Types

| Type | How it works | Example |
|---|---|---|
| **Check-in** | Binary — done or not | Daily Gratitude, Fasting |
| **Timed** | Track minutes | Prayer (30 min), Bible reading |
| **Count** | Track a number | Glasses of water, acts of service |
| **Abstain** | Track clean days away from something | Breaking a bad habit |

Each habit has:
- A **category** (Exercise, Scripture & Prayer, Rest, Fasting, Study, Service, Connection, Health, Breaking a Bad Habit, Custom, Gratitude)
- A **purpose statement** ("my why")
- Optional **trigger** and **coping plan** (for abstain habits)
- A **daily target** and **active schedule** (specific days of the week)

**Daily Gratitude** is a special built-in habit that always appears first on the Give tab. It has a text entry field ("What's one thing you're grateful for?") and a "Thank you, Lord" button. After check-in, a Scripture verse appears; the user is then prompted to share their gratitude with their Prayer Circles.

### The Give (Today) Screen

- Shows a personalised greeting ("Good morning, Lance")
- Horizontal **week strip** — tap any day to log retroactively; past days are clearly flagged
- Gratitude card appears first, then all user habits as check-in cards
- Free plan: up to 2 user-added habits; premium: unlimited
- **SOS button** floats bottom-right (premium only — see below)
- Auto-advances date when the day rolls over in the background

### The Week Screen

Displays an overall **week score** (0–100%) and day-tier indicators for the current Sunday-to-Saturday week:

| Tier | Score |
|---|---|
| Nothing | 0% |
| Partial | 1–49% |
| Substantial | 50–94% |
| Full | 95–100% |

Also shows micro-milestone previews ("3 more days to hit your 7-day streak").

### The Journey Screen

Lifetime analytics:
- Total "giving days" (any day at least one habit was completed)
- Total habit check-ins
- Days of gratitude
- Per-habit **milestones** (checkmarks next to reached thresholds)
- **52-week heatmap** (premium) — a GitHub-style activity grid across the full year

### Personal Milestones

Fixed thresholds, auto-detected when a habit is logged:

| Habit type | Thresholds |
|---|---|
| Timed | 1h, 10h, 50h, 100h, 500h, 1,000h |
| Count | 100, 500, 1,000, 5,000 completions |
| Check-in (days) | 7, 30, 100, 365 days |
| Abstain (consecutive) | 7, 14, 30, 60, 90, 180, 365 days |

Each milestone displays a spiritually-worded celebration message and an anchor Scripture verse. Reached milestones can be shared to Prayer Circles.

### SOS — Temptation Support (Premium)

A floating button on the Give screen. Pressing it opens a full-screen view that presents the user's purpose statement, anchor verse, and coping plan — a grounding tool for moments of temptation. Users can also send an SOS alert to selected Prayer Circle members, triggering push notifications to recipients.

---

## Fruit of the Spirit

A distinct layer on top of habit tracking. Each habit is **tagged with one or more of the 9 Fruits of the Spirit** from Galatians 5:22–23:

| Fruit | Greek | Description |
|---|---|---|
| Love | *agapē* | Unconditional love that serves before it feels |
| Joy | *chara* | Delight rooted in God's presence, not circumstances |
| Peace | *eirēnē* | Deep rest and wholeness, even amid uncertainty |
| Patience | *makrothymia* | Enduring grace that doesn't snap under pressure |
| Kindness | *chrēstotēs* | Warmth and goodness expressed in everyday acts |
| Goodness | *agathōsynē* | Doing right because you are being made right |
| Faithfulness | *pistis* | Consistent trust and reliability in small things |
| Gentleness | *prautēs* | Calm strength that doesn't need to force or defend |
| Self-Control | *enkrateia* | The quiet power to choose well |

### The Fruit Portfolio (Fruit Tab)

- How many habits are contributing to each fruit
- Weekly and all-time completions per fruit
- Current and longest streaks per fruit
- A **balance score** — what percentage of the 9 fruits have at least one weekly completion this week
- Neglected fruits (no habits assigned)
- Dominant fruit of the week

Each fruit has a daily check-in prompt ("Did you act out of love today, even when it was hard?") and a completion affirmation ("Love is patient, love is kind.").

The **Fruit Library** lets users explore all 9 fruits and see micro-actions (specific small acts) associated with each. The **weekly portfolio** resets each Sunday via a Cloud Function.

---

## The Week Cycle

GraceWay operates on a **Sunday-to-Saturday cycle**:

- **Sunday Dedication Ceremony** — each new week, the user dedicates their habits to God in a full-screen ceremony. If the user misses Sunday, the app silently auto-carries and shows a quiet banner ("New week, same habits") instead of forcing the ceremony.
- **Week Look-Back** — at the end of the week, the user reviews how they did before the new week begins.

The `WeekCycleManager` tracks `needsLookBack`, `needsDedication`, and `weekDedicatedDate` in `UserPreferences` (synced to Firestore).

---

## Prayer Circles (Community)

The most socially rich part of the app. A **Circle** is a small accountability group — users create or join circles via invite codes, shared as `https://graceway.faith/join?code=XXXX` deep links. Each circle has an **admin** who manages settings and members. The Circles tab shows all the user's circles, badged when new content arrives.

### Circle Detail — Five Tabs

#### 1. Overview Tab
- Circle stats: member count, invite code with share button
- Sunday summary — weekly activity report
- Member list — admins see a `···` menu to promote or demote members (Make Admin / Remove Admin)
- Circle Heatmap — aggregate activity grid for the group (all members' habits combined)
- Collective Milestones — total giving/gratitude days for the circle as a whole

#### 2. Habits Tab (Circle Habits)
Shared habits the whole group tracks together. Each habit has a daily summary card showing the group's completion rate for today. Admin settings control whether the card shows anonymous checkmarks or member names.

- **Create:** Admin sets name, tracking type, frequency (daily / weekly / specific days), anchor verse, purpose statement
- **Complete:** Any member can log their completion for the day
- **Deactivate:** Admin can retire a habit

#### 3. Prayer Tab (Prayer List)
Members post prayer requests to the circle.

- **Create:** Text, duration (this week / ongoing / until removed), optional anonymous posting
- **Pray:** Members tap 🙏 to log their prayer; count increments (idempotent)
- **Answered:** Author can mark a request answered with an optional note
- **Expiry:** "This week" requests expire automatically via a Cloud Function cron

#### 4. Scripture Focus Tab
The admin (or any member, depending on circle settings) sets a weekly Scripture passage for the group. The passage is fetched live from the API.Bible service by reference. Any member can submit a written reflection, and all reflections are visible to the circle.

#### 5. Activity Tab (Three Sub-tabs)

**Encouragements**
Send a preset or custom message to one or more circle members, optionally anonymously.

Preset messages include:
- "Praying for you today."
- "Keep going — you're doing great."
- "God sees your faithfulness."
- "You're not walking alone."
- "Praying God gives you strength today."
- "Just wanted you to know I'm thinking of you."
- "Grateful to be in community with you."

Received encouragements appear in the same tab. Sender identity is controlled server-side — the Cloud Function masks anonymous senders before returning results.

**Milestones**

Two sections, circle milestones first:

*Circle Milestones (auto-generated):*
When the circle's collective completions of a shared habit cross a threshold, a milestone document is automatically created by a Firestore trigger and displayed here. Thresholds: 10, 50, 100, 250, 500, 1,000 completions.
Example: "Your circle hit 100 completions of Morning Prayer!"

*Member Milestones (user-shared):*
Members who hit a personal habit milestone and choose to share it appear here. Other members can tap 🎉 Celebrate. The milestone owner is notified when the 1st, 5th, and 10th celebration is reached.

**Weekly Pulse**
A confidential weekly check-in. Members submit one of four status options:

| Status | Meaning |
|---|---|
| Encouraged | Doing well |
| Steady | Holding on |
| Struggling | Having a hard time |
| Needs Prayer | Please pray for me |

Results are shown as an aggregate summary (admin can enable a named view to see who responded how). Members who submit "Needs Prayer" are quietly flagged in the count. Responses are fetched through a Cloud Function — the client never reads the raw Firestore documents directly.

### Circle Events
Admins create events with a title, date, description, location, and optional meeting link. Events appear in a dedicated Events tab on the circle detail. A Cloud Function cron sends push reminder notifications to all members the day before each event.

### Gratitude Wall
After logging daily gratitude, users are prompted to share it with their circles. Shared posts appear on the circle's Gratitude Wall — a rolling 4-week feed. Posts can be anonymous. A new-gratitude badge appears on the Circles tab nav item when unread posts are waiting.

---

## Premium Subscription

GraceWay uses a freemium model with native in-app purchases (StoreKit on iOS, Google Play Billing on Android), validated server-side.

**Free tier:**
- Up to 2 personal habits
- Basic habit tracking and check-in
- Prayer Circles — all features included

**Premium unlocks:**
- Unlimited habits
- SOS temptation support
- Detailed analytics and insights
- Custom purpose statements
- 52-week Year in GraceWay heatmap
- Smart push notification reminders

**Plans:** Monthly · Annual (default) · Lifetime

The paywall is triggered contextually — e.g., tapping SOS on a free account shows the paywall with a custom message explaining why that specific feature needs premium.

---

## Cloud Functions (Backend)

All sensitive writes go through Firebase Callable Functions. The client never writes directly to protected collections.

| Function | Purpose |
|---|---|
| `circleCreate`, `circleJoin`, `circleLeave` | Circle lifecycle |
| `circleSendSOS` | Sends push notifications to SOS contacts |
| `circleShareGratitude`, `circleDeleteGratitude` | Gratitude wall |
| `circleUpdateSettings`, `circleUpdateMemberRole` | Admin operations |
| `prayerRequestCreate`, `prayerPrayFor`, `prayerRequestMarkAnswered` | Prayer list |
| `expirePrayerRequests` | Cron — expires "this week" prayer requests |
| `circleFetchBiblePassage`, `circleSetScriptureFocus`, `circleSubmitReflection` | Scripture focus |
| `circleCreateHabit`, `circleDeactivateHabit` | Circle habits management |
| `circleCompleteHabitAggregation` | Trigger — updates daily summary on habit completion |
| `circleHabitMilestoneCheck` | Trigger — auto-creates circle milestone docs at completion thresholds |
| `circleSendEncouragement`, `circleGetEncouragements`, `circleMarkEncouragementRead` | Encouragements (privacy-masked) |
| `circleShareMilestone`, `circleCelebrateMilestone`, `batchCelebrationNotifications` | Personal milestone sharing |
| `circleSubmitPulseResponse`, `circleGetPulseResponses` | Weekly pulse |
| `circleCreateEvent`, `circleDeleteEvent`, `sendEventReminders` | Events |
| `validateReceipt`, `appleNotification`, `googleNotification` | IAP and subscription webhooks |
| `resetWeeklyFruitPortfolio` | Cron — resets weekly fruit completion counts every Sunday |
| `sendEncouragementPrompts`, `sendPulsePrompts` | Cron — periodic push reminder prompts |

A Hono HTTP server (`api` function) also exposes a tRPC REST API used for invite link generation.

---

## Firestore Data Model

```
users/{uid}
  habits/{habitId}
    entries/{entryId}
  state/{docId}                     ← UI preferences, synced across devices
  subscription/{docId}              ← server-write only (Admin SDK)
  fruit_portfolio/{fruitId}

inviteCodes/{code}                  ← public read, server write
purchaseTokens/{tokenId}            ← no client access
bible_passage_cache/{cacheKey}      ← authenticated read, server write

circles/{circleId}
  members/{uid}
  gratitudes/{id}
  prayer_requests/{id}
  scripture_focus/{weekId}
    reflections/{id}
  circle_habits/{habitId}
    completions/{id}
    daily_summary/{date}
  circle_habit_milestones/{id}      ← auto-generated, read-only for clients
  encouragements/{id}               ← no direct client read (callable only)
  milestone_shares/{id}
  weekly_pulse/{weekId}
    responses/{uid}                 ← no direct client read (callable only)
  events/{id}
  sosRequests/{id}
  meta/totals
  userSeenGratitude/{uid}
  sosContacts/{uid}
  heatmapEntries/{uid}
  milestones/{id}
```

---

## Key Design Principles

**1. Faith-first language**
The app never says "complete" or "done"; it says "give", "offer", "faithful". Habits are not tasks — they are acts of worship. Completion messages quote Scripture or speak in terms of discipleship.

**2. Grace over gamification**
No streaks that punish missing a day. Retroactive logging (up to 6 days back) is supported without penalty. The week resets cleanly each Sunday. The app acknowledges failure without shame and invites the user back rather than resetting a counter.

**3. Privacy by design**
Anonymous options exist on gratitude posts, prayer requests, encouragements, and pulse responses. Encouragements and pulse responses are always fetched through Cloud Functions — never directly from Firestore — so sender and responder identity is controlled server-side and cannot be reverse-engineered by a determined client.

**4. Community that serves the individual**
Circles are opt-in accountability groups, not a social media feed. Every circle feature is designed to support the individual member's walk — not to create social pressure, performance anxiety, or comparison. The Pulse feature's aggregate-by-default view exemplifies this: the group sees the need without exposing who is struggling.

**5. Offline-tolerant**
The app reads habits from a local Firestore cache. The daily check-in always works with no connectivity; data syncs when the connection returns.

**6. Deterministic week boundaries**
The entire app operates on a consistent Sunday-to-Saturday week. The `WeekIdService` generates a `YYYY-WW` key used across habits, scripture focus, pulse, and milestones — ensuring that every part of the app and backend agree on what "this week" means.
