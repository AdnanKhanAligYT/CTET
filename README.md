# CTET & State TET Prep — Mobile App

Flutter + Supabase rewrite of the Study-App study tool, built to actually
ship on the Google Play Store with real student accounts. This is a fresh
project, not an edit of the PHP code in the rest of this repo.

Progress so far: **Phase 1** (Auth foundation, Edit Profile),
**Phase 2** (Mock Test + Syllabus Tracker), and **Phase 3** (Dictionary,
Timetable, Notepad, History, and local reminder notifications) are all
built. Only a video player is left unbuilt — deliberately, see "What's
NOT here yet" below.

The backend was originally built on Firebase, then migrated to
**Supabase** (Postgres + Auth) because enabling Cloud Firestore required
linking Google Cloud billing even on the free tier — Supabase's free tier
needs no card at all. See "What changed from Firebase" at the bottom if
you're picking this repo up mid-migration.

## One-time setup (you need to do this — I don't have access to your
## Supabase account)

1. **Create a Supabase project.** Go to https://supabase.com, sign up
   (GitHub login works, no card needed), and create a new project (e.g.
   `ctet-tet-prep`). Pick a region close to India if offered.
2. **Run the database schema.** Supabase Dashboard → SQL Editor → New
   query → paste the entire contents of `supabase/schema.sql` from this
   repo → Run. This creates every table (`profiles`, `questions`,
   `question_progress`, `dictionary_words`, `dictionary_progress`,
   `syllabus_topics`, `syllabus_progress`, `timetable_blocks`, `notes`,
   `attempts`) with Row Level Security policies already wired up — no
   separate "deploy rules" step like Firestore needed.
3. **Turn off forced email confirmation** (so email signup lands students
   straight in the app, matching the original non-blocking design):
   Dashboard → Authentication → Sign In / Providers → Email → toggle
   **"Confirm email"** OFF. Leave **Phone** provider's defaults as-is —
   see step 5 for the one thing phone signup still needs.
4. **Copy your API keys.** Dashboard → Project Settings → API Keys →
   copy the **Project URL** and the **Publishable key**. Paste them into
   `lib/core/supabase_config.dart` (currently `REPLACE_ME` placeholders).
   Both are safe to ship in the app — access is controlled by the Row
   Level Security policies from step 2, not by keeping these secret.
5. **Set up an SMS provider for Phone OTP.** Unlike Firebase, Supabase
   doesn't send SMS itself — Dashboard → Authentication → Providers →
   Phone → pick a provider (Twilio, MessageBird, Vonage, or similar) and
   enter its credentials. Every provider needs its own account and
   (unlike Supabase itself) does typically require a card, since sending
   an SMS costs a small amount per message — this is unavoidable for real
   SMS delivery, not specific to Supabase. If you want to test the rest of
   the app first without paying for SMS, you can skip this step for now
   and just use Email signup — Phone signup will error until a provider is
   configured.
6. **Deploy the account-deletion function** (Play Store requires an
   in-app way to delete your account, and only a backend can actually
   delete an `auth.users` row — see `supabase/functions/delete-account`):
   ```
   npx supabase login
   npx supabase link --project-ref <your-project-ref>
   npx supabase functions deploy delete-account
   ```
   No billing needed — Edge Functions have a generous free tier.
7. **Set up Google Sign-In** ("Continue with Google" on the Welcome
   screen — a native account picker, not a browser popup):
   1. Google Cloud Console (console.cloud.google.com) → APIs & Services →
      Credentials → **Create Credentials → OAuth client ID**.
   2. Create a **Web application** client (yes, even though this is an
      Android app — Supabase's Google provider and `google_sign_in`'s
      `serverClientId` both need this one, not an Android-type client).
      Copy its Client ID.
   3. Paste that Client ID into `_googleServerClientId` in
      `lib/features/auth/application/auth_controller.dart` (currently
      `REPLACE_ME.apps.googleusercontent.com`).
   4. Supabase Dashboard → Authentication → Sign In / Providers → Google →
      enable it, paste the same Client ID into "Client IDs".
   5. Create a second OAuth client, type **Android**, with this app's
      package name (`com.adnankhanaligyt.ctet_tet_prep`) and its SHA-1
      fingerprint (get yours with `cd android && ./gradlew signingReport`,
      look for the `debug` variant's SHA1 — you'll need to redo this with
      your release keystore's SHA-1 once you have one for Play Store
      builds).
8. **Seed some content to test with** — Mock Test, Syllabus, and
   Dictionary are all empty until you add rows yourself (Supabase
   Dashboard → Table Editor → pick the table → Insert row, or paste SQL
   `insert into ...` statements into the SQL Editor).
   - `questions`: `subject`, `topic`, `exam_tags` (text array, e.g.
     `{"CTET Paper 1"}`), `text`, `options` (array of strings),
     `correct_option_index` (number), `explanations` (array, one string
     per option, same length as `options`)
   - `syllabus_topics`: `exam` (must match one of the strings in
     `lib/core/models/exam_catalog.dart`), `subject`, `unit`,
     `topic_name`, `order` (number, controls display order)
   - `dictionary_words`: `word`, `meaning_hi`, `meaning_en`,
     `example_sentence` (all strings)

