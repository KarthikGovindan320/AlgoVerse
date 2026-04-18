import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/onboarding/login_screen.dart';
import '../../features/onboarding/leetcode_screen.dart';
import '../../features/onboarding/concepts_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/discover/discover_screen.dart';
import '../../features/concept_graph/concept_graph_screen.dart';
import '../../features/problem_detail/problem_detail_screen.dart';
import '../../features/chat_history/chat_history_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/social/social_screen.dart';
import '../../features/jobs/jobs_screen.dart';
import '../theme/app_colors.dart';
import '../../data/repositories/providers.dart';

// ── Bottom nav shell ──────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<String> _routes = [
    '/home',
    '/discover',
    '/concepts',
    '/progress',
    '/social',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            context.go(_routes[index]);
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.hub_outlined),
              activeIcon: Icon(Icons.hub),
              label: 'Concepts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Social',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Auth-aware router notifier ────────────────────────────────────────────────

class _RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  _RouterNotifier(this._ref) {
    // Rebuild router on auth or profile change
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(userProfileProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authAsync = _ref.read(authStateProvider);
    final loc = state.matchedLocation;

    // Still resolving auth state — stay put (splash handles the wait)
    if (authAsync.isLoading) return null;

    final user = authAsync.value;

    // ── Not signed in ────────────────────────────────────────────────────────
    if (user == null) {
      // Allow splash and onboarding routes; block everything else
      if (loc == '/splash' || loc.startsWith('/onboarding')) return null;
      return '/onboarding/login';
    }

    // ── Signed in ────────────────────────────────────────────────────────────
    final profileAsync = _ref.read(userProfileProvider);

    // Profile still loading — allow splash while we wait
    if (profileAsync.isLoading) {
      return loc == '/splash' ? null : '/splash';
    }

    final profile = profileAsync.value;
    if (profile == null) {
      // Profile doc doesn't exist yet (first sign-in race) — wait on splash
      return loc == '/splash' ? null : '/splash';
    }

    final isComplete = profile['onboardingComplete'] == true;

    if (!isComplete) {
      // Resume from where the user left off
      final step = (profile['onboardingStep'] ?? 1) as int;
      if (loc.startsWith('/onboarding') || loc == '/splash') return null;
      if (step <= 1) return '/onboarding/leetcode';
      if (step == 2) return '/onboarding/concepts';
      return '/onboarding/leetcode';
    }

    // Fully onboarded — redirect away from auth flow
    if (loc == '/splash' || loc.startsWith('/onboarding')) return '/home';
    return null;
  }
}

// ── Router provider ───────────────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    debugLogDiagnostics: false,
    routes: [
      // ── Splash ─────────────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Onboarding ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/onboarding/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding/leetcode',
        builder: (context, state) => const LeetCodeScreen(),
      ),
      GoRoute(
        path: '/onboarding/concepts',
        builder: (context, state) => const ConceptsScreen(),
      ),

      // ── Main shell with bottom nav ──────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverScreen(),
          ),
          GoRoute(
            path: '/concepts',
            builder: (context, state) => const ConceptGraphScreen(),
          ),
          GoRoute(
            path: '/progress',
            builder: (context, state) => const ProgressScreen(),
          ),
          GoRoute(
            path: '/social',
            builder: (context, state) => const SocialScreen(),
          ),
          GoRoute(
            path: '/jobs',
            builder: (context, state) => const JobsScreen(),
          ),
        ],
      ),

      // ── Top-level screens ───────────────────────────────────────────────────
      GoRoute(
        path: '/problem/:slug',
        builder: (context, state) => ProblemDetailScreen(
          slug: state.pathParameters['slug']!,
          initialTab: 0,
        ),
      ),
      GoRoute(
        path: '/problem/:slug/chat',
        builder: (context, state) => ProblemDetailScreen(
          slug: state.pathParameters['slug']!,
          initialTab: 1,
        ),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatHistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:username',
        builder: (context, state) => ProfileScreen(
          username: state.pathParameters['username'],
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/duel/:duelId',
        builder: (context, state) => SocialScreen(
          duelId: state.pathParameters['duelId'],
        ),
      ),
      GoRoute(
        path: '/job/:jobId',
        builder: (context, state) => JobsScreen(
          jobId: state.pathParameters['jobId'],
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    ),
  );
});
