import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/timetable_screen.dart';
import '../../features/students/screens/student_list_screen.dart';
import '../../features/students/screens/add_student_screen.dart';
import '../../features/staff/screens/staff_screen.dart';
import '../../features/staff/screens/add_staff_screen.dart';
import '../../features/staff/screens/staff_attendance_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/attendance/screens/attendance_detail_screen.dart';
import '../../features/cameras/screens/camera_list_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/splash/screens/splash_screen.dart';
import '../services/auth_service.dart';

// Router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isSplash = state.uri.toString() == '/splash';
      final isLogin = state.uri.toString() == '/login';

      if (!isAuthenticated && !isLogin && !isSplash) return '/login';
      if (isAuthenticated && (isLogin || isSplash)) return '/dashboard';
      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Login
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Timetable (outside shell — full screen)
      GoRoute(
        path: '/admin/timetable',
        name: 'timetable',
        builder: (context, state) => const TimetableScreen(),
      ),

      // Staff routes (outside shell for cleaner full screen)
      GoRoute(
        path: '/staff/add',
        name: 'add-staff',
        builder: (context, state) => const AddStaffScreen(),
      ),
      GoRoute(
        path: '/staff/:staffId/attendance',
        name: 'staff-attendance',
        builder: (context, state) {
          final staffId = int.parse(state.pathParameters['staffId']!);
          return StaffAttendanceScreen(staffId: staffId);
        },
      ),

      // Student add/edit routes (outside shell)
      GoRoute(
        path: '/students/add',
        name: 'add-student',
        builder: (context, state) => const AddStudentScreen(),
      ),
      GoRoute(
        path: '/students/edit/:studentId',
        name: 'edit-student',
        builder: (context, state) {
          final studentId = int.parse(state.pathParameters['studentId']!);
          return AddStudentScreen(studentId: studentId);
        },
      ),

      // Main Shell with Bottom Navigation
      ShellRoute(
        builder: (context, state, child) => MainNavigationScreen(child: child),
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),

          // Students list
          GoRoute(
            path: '/students',
            name: 'students',
            builder: (context, state) => const StudentListScreen(),
          ),

          // Staff list
          GoRoute(
            path: '/staff',
            name: 'staff',
            builder: (context, state) => const StaffScreen(),
          ),

          // Attendance
          GoRoute(
            path: '/attendance',
            name: 'attendance',
            builder: (context, state) => const AttendanceScreen(),
            routes: [
              GoRoute(
                path: 'detail/:date',
                name: 'attendance-detail',
                builder: (context, state) {
                  final date = state.pathParameters['date']!;
                  return AttendanceDetailScreen(date: date);
                },
              ),
            ],
          ),

          // Profile
          GoRoute(
            path: '/profile',
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),

          // Iris Scan
          GoRoute(
            path: '/iris-scan',
            name: 'iris-scan',
            builder: (context, state) => const IrisScanScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
});

// ─────────────────────────────────────────────
// Bottom Navigation Shell
// ─────────────────────────────────────────────

class MainNavigationScreen extends ConsumerStatefulWidget {
  final Widget child;
  const MainNavigationScreen({super.key, required this.child});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  final List<_NavItem> _items = const [
    _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard',
        route: '/dashboard'),
    _NavItem(
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        label: 'Students',
        route: '/students'),
    _NavItem(
        icon: Icons.remove_red_eye_outlined,
        activeIcon: Icons.remove_red_eye,
        label: 'Scan Iris',
        route: '/iris-scan'),
    _NavItem(
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check,
        label: 'Attendance',
        route: '/attendance'),
    _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
        route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    int currentIndex =
        _items.indexWhere((item) => currentRoute.startsWith(item.route));
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => context.go(_items[index].route),
        destinations: _items
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.activeIcon),
                  label: item.label,
                ))
            .toList(),
        height: 65,
      ),
    );
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label, route;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      required this.route});
}

// Error screen
class _ErrorScreen extends StatelessWidget {
  final Object? error;
  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error?.toString() ?? 'Unknown error',
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