## Reminders

Fully client-side now (`lib/core/services/notification_service.dart`) —
no server, no billing, nothing to deploy. Uses
`flutter_local_notifications`' exact-alarm scheduling instead of a
Firebase Cloud Function + FCM push:
- A daily 8 AM reminder to check due Mock Test/Dictionary reviews.
- A weekly Sunday 7 PM nudge to check History.
- One reminder per Timetable block, 10 minutes before it starts, that
  re-syncs automatically whenever the Timetable screen loads.

## Ads (AdMob)

`lib/core/services/ad_service.dart` wires up a banner ad (dashboard) and
an interstitial (after finishing a mock test) using **Google's public
test Ad Unit IDs** — these render real test ads so you can see the ad
slots working, but earn nothing. To actually earn money:
1. Create an AdMob account at https://apps.admob.com and link it to this
   app (same Google account you'd use for Play Console).
2. Replace the App ID in `android/app/src/main/AndroidManifest.xml`
   (`com.google.android.gms.ads.APPLICATION_ID`) with your real one.
3. Replace `AdUnitIds.banner` / `AdUnitIds.interstitial` in
   `ad_service.dart` with your own ad units' IDs.
4. Google requires a **privacy policy** and (in the EU/UK) a consent
   management flow before real ads go live — both need to be in place
   before Play Store submission regardless of ads, see the project plan's
   Play Store checklist.

## Running

```
flutter pub get
flutter run
```

## Testing

```
flutter test
```

Covers `NameSuggestionService` (email → suggested display name) and
`SpacedRepetitionService` (the due-today review scheduling shared by
Mock Test and Dictionary) end to end — the two pieces of pure logic in
the app so far, and the easiest to silently break.

## What's here

- `lib/features/auth/` — Welcome screen, Email signup/login, Phone
  signup/login + OTP verification, Suggested Name (email flow) / Manual
  Name (phone flow) screens.
- `lib/features/profile/` — Edit Profile screen (first-time setup and
  later edits share the same screen).
- `lib/features/mock_test/` — today's due questions in mixed order,
  instant feedback + explanation, locked answers, Submit-anytime/Next —
  matches `take_test.php` from the reference PHP app.
- `lib/features/syllabus/` — topic list grouped by subject with a
  three-state tap-to-cycle (not started → in progress → done) and an
  overall progress bar.
- `lib/features/dictionary/` — same due-today review loop as Mock Test,
  flashcard-style (word → tap to reveal meaning/example → Know It /
  Don't Know), plus a browsable list of every word.
- `lib/features/timetable/` — personal weekly study schedule: add a
  block (day, start/end time, subject), tick it off, delete it.
- `lib/features/notepad/` — simple notes with an optional pin-to-top.
- `lib/features/history/` — past mock test attempts with date, accuracy,
  and correct/wrong/skipped breakdown.
- `lib/features/dashboard/` — Home screen with quick links to all six
  study tools, a banner ad, and the routing gate that forces an
  incomplete profile into setup before showing it.
- `lib/core/` — theme (navy brand, bundled Noto Sans, **follows the
  phone's system light/dark setting by default** — see
  `AppThemePreference` in `core/models/user_profile.dart`), routing
  (go_router + auth-state redirect), `NameSuggestionService`,
  `SpacedRepetitionService` (shared by Mock Test + Dictionary),
  `AdService`, `NotificationService`.
- `supabase/schema.sql` — every table + Row Level Security policy.
- `supabase/functions/delete-account/` — the one server-side piece this
  app needs (self-service account deletion; see step 6 above).

## What's NOT here yet

**Video player** is the one deliberately unbuilt piece — the reference
PHP app's video features assumed a specific video source (YouTube links
embedded per-topic) that hasn't been decided for this app yet, so there's
no content model to build a player screen against. Everything else from
the original project plan (auth, profile, mock test, syllabus,
dictionary, timetable, notepad, history, reminders) is built.

The root-level PHP file-manager tool from the rest of the original
Study-App repo was never brought over here — it's a private dev tool, not
something students should ever see.

## What changed from Firebase

Started on Firebase Auth + Cloud Firestore + Cloud Functions + FCM;
switched to Supabase because Firestore (even on the free Spark plan)
started requiring a linked Google Cloud billing account just to create
the database. Supabase's free tier needs no card. What that meant
concretely:
- `cloud_firestore` → Postgres tables (`supabase/schema.sql`), queried
  via `supabase_flutter`'s Postgrest client instead of
  `.collection().doc()`.
- `firebase_auth` → Supabase Auth (`GoTrueClient`) — same two sign-in
  methods (Email/Password, Phone OTP), same UX flow.
- Account deletion moved from a direct client-side `user.delete()` call
  to a small Edge Function (`supabase/functions/delete-account`), since
  Supabase (correctly) doesn't let a client app delete its own
  `auth.users` row directly — only a `service_role`-authenticated
  backend can, same as most real auth systems.
- Scheduled Cloud Functions + FCM push → fully local, on-device
  reminders via `flutter_local_notifications`' exact-alarm scheduling
  (see "Reminders" above) — no server, nothing to deploy or pay for.
