# CLAUDE.md

This file guides Claude Code (and other AI assistants) when working in this repository.

## What this app is

`ctet_tet_prep` — a Flutter + Supabase mobile app for prepping Indian students for the
**CTET (Central Teacher Eligibility Test)** and State TET exams. It's a from-scratch
rewrite of the PHP "Study-App" tool (in `AdnanKhanAligYT/Study-App`), built to actually
ship on the Google Play Store with real student accounts — **not** an edit of that PHP
code. Android package: `com.adnankhanaligyt.ctet_tet_prep`.

Shipped features: Auth (email/Google/phone), Profile, Mock Test + PYQ (previous year
questions), Syllabus Tracker, Dictionary (spaced-repetition flashcards), Timetable,
Notepad, History of attempts, and local reminder notifications. A video player is
explicitly **not** built yet (deliberate scope cut — see `README.md`).

## Backend architecture

**Supabase (Postgres + Auth + Row Level Security) is the primary backend.** The app
was originally built on Firebase, then migrated off it because Firestore required
linking Google Cloud billing even on the free tier. Firebase makes one narrow return:
**Mobile OTP** uses Firebase Phone Auth purely to verify a phone number, then bridges
that verification into a real Supabase account via the `firebase-phone-bridge` Edge
Function. Everything else (data, email login, Google login, storage) is Supabase-only.

- `supabase/schema.sql` — full DB schema + RLS policies (tables: `profiles`,
  `questions`, `question_progress`, `dictionary_words`, `dictionary_progress`,
  `syllabus_topics`, `syllabus_progress`, `timetable_blocks`, `notes`, `attempts`,
  `exams`, `test_sets`, `test_set_questions`).
- `supabase/migration_*.sql` — incremental migrations layered on top of `schema.sql`
  (e.g. `migration_mock_test_catalog.sql` added the PYQ/Mock Test catalog tables
  after initial ship — check for a matching migration before assuming a table exists).
- `supabase/functions/` — Deno Edge Functions: `delete-account`, `firebase-phone-bridge`.
- `lib/core/supabase_config.dart` — Supabase URL + publishable key. Committed with
  `REPLACE_ME` placeholders (safe to ship — access is controlled by RLS, not by
  keeping these secret). A real project must fill these in per `README.md` setup steps.

When adding a new table or column, add a new `migration_*.sql` file rather than editing
`schema.sql` in place, so existing deployments can pick up the change incrementally
(follow the existing pattern set by `migration_mock_test_catalog.sql`).

## Project structure

Folder-by-feature under `lib/features/<feature>/`, each split into
clean-architecture-lite layers:
- `data/` — repositories wrapping Supabase table/query access
- `domain/` — plain model classes / enums
- `application/` — Riverpod controllers (state)
- `presentation/screens/` — widgets/screens

Features: `auth`, `dashboard`, `dictionary`, `history`, `mock_test`, `notepad`,
`profile`, `syllabus`, `timetable`.

`lib/core/` — shared code:
- `models/` — shared data classes (`user_profile`, `question`, `exam_node`, `test_set`,
  `test_attempt`, `syllabus_topic`, `dictionary_word`, `review_progress`)
- `routing/` — `app_router.dart` (go_router route table), `go_router_refresh_stream.dart`,
  `route_observer.dart`
- `services/` — `ad_service`, `notification_service`, `push_notification_service`,
  `spaced_repetition_service`, `name_suggestion_service`, `app_settings_repository`
- `theme/` — `app_colors.dart`, `app_theme.dart`
- `widgets/` — shared UI (`app_text_field`, `primary_button`, `confirm_submit_dialog`,
  `load_error`, `network_logo_avatar`)
- `supabase_config.dart` — see above

`lib/main.dart` — entry point; initializes Supabase + Firebase, wraps the app in
`ProviderScope`.

Other top-level dirs: `android/`, `ios/`, `web/` (standard Flutter platform scaffolding),
`assets/` (`icons/`, `fonts/` — Noto Sans bundled locally for offline Devanagari
support, `icon/` launcher icon source), `test/` (unit tests only, `flutter_test`).

## State management: Riverpod

