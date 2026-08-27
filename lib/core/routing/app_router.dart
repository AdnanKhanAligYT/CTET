import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/presentation/screens/email_auth_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/manual_name_screen.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/auth/presentation/screens/phone_auth_screen.dart';
import '../../features/auth/presentation/screens/suggested_name_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/bullet_revision/presentation/screens/bullet_revision_screen.dart';
import '../../features/dashboard/presentation/screens/home_gate.dart';
import '../../features/dictionary/presentation/screens/dictionary_screen.dart';
import '../../features/history/presentation/screens/history_screen.dart';
import '../../features/mock_test/presentation/screens/deep_link_test_open_screen.dart';
import '../../features/mock_test/presentation/screens/exam_list_screen.dart';
import '../../features/mock_test/presentation/screens/mock_test_instructions_screen.dart';
import '../../features/mock_test/presentation/screens/mock_test_result_screen.dart';
import '../../features/mock_test/presentation/screens/mock_test_taking_screen.dart';
import '../../features/mock_test/presentation/screens/named_test_result_screen.dart';
import '../../features/mock_test/presentation/screens/named_test_screen.dart';
import '../../features/mock_test/presentation/screens/paper_list_screen.dart';
import '../../features/mock_test/presentation/screens/subject_block_list_screen.dart';
import '../../features/mock_test/presentation/screens/subject_revision_list_screen.dart';
import '../../features/mock_test/presentation/screens/take_test_screen.dart';
import '../../features/mock_test/presentation/screens/test_set_list_screen.dart';
import '../../features/notepad/presentation/screens/notepad_screen.dart';
import '../../features/notes/presentation/screens/notes_chapter_list_screen.dart';
import '../../features/notes/presentation/screens/notes_content_screen.dart';
import '../../features/notes/presentation/screens/notes_subject_list_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/syllabus/presentation/screens/syllabus_topics_screen.dart';
import '../../features/syllabus/presentation/syllabus_navigation.dart';
import '../../features/timetable/presentation/screens/timetable_screen.dart';
import '../models/exam_node.dart';
import '../models/notes_chapter.dart';
import '../models/test_attempt.dart';
import '../models/test_set.dart';
import 'go_router_refresh_stream.dart';
import 'route_observer.dart';

// Only '/welcome' is bounced away from once logged in — this exists purely
// to skip straight past the welcome screen on a cold start when a session
// is already active. The signup/login/OTP screens deliberately are NOT in
// this list: each of them decides its own next screen on success (e.g.
// email signup -> Suggested Name, phone signup -> Manual Name, login ->
// home), and bouncing them here would race that explicit navigation and
// skip the name-entry step for brand-new users.
const _bounceWhenLoggedIn = ['/welcome'];

// Routes that require a signed-in user; anyone signed out gets sent back
// to Welcome instead.
const _requiresAuth = [
  '/',
  '/profile/edit',
  '/mock-test',
  '/mock-test/open',
  '/mock-test/take',
  '/mock-test/papers',
  '/mock-test/sets',
  '/mock-test/named',
  '/mock-test/named/result',
  '/mock-test/instructions',
  '/mock-test/take-v2',
  '/mock-test/result-v2',
  '/mock-test/subjects',
  '/mock-test/subjects/blocks',
  '/pyq',
  '/syllabus/topics',
  '/dictionary',
  '/timetable',
  '/notepad',
  '/notes',
  '/notes/chapters',
  '/notes/content',
  '/history',
  '/bullet-revision',
];

// Firebase.apps.isNotEmpty is a synchronous, already-initialized check —
// safe here since `appRouter` (a lazily-evaluated top-level final) is
// only ever actually read from App.build(), which runs after main()'s
// Firebase.initializeApp() attempt has already resolved one way or the
// other. Skips the analytics observer entirely rather than crash when
// Firebase isn't set up (same fail-open stance as PushNotificationService).
final _navigatorObservers = <NavigatorObserver>[
  routeObserver,
  if (Firebase.apps.isNotEmpty)
    FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
];

