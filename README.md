# CTET & State TET Prep — Mobile App

Flutter + Firebase rewrite of the Study-App study tool, built to actually
ship on the Google Play Store with real student accounts. This is a fresh
project, not an edit of the PHP code in the rest of this repo. The full
architecture/decisions are written up in the project plan this was built
from (Firebase Auth with Email + Mobile OTP, Firestore data model,
feature-first Flutter structure).

This is **Phase 1** of the phased build: Firebase project foundation, both
auth methods (email and mobile OTP), the email-name auto-suggestion flow,
and the full Edit Profile screen. Mock tests, syllabus tracker, timetable,
dictionary, notifications, etc. are later phases — see the plan for the
full order.

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
5. **Connect this project to your Firebase project** — from inside
   `mobile_app/`:
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

## Running

```
cd mobile_app
flutter pub get
flutter run
```

## Testing

```
flutter test
```

Currently covers `NameSuggestionService` (the email → suggested display
name parser) end to end — this is the piece with the most "logic" in
Phase 1 and the easiest to silently break, so it's unit-tested.

## What's here (Phase 1)

- `lib/features/auth/` — Welcome screen, Email signup/login, Phone
  signup/login + OTP verification, Suggested Name (email flow) / Manual
  Name (phone flow) screens.
- `lib/features/profile/` — Edit Profile screen (first-time setup and
  later edits share the same screen).
- `lib/features/dashboard/` — placeholder Home screen + the routing gate
  that forces an incomplete profile into setup before showing it.
- `lib/core/` — theme (placeholder, real design deferred), routing
  (go_router + auth-state redirect), the `NameSuggestionService`, and the
  `UserProfile` model mapping to the `/users/{uid}` Firestore document.
- `firestore.rules` — per-user data isolation + read-only shared content
  collections.

## What's NOT here yet

Mock tests, syllabus tracker, timetable, dictionary, notepad, history,
video player, push notifications, and the visual design system are all
later phases. The root-level PHP file-manager tool from the rest of this
repo is intentionally excluded from this app entirely — it's a private
dev tool, not something students should ever see.
