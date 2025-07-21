import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';
import '../utils/logger.dart';
import '../widgets/calendar_heatmap.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int? _totalDuration;
  List<CalendarHeatmapData> _dailyDurations = [];
  bool _loadingDuration = true;
  bool _previousLoginState = false;

  @override
  void initState() {
    super.initState();
    // Don't load data here - wait for user to be logged in
  }

  Future<void> _loadUserDuration() async {
    AppLogger.info('📊 Starting to load user duration data...');

    // Check token status first
    final accessToken = await TokenManager.getAccessToken();
    final refreshToken = await TokenManager.getRefreshToken();
    AppLogger.info(
      '🔐 Current access token: ${accessToken != null ? "EXISTS" : "NULL"}',
    );
    AppLogger.info(
      '🔐 Current refresh token: ${refreshToken != null ? "EXISTS" : "NULL"}',
    );

    if (accessToken != null) {
      AppLogger.info(
        '🕒 Token expires soon: ${await TokenManager.isTokenExpiringSoon()}',
      );
    }

    try {
      final apiService = ApiService();
      AppLogger.info('🔄 Calling getUserDuration API...');

      final response = await apiService.getUserDuration();
      AppLogger.info('✅ API response received: $response');

      if (mounted) {
        setState(() {
          _totalDuration = response['totalDuration'] as int?;
          AppLogger.info('📈 Total duration: $_totalDuration seconds');

          _loadingDuration = false;

          // Convert duration data to calendar format
          final dailyDurations =
              response['dailyDurations'] as Map<String, dynamic>?;
          AppLogger.info('📅 Daily durations data: $dailyDurations');

          if (dailyDurations != null) {
            _dailyDurations = dailyDurations.entries.map((entry) {
              final date = DateTime.fromMillisecondsSinceEpoch(
                int.parse(entry.key),
              );
              final value = entry.value as int;
              AppLogger.info('📊 Processing date: $date, value: $value');
              return CalendarHeatmapData(date: date, value: value);
            }).toList();

            AppLogger.info(
              '🗓️ Total heatmap data points: ${_dailyDurations.length}',
            );
          } else {
            AppLogger.warning('⚠️ No daily durations data received');
            _dailyDurations = [];
          }
        });
      }
    } catch (e) {
      AppLogger.error('❌ Failed to load user duration: $e');
      if (mounted) {
        setState(() {
          _loadingDuration = false;
          _totalDuration = 0; // Set to 0 instead of null for display
          _dailyDurations = [];
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info('ProfileScreen build called');
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          AppLogger.info(
            'AuthProvider state: isLoading=${authProvider.isLoading}, isLoggedIn=${authProvider.isLoggedIn}',
          );

          // Check if user just logged in
          if (authProvider.isLoggedIn && !_previousLoginState) {
            AppLogger.info('User just logged in, loading duration data...');
            _previousLoginState = true;
            // Load data when user logs in
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadUserDuration();
            });
          } else if (!authProvider.isLoggedIn && _previousLoginState) {
            // User logged out, reset state
            AppLogger.info('User logged out, resetting data...');
            _previousLoginState = false;
            _totalDuration = null;
            _dailyDurations = [];
            _loadingDuration = true;
          }

          if (authProvider.isLoading) {
            AppLogger.info('Showing loading indicator');
            return const Center(child: CircularProgressIndicator());
          }

          if (!authProvider.isLoggedIn || authProvider.currentUser == null) {
            AppLogger.info('User not logged in, showing login view');
            return _buildNotLoggedInView(context, authProvider);
          }

          AppLogger.info('User logged in, showing profile view');
          final user = authProvider.currentUser!;
          return _buildUserProfileView(context, user, authProvider);
        },
      ),
    );
  }

  Widget _buildNotLoggedInView(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade900, Colors.purple.shade800],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 80,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to Dictation Studio',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in to access your personalized learning dashboard',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue.shade900,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileView(
    BuildContext context,
    user,
    AuthProvider authProvider,
  ) {
    AppLogger.info('Building user profile view for user: ${user.username}');

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header with gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue.shade600, Colors.purple.shade600],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // User Avatar
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: user.avatar.isNotEmpty
                            ? NetworkImage(user.avatar)
                            : null,
                        child: user.avatar.isEmpty
                            ? Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white.withOpacity(0.8),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // User Name and Role
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user.username,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Info Cards Grid
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Info Cards
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // First row - Email and Plan
                      Row(
                        children: [
                          Expanded(
                            child: _buildSimpleInfoItem(
                              'Email',
                              user.email,
                              Icons.email_outlined,
                              Colors.blue,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade200,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          Expanded(
                            child: _buildSimpleInfoItem(
                              'Plan',
                              user.plan.name,
                              Icons.workspace_premium_outlined,
                              Colors.amber,
                            ),
                          ),
                        ],
                      ),

                      Divider(height: 32, color: Colors.grey.shade200),

                      // Second row - Expires and Total Time
                      Row(
                        children: [
                          Expanded(
                            child: _buildSimpleInfoItem(
                              'Expires',
                              user.plan.expireTime != null
                                  ? DateFormat('MMM dd, yyyy').format(
                                      DateTime.fromMillisecondsSinceEpoch(
                                        user.plan.expireTime!,
                                      ),
                                    )
                                  : 'No Limit',
                              Icons.schedule_outlined,
                              Colors.purple,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade200,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          Expanded(
                            child: _buildSimpleInfoItem(
                              'Total Time',
                              () {
                                AppLogger.info(
                                  '🎯 UI Display - _loadingDuration: $_loadingDuration',
                                );
                                AppLogger.info(
                                  '🎯 UI Display - _totalDuration: $_totalDuration',
                                );
                                if (_loadingDuration) {
                                  return 'Loading...';
                                } else if (_totalDuration != null) {
                                  final formatted = _formatDuration(
                                    _totalDuration!,
                                  );
                                  AppLogger.info(
                                    '🎯 UI Display - formatted duration: $formatted',
                                  );
                                  return formatted;
                                } else {
                                  AppLogger.info(
                                    '🎯 UI Display - showing default 00:00:00',
                                  );
                                  return '00:00:00';
                                }
                              }(),
                              Icons.timer_outlined,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Calendar Heatmap
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Dictation Activities',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_loadingDuration)
                          const Center(child: CircularProgressIndicator())
                        else
                          CalendarHeatmap.withDefaults(
                            data: _dailyDurations,
                            cellSize: 8,
                            spacing: 2,
                            baseColor: Colors.green.shade600,
                            emptyColor: Colors.grey.shade300,
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Logout Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: authProvider.isLoading
                        ? null
                        : () async {
                            await authProvider.logout();
                          },
                    icon: authProvider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.logout),
                    label: Text(
                      authProvider.isLoading ? 'Signing Out...' : 'Sign Out',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInfoItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