final appRouter = GoRouter(
  initialLocation: '/welcome',
  observers: _navigatorObservers,
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final loggedIn = Supabase.instance.client.auth.currentUser != null;
    final loc = state.matchedLocation;

    if (loggedIn && _bounceWhenLoggedIn.contains(loc)) return '/';
    if (!loggedIn && _requiresAuth.contains(loc)) return '/welcome';
    return null;
  },
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/auth/email',
      builder: (context, state) => EmailAuthScreen(
        isSignUp: state.uri.queryParameters['mode'] != 'login',
      ),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) => const PhoneAuthScreen(),
    ),
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) => const OtpVerifyScreen(),
    ),
    GoRoute(
      path: '/auth/suggested-name',
      builder: (context, state) =>
          SuggestedNameScreen(email: state.uri.queryParameters['email'] ?? ''),
    ),
    GoRoute(
      path: '/auth/manual-name',
      builder: (context, state) => const ManualNameScreen(),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(path: '/', builder: (context, state) => const HomeGate()),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => EditProfileScreen(
        isFirstTimeSetup: state.uri.queryParameters['firstTime'] == 'true',
      ),
    ),
    // ── Mock Test / Previous Year Questions catalog ──
    // Both tiles land on the same ExamListScreen/PaperListScreen/
    // TestSetListScreen chain, distinguished only by `type`.
    GoRoute(
      path: '/mock-test',
      builder: (context, state) =>
          const ExamListScreen(type: TestSetType.mockTest),
    ),
    GoRoute(
      path: '/mock-test/open',
      builder: (context, state) => DeepLinkTestOpenScreen(
        testSetId: state.uri.queryParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/pyq',
      builder: (context, state) => const ExamListScreen(type: TestSetType.pyq),
    ),
    GoRoute(
      path: '/mock-test/papers',
      builder: (context, state) => PaperListScreen(
        parent: state.extra as ExamNode,
        type: TestSetTypeX.fromValue(state.uri.queryParameters['type']),
      ),
    ),
    GoRoute(
      path: '/mock-test/sets',
      builder: (context, state) => TestSetListScreen(
        paper: state.extra as ExamNode,
        type: TestSetTypeX.fromValue(state.uri.queryParameters['type']),
      ),
    ),
    GoRoute(
      path: '/mock-test/named',
      builder: (context, state) =>
          NamedTestScreen(args: state.extra as NamedTestArgs),
    ),
    GoRoute(
      path: '/mock-test/named/result',
      builder: (context, state) =>
          NamedTestResultScreen(attempt: state.extra as TestAttempt),
    ),
    // ── New Mock Test exam-style flow (instructions -> free-navigation
    // taking screen -> result with rank/percentile). PYQ keeps using the
    // '/mock-test/named' flow above, unchanged. ──
    GoRoute(
      path: '/mock-test/instructions',
      builder: (context, state) =>
          MockTestInstructionsScreen(testSet: state.extra as TestSet),
    ),
    GoRoute(
      path: '/mock-test/take-v2',
      builder: (context, state) =>
          MockTestTakingScreen(args: state.extra as MockTestTakingArgs),
    ),
    GoRoute(
      path: '/mock-test/result-v2',
      builder: (context, state) =>
          MockTestResultScreen(args: state.extra as MockTestResultArgs),
    ),
    // ── Daily due-today practice (spaced repetition), and Subject Wise
    // Revision (same screen, `subject`+`block` query params switch the
    // mode — subject list -> block picker -> this) ──
    GoRoute(
      path: '/mock-test/take',
      builder: (context, state) => TakeTestScreen(
        subject: state.uri.queryParameters['subject'],
        block: int.tryParse(state.uri.queryParameters['block'] ?? ''),
      ),
    ),
    GoRoute(
      path: '/mock-test/subjects',
      builder: (context, state) => const SubjectRevisionListScreen(),
    ),
    GoRoute(
      path: '/mock-test/subjects/blocks',
      builder: (context, state) => SubjectBlockListScreen(
        subject: state.uri.queryParameters['subject'] ?? '',
      ),
    ),
    // ── Syllabus ──
    // Reached straight from the Mock Test/PYQ test-set list's "Syllabus"
    // button (same leaf ExamNode, same admin-managed exam/paper tree) —
    // no separate exam/paper picker of its own any more.
    GoRoute(
      path: '/syllabus/topics',
      builder: (context, state) =>
          SyllabusTopicsScreen(args: state.extra as SyllabusTopicsArgs),
    ),
    GoRoute(
      path: '/dictionary',
      builder: (context, state) => const DictionaryScreen(),
    ),
    GoRoute(
      path: '/timetable',
      builder: (context, state) => const TimetableScreen(),
    ),
    GoRoute(
      path: '/notepad',
      builder: (context, state) => const NotepadScreen(),
    ),
    // ── Notes ──
    // Fixed subject list (NotesSubjectListScreen, no fetch) -> admin-added
    // chapters for that subject -> the chapter's own content.
    GoRoute(
      path: '/notes',
      builder: (context, state) => const NotesSubjectListScreen(),
    ),
    GoRoute(
      path: '/notes/chapters',
      builder: (context, state) =>
          NotesChapterListScreen(subject: state.extra as String),
    ),
    GoRoute(
      path: '/notes/content',
      builder: (context, state) =>
          NotesContentScreen(chapter: state.extra as NotesChapter),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/bullet-revision',
      builder: (context, state) => const BulletRevisionScreen(),
    ),
  ],
);
