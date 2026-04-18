import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/onboarding/onboarding_screen.dart';
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
import '../widgets/loading_spinner.dart';
import '../theme/app_colors.dart';

// Shell scaffold with bottom nav
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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding/login',
    debugLogDiagnostics: false,
    routes: [
      // Auth / Onboarding stack
      GoRoute(
        path: '/onboarding/login',
        builder: (context, state) => const OnboardingScreen(step: OnboardingStep.login),
      ),
      GoRoute(
        path: '/onboarding/leetcode',
        builder: (context, state) => const OnboardingScreen(step: OnboardingStep.leetcode),
      ),
      GoRoute(
        path: '/onboarding/concepts',
        builder: (context, state) => const OnboardingScreen(step: OnboardingStep.concepts),
      ),

      // Main shell with bottom nav
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

      // Top-level screens pushed over main stack
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
        child: Text('Page not found: ${state.uri}',
            style: const TextStyle(color: AppColors.textPrimary)),
      ),
    ),
  );
});
