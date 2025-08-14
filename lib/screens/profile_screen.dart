import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../services/api_service.dart';
import '../services/token_manager.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';
import '../widgets/calendar_heatmap.dart';
import '../widgets/theme_toggle_button.dart';
import '../generated/app_localizations.dart';
import 'login_screen.dart';
import '../models/progress_data.dart' as progress_data;
import '../models/video.dart';

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

  // Scroll controller for header animation
  final ScrollController _scrollController = ScrollController();
  double _headerHeight = 180.0; // Initial header height
  double _headerOpacity = 1.0;
  double _titleFontSize = 32.0;
  double _adminTagFontSize = 11.0;
  double _adminTagPadding = 8.0;
  double _adminTagBorderRadius = 12.0;

  // Keep the state alive when switching tabs
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    const double maxScroll = 140.0; // Maximum scroll distance for animation
    const double minHeaderHeight =
        140.0; // Further increased minimum header height to prevent overflow
    const double maxHeaderHeight = 180.0; // Larger initial header height
    const double minTitleSize = 18.0; // Larger minimum to keep readable
    const double maxTitleSize = 32.0; // Larger initial title

    final double scrollOffset = _scrollController.offset.clamp(0.0, maxScroll);
    final double progress = scrollOffset / maxScroll;

    setState(() {
      _headerHeight =
          maxHeaderHeight - (maxHeaderHeight - minHeaderHeight) * progress;
      _headerOpacity = 1.0 - (progress * 0.2); // Less opacity change
      _titleFontSize = maxTitleSize - (maxTitleSize - minTitleSize) * progress;
      // Admin tag scaling
      _adminTagFontSize = 11.0 - (11.0 - 9.0) * progress;
      _adminTagPadding = 8.0 - (8.0 - 6.0) * progress;
      _adminTagBorderRadius = 12.0 - (12.0 - 8.0) * progress;
    });
  }

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
              ? (totalDurationValue is int
                    ? totalDurationValue
                    : (totalDurationValue as double).toInt())
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
              final value = rawValue is int
                  ? rawValue
                  : (rawValue as double).toInt();
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0A0A0B)
          : theme.colorScheme.surface,
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
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Header section matching channel_list_screen design
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            MediaQuery.of(context).padding.top + 4,
            16,
            12,
          ),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A1D), Color(0xFF16161A)],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                    ],
                  ),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF2A2A2F).withValues(alpha: 0.5)
                    : theme.colorScheme.outline.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            boxShadow: isDark
                ? [
                    const BoxShadow(
                      color: Color(0xFF000000),
                      offset: Offset(0, 2),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.profile,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFE8E8EA)
                            : theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.signInToAccess,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? const Color(0xFF9E9EA3)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                        fontWeight: FontWeight.w500,
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
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.1,
                          ),
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
                      AppLocalizations.of(context)!.welcome,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.signInToAccess,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
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
                      label: Text(AppLocalizations.of(context)!.signIn),
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
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Animated Header
        AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: _headerHeight,
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.of(context).padding.top + 16,
            24,
            16,
          ),
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A1A1D).withOpacity(_headerOpacity),
                      const Color(0xFF16161A).withOpacity(_headerOpacity * 0.8),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primaryContainer.withOpacity(
                        _headerOpacity * 0.7,
                      ),
                      theme.colorScheme.primaryContainer.withOpacity(
                        _headerOpacity * 0.4,
                      ),
                    ],
                  ),
            border: Border(
              bottom: BorderSide(
                color:
                    (isDark
                            ? const Color(0xFF2A2A2F)
                            : theme.colorScheme.outline)
                        .withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment
                .center, // Keep centered for consistent spacing
            crossAxisAlignment:
                CrossAxisAlignment.start, // Left align everything
            children: [
              // Username with Admin tag - positioned together
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Username - Large and prominent
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: _titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFE8E8EA)
                            : theme
                                  .colorScheme
                                  .onSurface, // Dark text for light mode
                        letterSpacing: -0.8,
                      ),
                      child: Text(
                        user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // Admin Role Badge - Right next to username with scaling animation
                  if (user.role.toLowerCase() == 'admin')
                    Container(
                      margin: const EdgeInsets.only(
                        left: 8,
                      ), // Close to username
                      padding: EdgeInsets.symmetric(
                        horizontal: _adminTagPadding, // Use animated padding
                        vertical:
                            _adminTagPadding *
                            0.5, // Proportional vertical padding
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF007AFF).withOpacity(0.2)
                            : theme.colorScheme.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(
                          _adminTagBorderRadius,
                        ), // Use animated border radius
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF007AFF).withOpacity(0.4)
                              : theme.colorScheme.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'ADMIN',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF007AFF)
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: _adminTagFontSize, // Use animated font size
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Main content - scrollable
        Expanded(
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
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
                          color: theme.colorScheme.shadow.withValues(
                            alpha: 0.08,
                          ),
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
                                  AppLocalizations.of(context)!.email,
                                  user.email,
                                  Icons.email_outlined,
                                  theme.colorScheme.primary,
                                  theme,
                                ),
                              ),
                              Container(
                                width: 1,
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.1,
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              Expanded(
                                child: _buildSimpleInfoItem(
                                  AppLocalizations.of(context)!.plan,
                                  user.plan.name,
                                  Icons.workspace_premium_outlined,
                                  theme.colorScheme.secondary,
                                  theme,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(
                          height: 32,
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.1,
                          ),
                        ),

                        // Second row - Expires and Total Time
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildSimpleInfoItem(
                                  AppLocalizations.of(context)!.expires,
                                  user.plan.expireTime != null
                                      ? DateFormat('MMM dd, yyyy').format(
                                          DateTime.fromMillisecondsSinceEpoch(
                                            user.plan.expireTime!,
                                          ),
                                        )
                                      : AppLocalizations.of(context)!.noLimit,
                                  Icons.schedule_outlined,
                                  theme.colorScheme.tertiary,
                                  theme,
                                ),
                              ),
                              Container(
                                width: 1,
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.1,
                                ),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              Expanded(
                                child: _buildSimpleInfoItem(
                                  AppLocalizations.of(context)!.totalTime,
                                  () {
                                    AppLogger.info(
                                      '🎯 UI Display - _loadingDuration: $_loadingDuration',
                                    );
                                    AppLogger.info(
                                      '🎯 UI Display - _totalDuration: $_totalDuration',
                                    );
                                    if (_loadingDuration) {
                                      return AppLocalizations.of(
                                        context,
                                      )!.loading;
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
                          color: theme.colorScheme.shadow.withValues(
                            alpha: 0.08,
                          ),
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
                                  AppLocalizations.of(
                                    context,
                                  )!.dictationActivities,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              // Refresh Button
                              IconButton(
                                onPressed: _loadingDuration
                                    ? null
                                    : _refreshData,
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
                                tooltip: AppLocalizations.of(context)!.refresh,
                                style: IconButton.styleFrom(
                                  backgroundColor: theme
                                      .colorScheme
                                      .primaryContainer
                                      .withValues(alpha: 0.7),
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
                              emptyColor: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Theme Settings Section
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.settings_outlined,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.settings,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const ThemeSettingsListTile(),
                        _buildLanguageSettingsTile(theme),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Dictation Progress Section
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context)!.progress,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildDictationProgressTile(theme),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: authProvider.isLoading
                          ? null
                          : () =>
                                _showLogoutDialog(context, authProvider, theme),
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
                          : Icon(
                              Icons.logout_outlined,
                              color: theme.colorScheme.error,
                            ),
                      label: Text(
                        authProvider.isLoading
                            ? AppLocalizations.of(context)!.signingOut
                            : AppLocalizations.of(context)!.signOut,
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

  void _showLogoutDialog(
    BuildContext context,
    AuthProvider authProvider,
    ThemeData theme,
  ) {
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
                AppLocalizations.of(context)!.signOut,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context)!.areYouSureSignOut,
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
                AppLocalizations.of(context)!.cancel,
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
              child: Text(AppLocalizations.of(context)!.signOut),
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

  Widget _buildLanguageSettingsTile(ThemeData theme) {
    return ListTile(
      leading: Icon(
        Icons.language_outlined,
        color: theme.colorScheme.primary,
        size: 20,
      ),
      title: Text(
        AppLocalizations.of(context)!.language,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Consumer<LocaleProvider>(
        builder: (context, localeProvider, child) {
          // Get the correct language code for display
          String displayLanguageCode;
          if (localeProvider.locale.languageCode == 'zh' &&
              localeProvider.locale.countryCode == 'TW') {
            displayLanguageCode = AppConstants.languageTraditionalChinese;
          } else {
            displayLanguageCode = localeProvider.locale.languageCode;
          }

          return Text(
            _getLocalizedLanguageName(context, displayLanguageCode),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          );
        },
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: theme.colorScheme.outline,
      ),
      onTap: () => _showLanguageSelection(context, theme),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  void _showLanguageSelection(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.selectLanguage,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Language options
              ...LanguageHelper.getSupportedLanguages().map(
                (language) => _buildLanguageOption(
                  context,
                  theme,
                  _getLocalizedLanguageName(context, language),
                  language,
                  Icons.language,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    ThemeData theme,
    String title,
    String value,
    IconData icon,
  ) {
    final localeProvider = context.watch<LocaleProvider>();
    // Handle Traditional Chinese locale matching
    final isSelected = _isLanguageSelected(localeProvider.locale, value);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          context.read<LocaleProvider>().setLocale(value);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Check if a language is selected, handling Traditional Chinese special case
  bool _isLanguageSelected(Locale currentLocale, String languageCode) {
    if (languageCode == AppConstants.languageTraditionalChinese) {
      // For Traditional Chinese, check both language and country code
      return currentLocale.languageCode == 'zh' &&
          currentLocale.countryCode == 'TW';
    } else if (languageCode == AppConstants.languageChinese) {
      // For Simplified Chinese, ensure it's NOT Traditional Chinese
      return currentLocale.languageCode == 'zh' &&
          currentLocale.countryCode != 'TW';
    } else {
      // For other languages, just check language code
      return currentLocale.languageCode == languageCode;
    }
  }

  // Get native language name (not localized)
  String _getLocalizedLanguageName(BuildContext context, String language) {
    switch (language) {
      case AppConstants.languageEnglish:
        return 'English';
      case AppConstants.languageChinese:
        return '简体中文';
      case AppConstants.languageTraditionalChinese:
        return '繁體中文';
      case AppConstants.languageJapanese:
        return '日本語';
      case AppConstants.languageKorean:
        return '한국어';
      default:
        return language.toUpperCase();
    }
  }

  Widget _buildDictationProgressTile(ThemeData theme) {
    return ListTile(
      leading: Icon(
        Icons.library_books_outlined,
        color: theme.colorScheme.primary,
        size: 20,
      ),
      title: Text(
        AppLocalizations.of(context)!.dictationProgress,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        AppLocalizations.of(context)!.viewYourDictationHistory,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: theme.colorScheme.outline,
      ),
      onTap: () => _showDictationProgressDialog(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  /// 显示听写进度对话框
  void _showDictationProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DictationProgressDialog(),
    );
  }

}

/// 听写进度对话框
class _DictationProgressDialog extends StatefulWidget {
  @override
  State<_DictationProgressDialog> createState() => _DictationProgressDialogState();
}

class _DictationProgressDialogState extends State<_DictationProgressDialog> {
  List<progress_data.ProgressData> _progress = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _loadCurrentUserProgress();
  }

  /// 加载当前用户的听写进度
  Future<void> _loadCurrentUserProgress() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await _apiService.getCurrentUserProgress();
      
      if (mounted) {
        setState(() {
          _progress = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load current user progress: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// 根据频道分组进度数据
  Map<String, List<progress_data.ProgressData>> _groupProgressByChannel() {
    final Map<String, List<progress_data.ProgressData>> grouped = {};
    
    for (final item in _progress) {
      final channelName = item.channelName.isNotEmpty ? item.channelName : item.channelId;
      if (!grouped.containsKey(channelName)) {
        grouped[channelName] = [];
      }
      grouped[channelName]!.add(item);
    }
    
    // 按完成度排序每个频道下的视频
    for (final channelVideos in grouped.values) {
      channelVideos.sort((a, b) => b.overallCompletion.compareTo(a.overallCompletion));
    }
    
    return grouped;
  }

  /// 获取完成度对应的颜色
  Color _getCompletionColor(double completion, BuildContext context) {
    if (completion >= 90) {
      return Colors.green;
    } else if (completion >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.dictationProgress,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              
              // 内容区域
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context)!.loadError,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadCurrentUserProgress,
                                  child: Text(AppLocalizations.of(context)!.tryAgain),
                                ),
                              ],
                            ),
                          )
                        : _progress.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.library_books_outlined,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      AppLocalizations.of(context)!.noProgressDataAvailable,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppLocalizations.of(context)!.startDictationToSeeProgress,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : _buildProgressList(context, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建进度列表
  Widget _buildProgressList(BuildContext context, ThemeData theme) {
    final groupedProgress = _groupProgressByChannel();
    
    return ListView.builder(
      itemCount: groupedProgress.keys.length,
      itemBuilder: (context, index) {
        final channelName = groupedProgress.keys.elementAt(index);
        final videos = groupedProgress[channelName]!;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            title: Text(
              channelName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              '${videos.length} ${videos.length == 1 ? "video" : "videos"}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            leading: Icon(
              Icons.video_library,
              color: theme.colorScheme.primary,
            ),
            // 移除展开时的分隔线
            childrenPadding: EdgeInsets.zero,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: const Border(),
            collapsedShape: const Border(),
            children: videos.map((video) => _buildVideoItem(context, theme, video)).toList(),
          ),
        );
      },
    );
  }

  /// 构建单个视频项
  Widget _buildVideoItem(BuildContext context, ThemeData theme, progress_data.ProgressData video) {
    final completionColor = _getCompletionColor(video.overallCompletion, context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: theme.colorScheme.surfaceContainer,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              'https://img.youtube.com/vi/${video.videoId}/default.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.play_circle_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                );
              },
            ),
          ),
        ),
        title: Text(
          video.videoTitle.isNotEmpty ? video.videoTitle : 'Video ${video.videoId}',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: video.overallCompletion / 100,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(completionColor),
              minHeight: 6,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${video.overallCompletion.toStringAsFixed(1)}% ${AppLocalizations.of(context)!.completed}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: completionColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (video.overallCompletion >= 100)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: theme.colorScheme.outline,
        ),
        onTap: () {
          Navigator.of(context).pop(); // 关闭对话框
          // 导航到听写页面，使用与video_list_screen.dart相同的逻辑
          // 创建兼容的Video对象给dictation_screen使用
          final videoObject = Video(
            videoId: video.videoId,
            title: video.videoTitle,
            link: video.videoLink,
            visibility: 'public',
            createdAt: 0,
            updatedAt: 0,
            isRefined: true,
          );
          
          context.pushNamed(
            'dictation',
            pathParameters: {
              'channelId': video.channelId,
              'videoId': video.videoId,
            },
            extra: {
              'video': videoObject,
            },
          );
        },
      ),
    );
  }
}
