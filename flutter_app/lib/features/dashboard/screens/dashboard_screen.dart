import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_widget.dart' as custom;
import '../widgets/stats_card.dart';
import '../widgets/recent_attendance_widget.dart';
import '../widgets/quick_actions_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with RefreshIndicatorHandler {
  late Future<DashboardStats> _dashboardStatsFuture;
  late Future<List<AttendanceRecord>> _recentAttendanceFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final apiService = ref.read(apiServiceProvider);

    _dashboardStatsFuture = apiService.getDashboardStats();
    _recentAttendanceFuture = apiService.getTodayAttendance().then(
          (list) => list
              .map((e) => AttendanceRecord.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Message
              Consumer(
                builder: (context, ref, child) {
                  final authService = ref.watch(authServiceProvider);
                  return FutureBuilder<String?>(
                    future: authService.username,
                    builder: (context, snapshot) {
                      final username = snapshot.data ?? 'Admin';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, $username!',
                            style: AppTheme.headingMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Here\'s what\'s happening today',
                            style: AppTheme.bodyMedium.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),

              // Stats Cards
              FutureBuilder<DashboardStats>(
                future: _dashboardStatsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 200,
                      child: Center(child: LoadingIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return custom.ErrorWidget(
                      error: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final stats = snapshot.data!;
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatsCard(
                              title: 'Total Students',
                              value: stats.totalStudents.toString(),
                              icon: Icons.people,
                              color: AppTheme.primaryColor,
                              onTap: () => context.go('/students'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatsCard(
                              title: 'Present Today',
                              value: stats.totalAttendanceToday.toString(),
                              icon: Icons.check_circle,
                              color: AppTheme.successColor,
                              onTap: () => context.go('/attendance'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: StatsCard(
                              title: 'Admin Users',
                              value: stats.totalAdmins.toString(),
                              icon: Icons.admin_panel_settings,
                              color: AppTheme.warningColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatsCard(
                              title: 'Cameras',
                              value: stats.totalCameras.toString(),
                              icon: Icons.camera_alt,
                              color: AppTheme.accentColor,
                              onTap: () => context.go('/cameras'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Quick Actions
              const QuickActionsWidget(),

              const SizedBox(height: 24),

              // Recent Attendance
              Text(
                'Recent Attendance',
                style: AppTheme.headingSmall,
              ),
              const SizedBox(height: 16),

              FutureBuilder<List<AttendanceRecord>>(
                future: _recentAttendanceFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 300,
                      child: Center(child: LoadingIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return custom.ErrorWidget(
                      error: snapshot.error.toString(),
                      onRetry: _refresh,
                    );
                  }

                  final attendance = snapshot.data!;

                  if (attendance.isEmpty) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No attendance recorded today',
                              style: AppTheme.bodyMedium.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RecentAttendanceWidget(attendance: attendance);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final authService = ref.read(authServiceProvider);
              await authService.logout();
              if (mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// Mixin for refresh indicator
mixin RefreshIndicatorHandler on ConsumerState<DashboardScreen> {
  Future<void> _refresh() async {
    // Implementation in the class using this mixin
  }
}