Uses `flutter_riverpod` v3 (`Notifier`/`NotifierProvider`/`StreamProvider` API —
**not** the older `ChangeNotifier`/`StateNotifier` style). `main.dart` wraps the app
in `ProviderScope`; top-level widgets extend `ConsumerWidget`.

Pattern to follow (see `lib/features/auth/application/auth_controller.dart` and
`lib/features/profile/application/profile_controller.dart`):
- A `StreamProvider` wraps a live Supabase stream (e.g. `authStateChangesProvider`
  wraps `onAuthStateChange`; `userProfileProvider` wraps a live Postgres `.stream()`
  query) for read state.
- A `Notifier<T>` subclass (e.g. `AuthController`, `ProfileController`) handles
  writes/actions, kept narrow in scope — auth failures and profile-write failures are
  deliberately modeled as separate controllers rather than one shared error state.

## Routing

`go_router`, centralized in `lib/core/routing/app_router.dart`. Auth-gating uses
explicit `_requiresAuth` / `_bounceWhenLoggedIn` route lists and a `redirect` driven by
`authStateChangesProvider` via `go_router_refresh_stream.dart` — add new protected
routes to the existing lists rather than hand-rolling per-screen auth checks.

## Theming

Single navy brand color (`#16234B`) via `AppTheme.light()` / `AppTheme.dark()`,
defaulting to system light/dark unless overridden by `UserProfile.themePreference`.
Fonts are bundled locally (Noto Sans, not `google_fonts`) so Devanagari text renders
correctly offline.

## Code conventions

This codebase has unusually detailed inline comments explaining **why**, not just
what — preserve that convention when adding non-obvious logic. Keep the
`data/domain/application/presentation` layering per feature rather than mixing
Supabase calls directly into widgets.

## Build / run / test

No Makefile, no CI (no `.github/workflows`), no melos/fvm. Standard Flutter CLI:

```
flutter pub get
flutter run
flutter test                              # covers NameSuggestionService, SpacedRepetitionService
flutter analyze                           # uses flutter_lints via analysis_options.yaml, no custom rules
flutter build appbundle --release         # needs android/key.properties + upload keystore (gitignored)
dart run flutter_launcher_icons           # regenerate app icon (manual, on-demand)
dart run flutter_native_splash:create     # regenerate splash screen (manual, on-demand)
```

Dart SDK constraint: `^3.12.2` (see `pubspec.yaml`). Key dependencies:
`supabase_flutter`, `flutter_riverpod`, `go_router`, `firebase_core`/`firebase_auth`/
`firebase_messaging` (phone OTP + push only), `google_sign_in`, `geolocator`/
`geocoding`, `pinput`, `cached_network_image`, `shared_preferences`,
`flutter_local_notifications` + `timezone`, `google_mobile_ads`, `flutter_svg`.

## Secrets / config

- `lib/core/supabase_config.dart` — committed with placeholders, not gitignored (safe
  by design; RLS is the real access control).
- `android/app/google-services.json` — gitignored, Firebase Phone Auth config, must be
  generated per-project via Firebase console (see `README.md` setup step 5).
- `android/key.properties` + upload keystore `.jks` — gitignored release-signing
  secrets, required only for `flutter build appbundle --release`.
- Edge Function secrets (e.g. `FIREBASE_PROJECT_ID`) are set via
  `npx supabase secrets set ...`, never committed to the repo.

## Git conventions

Commit subjects are short, imperative, plain English — no conventional-commits
prefixes (`feat:`/`fix:`). Often name the feature/module first, e.g. `"Subject Wise
Revision: block picker (CDP 1st/2nd/..., SST in 60s)"`, `"Fix Subject Wise Revision
showing empty despite uploaded questions"`. Occasionally tag with a parenthetical
feature marker, e.g. `(Feature #3)`. Match this style for new commits.

## Docs

`README.md` is the source of truth for one-time Supabase/Firebase project setup
(creating the Supabase project, running `schema.sql`, configuring the Firebase phone
bridge, Play Store signing). Read it before assuming any backend is already configured
for a fresh clone — `supabase_config.dart` ships with `REPLACE_ME` placeholders.
