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

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  int? _totalDuration;
  List<CalendarHeatmapData> _dailyDurations = [];
  bool _loadingDuration = true;
  bool _previousLoginState = false;
  bool _hasLoadedData = false; // Track if data has been loaded before

  // Keep the state alive when switching tabs
  @override
  bool get wantKeepAlive => true;


  Future<void> _loadUserDuration({bool forceRefresh = false}) async {
    // Only load if we haven't loaded before or if it's a forced refresh
    if (!forceRefresh && _hasLoadedData) {
      AppLogger.info('📊 Data already loaded, skipping...');
      return;
    }

    AppLogger.info('📊 Starting to load user duration data...');

    setState(() {
      _loadingDuration = true;
    });

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
          // Handle both int and double types from API
          final totalDurationValue = response['totalDuration'];
          _totalDuration = totalDurationValue != null 
              ? (totalDurationValue is int ? totalDurationValue : (totalDurationValue as double).toInt())
              : null;
          AppLogger.info('📈 Total duration: $_totalDuration seconds');

          _loadingDuration = false;
          _hasLoadedData = true; // Mark as loaded

          // Convert duration data to calendar format
          final dailyDurations =
              response['dailyDurations'] as Map<String, dynamic>?;
          AppLogger.info('📅 Daily durations data: $dailyDurations');

          if (dailyDurations != null) {
            _dailyDurations = dailyDurations.entries.map((entry) {
              final date = DateTime.fromMillisecondsSinceEpoch(
                int.parse(entry.key),
              );
              // Handle both int and double types from API
              final rawValue = entry.value;
              final value = rawValue is int ? rawValue : (rawValue as double).toInt();
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
          // Don't set _hasLoadedData = true on error, allow retry
        });
      }
    }
  }

  // Manual refresh function for the refresh button
  Future<void> _refreshData() async {
    AppLogger.info('🔄 Manual refresh triggered');
    await _loadUserDuration(forceRefresh: true);
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    AppLogger.info('ProfileScreen build called');
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          AppLogger.info(
            'AuthProvider state: isLoading=${authProvider.isLoading}, isLoggedIn=${authProvider.isLoggedIn}',
          );

          // Check if user just logged in
          if (authProvider.isLoggedIn && !_previousLoginState) {
            AppLogger.info('User just logged in, loading duration data...');
            _previousLoginState = true;
            // Load data when user logs in (only if not already loaded)
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
            _hasLoadedData = false; // Reset loaded state
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
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Header section matching channel_list_screen design
        Container(
          padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 4, 12, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Sign in to access your dashboard',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Main content
        Expanded(
          child: SafeArea(
            top: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to Dictation Studio',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sign in to access your personalized learning dashboard',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfileView(
    BuildContext context,
    user,
    AuthProvider authProvider,
  ) {
    AppLogger.info('Building user profile view for user: ${user.username}');
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header section matching channel_list_screen design
        Container(
          padding: EdgeInsets.fromLTRB(12, MediaQuery.of(context).padding.top + 4, 12, 20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // User Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 3,
                  ),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: user.avatar.isNotEmpty
                      ? NetworkImage(user.avatar)
                      : null,
                  child: user.avatar.isEmpty
                      ? Icon(
                          Icons.person,
                          size: 32,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // User Role Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main content - scrollable
        Expanded(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                // Info Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // First row - Email and Plan
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildSimpleInfoItem(
                                'Email',
                                user.email,
                                Icons.email_outlined,
                                theme.colorScheme.primary,
                                theme,
                              ),
                            ),
                            Container(
                              width: 1,
                              color: theme.colorScheme.outline.withValues(alpha: 0.1),
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            Expanded(
                              child: _buildSimpleInfoItem(
                                'Plan',
                                user.plan.name,
                                Icons.workspace_premium_outlined,
                                theme.colorScheme.secondary,
                                theme,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(height: 32, color: theme.colorScheme.outline.withValues(alpha: 0.1)),

                      // Second row - Expires and Total Time
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                theme.colorScheme.tertiary,
                                theme,
                              ),
                            ),
                            Container(
                              width: 1,
                              color: theme.colorScheme.outline.withValues(alpha: 0.1),
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                theme.colorScheme.primary,
                                theme,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Calendar Heatmap with Refresh Button
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Dictation Activities',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            // Refresh Button
                            IconButton(
                              onPressed: _loadingDuration ? null : _refreshData,
                              icon: _loadingDuration
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              theme.colorScheme.primary,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.refresh,
                                      color: theme.colorScheme.primary,
                                    ),
                              tooltip: 'Refresh heatmap data',
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_loadingDuration)
                          Center(
                            child: CircularProgressIndicator(
                              color: theme.colorScheme.primary,
                            ),
                          )
                        else
                          CalendarHeatmap.withDefaults(
                            data: _dailyDurations,
                            cellSize: 8,
                            spacing: 2,
                            baseColor: theme.colorScheme.primary,
                            emptyColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: authProvider.isLoading
                        ? null
                        : () => _showLogoutDialog(context, authProvider, theme),
                    icon: authProvider.isLoading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.error,
                              ),
                            ),
                          )
                        : Icon(Icons.logout_outlined, color: theme.colorScheme.error),
                    label: Text(
                      authProvider.isLoading ? 'Signing Out...' : 'Sign Out',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
          ),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider, ThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.logout_outlined,
                color: theme.colorScheme.error,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Sign Out',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await authProvider.logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSimpleInfoItem(
    String title,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
