# CTET & State TET Prep — Mobile App

Flutter + Firebase rewrite of the Study-App study tool, built to actually
ship on the Google Play Store with real student accounts. This is a fresh
project, not an edit of the PHP code in the rest of this repo. The full
architecture/decisions are written up in the project plan this was built
from (Firebase Auth with Email + Mobile OTP, Firestore data model,
feature-first Flutter structure).

Progress so far: **Phase 1** (Firebase Auth foundation, Edit Profile) and
the start of **Phase 2** (Mock Test + Syllabus Tracker, the app's core
day-to-day study loop) are built. Timetable, dictionary, notepad,
history, video player, and push notifications are later phases — see the
plan for the full order.

## One-time setup (you need to do this — I don't have access to your
## Google/Firebase account)

1. **Create a Firebase project.** Go to https://console.firebase.google.com,
   create a new project (e.g. `ctet-tet-prep`).
2. **Enable Authentication providers.** In the Firebase Console →
   Authentication → Sign-in method, enable:
   - **Email/Password**
   - **Phone** (you'll need to add SHA-1/SHA-256 fingerprints of your
     debug and release keystores under Project Settings → Your apps →
     Android app, once you generate/reserve those keystores)
3. **Enable Cloud Firestore** (Firebase Console → Firestore Database →
   Create database, start in production mode).
4. **Install the FlutterFire CLI** (one-time, on your own machine):
   ```
   dart pub global activate flutterfire_cli
   ```
5. **Connect this project to your Firebase project** — from inside this
   folder:
   ```
   flutterfire configure
   ```
   Pick your Firebase project, select Android (and iOS if you're building
   that too). This **overwrites** `lib/firebase_options.dart` (currently a
   placeholder with dummy `REPLACE_ME` values) with your project's real
   keys, and drops the matching `google-services.json` /
   `GoogleService-Info.plist` into the native project folders.
6. **Deploy the security rules** in `firestore.rules`:
   ```
   firebase deploy --only firestore:rules
   ```
   (requires `firebase login` and a `firebase.json` — running
   `firebase init firestore` in this folder once will create that file and
   point it at `firestore.rules`.)
7. **Seed some content to test with** — Mock Test and Syllabus are both
   empty until you add documents to Firestore yourself (Firebase Console →
   Firestore Database → Start collection):
   - `questions/{autoId}`: `subject`, `topic`, `examTags` (array, e.g.
     `["CTET Paper 1"]`), `text`, `options` (array of strings),
     `correctOptionIndex` (number), `explanations` (array, one string per
     option, same length as `options`)
   - `syllabusTopics/{autoId}`: `exam` (must match one of the strings in
     `lib/core/models/exam_catalog.dart`), `subject`, `unit`, `topicName`,
     `order` (number, controls display order)

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
`SpacedRepetitionService` (the mock-test due-date scheduling) end to
end — the two pieces of pure logic in the app so far, and the easiest to
silently break.

## What's here

- `lib/features/auth/` — Welcome screen, Email signup/login, Phone
  signup/login + OTP verification, Suggested Name (email flow) / Manual
  Name (phone flow) screens.
- `lib/features/profile/` — Edit Profile screen (first-time setup and
  later edits share the same screen).
- `lib/features/mock_test/` — today's due questions in mixed order,
  instant feedback + explanation, locked answers, Submit-anytime/Next —
  matches `take_test.php` from the reference PHP app. Scheduling logic in
  `domain/spaced_repetition_service.dart`.
- `lib/features/syllabus/` — topic list grouped by subject with a
  three-state tap-to-cycle (not started → in progress → done) and an
  overall progress bar.
- `lib/features/dashboard/` — Home screen with quick links to Mock Test
  and Syllabus, a banner ad, and the routing gate that forces an
  incomplete profile into setup before showing it.
- `lib/core/` — theme (navy brand, bundled Noto Sans, **follows the
  phone's system light/dark setting by default** — see
  `AppThemePreference` in `core/models/user_profile.dart`), routing
  (go_router + auth-state redirect), `NameSuggestionService`, `AdService`.
- `firestore.rules` — per-user data isolation + read-only shared content
  collections.

## What's NOT here yet

Timetable, dictionary, notepad, history, video player, and push
notifications are later phases. The root-level PHP file-manager tool from
the rest of the original Study-App repo was never brought over here — it's
a private dev tool, not something students should ever see.
