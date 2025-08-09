import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/channel_provider.dart';
import 'providers/video_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/locale_provider.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';
import 'screens/video_list_screen.dart';
import 'screens/admin/channel_management_screen.dart';
import 'screens/admin/video_management_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/analytics_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dictation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/deep_link_service.dart';
import 'services/api_service.dart';
import 'utils/logger.dart';
import 'generated/app_localizations.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Configure system status bar - transparent to match app content
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Transparent to show app content
        statusBarBrightness: Brightness.light, // For iOS
        statusBarIconBrightness: Brightness.dark, // Dark icons on light background
        systemNavigationBarColor: Colors.white, // Bottom navigation bar
        systemNavigationBarIconBrightness: Brightness.dark, // Dark icons
      ),
    );

    // Initialize logging system
    AppLogger.initialize();

    AppLogger.info('🚀 Starting Dictation Studio App...');

    // Initialize Supabase with deep link configuration
    AppLogger.info('📡 Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://orvcshdggqwqpndspqzm.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ydmNzaGRnZ3F3cXBuZHNwcXptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mjk0MDEyNTcsImV4cCI6MjA0NDk3NzI1N30.OtWRrOxagU6DUiAvgEYioAanPTdYrMZ2gfa0-PCO0LY',
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
      storageOptions: const StorageClientOptions(retryAttempts: 10),
    );

    // Listen for deep links and handle OAuth callbacks
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      AppLogger.info('🔄 Auth state change: $event');
      if (event == AuthChangeEvent.signedIn && session != null) {
        AppLogger.info('✅ User signed in via OAuth callback');
      } else if (event == AuthChangeEvent.signedOut) {
        AppLogger.info('🚪 User signed out');
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        AppLogger.info('🔄 Token refreshed');
      }
    });

    AppLogger.success('✅ Supabase initialized successfully');

    // Initialize deep link service for OAuth callbacks
    AppLogger.info('🔗 Initializing deep link service...');
    await DeepLinkService().initialize();
    AppLogger.success('✅ Deep link service initialized');

    // Initialize theme service
    AppLogger.info('🎨 Initializing theme service...');
    await ThemeService.instance.initialize();
    AppLogger.success('✅ Theme service initialized');

    AppLogger.info('🎯 Running app...');
    runApp(const DictationStudioApp());
  } catch (e, stackTrace) {
    AppLogger.error('❌ Error during app initialization: $e', e, stackTrace);
    // Run a minimal error app
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('App Initialization Error'),
                const SizedBox(height: 8),
                Text('Error: $e'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DictationStudioApp extends StatefulWidget {
  const DictationStudioApp({super.key});

  @override
  State<DictationStudioApp> createState() => _DictationStudioAppState();
}

class _DictationStudioAppState extends State<DictationStudioApp> {
  // Global navigation key for 401 error handling
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  // Create router instance once to avoid rebuilding on theme changes
  late final GoRouter _router = _buildRouter(_navigatorKey);

  @override
  Widget build(BuildContext context) {
    AppLogger.info('🏗️ Building DictationStudioApp...');
    
    // Set the navigator key for API service
    ApiService.setNavigatorKey(_navigatorKey);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            AppLogger.info('🔐 Creating AuthProvider...');
            final authProvider = AuthProvider();
            // Don't initialize asynchronously - let SplashScreen handle the timing
            return authProvider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            AppLogger.info('📺 Creating ChannelProvider...');
            return ChannelProvider();
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            AppLogger.info('🎬 Creating VideoProvider...');
            return VideoProvider();
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            AppLogger.info('⚙️ Creating AdminProvider...');
            return AdminProvider();
          },
        ),
        ChangeNotifierProvider.value(
          value: ThemeService.instance,
        ),
        ChangeNotifierProvider(
          create: (_) {
            AppLogger.info('🌍 Creating LocaleProvider...');
            return LocaleProvider();
          },
        ),
      ],
      child: Consumer2<ThemeService, LocaleProvider>(
        builder: (context, themeService, localeProvider, child) {
          return MaterialApp.router(
            title: 'Dictation Studio',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: _getThemeMode(themeService.themeMode),
            locale: localeProvider.locale,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'), // English
              Locale('zh'), // Simplified Chinese
              Locale('zh', 'TW'), // Traditional Chinese
              Locale('ja'), // Japanese
              Locale('ko'), // Korean
            ],
            routerConfig: _router,
            builder: (context, child) {
              // Add error boundary
              return child ?? const SizedBox();
            },
          );
        },
      ),
    );
  }

  /// Convert our theme mode to Flutter's ThemeMode
  ThemeMode _getThemeMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }


  // Build app router using GoRouter
  GoRouter _buildRouter(GlobalKey<NavigatorState> navigatorKey) {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      errorBuilder: (context, state) {
        AppLogger.error('🚨 Router error: ${state.error}');
        return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  state.error?.toString() ?? 'Unknown error',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        );
      },
      routes: [
        // Splash Screen (Entry Point)
        GoRoute(
          path: '/',
          name: 'splash',
          pageBuilder: (context, state) {
            AppLogger.info('🚀 Navigating to splash screen');
            return MaterialPage(key: state.pageKey, child: const SplashScreen());
          },
        ),

        // Onboarding Route
        GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          pageBuilder: (context, state) {
            AppLogger.info('👋 Navigating to onboarding screen');
            return const MaterialPage(child: OnboardingScreen());
          },
        ),

        // Main Screen with Tabs
        GoRoute(
          path: '/main',
          name: 'main',
          pageBuilder: (context, state) {
            AppLogger.info('🏠 Navigating to main screen');
            return MaterialPage(key: state.pageKey, child: const MainScreen());
          },
        ),

        // Video List Route (From channels tab)
        GoRoute(
          path: '/videos/:channelId',
          name: 'videos',
          pageBuilder: (context, state) {
            final channelId = state.pathParameters['channelId']!;
            final extra = state.extra as Map<String, dynamic>?;
            final channelName = extra?['channelName'] as String?;

            AppLogger.info('🎬 Navigating to video list: $channelId');
            return MaterialPage(
              key: state.pageKey,
              child: VideoListScreen(
                channelId: channelId,
                channelName: channelName,
              ),
            );
          },
        ),

        // Dictation Route
        GoRoute(
          path: '/dictation/:channelId/:videoId',
          name: 'dictation',
          pageBuilder: (context, state) {
            final channelId = state.pathParameters['channelId']!;
            final videoId = state.pathParameters['videoId']!;
            final extra = state.extra as Map<String, dynamic>?;
            final video = extra?['video'];

            AppLogger.info('🎧 Navigating to dictation: $channelId/$videoId');
            
            if (video == null) {
              // If no video data provided, show error
              return MaterialPage(
                key: state.pageKey,
                child: Scaffold(
                  appBar: AppBar(title: const Text('Error')),
                  body: const Center(
                    child: Text('Video data not found'),
                  ),
                ),
              );
            }

            return MaterialPage(
              key: state.pageKey,
              child: DictationScreen(
                channelId: channelId,
                videoId: videoId,
                video: video,
              ),
            );
          },
        ),

        // Login Route
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) {
            AppLogger.info('🔐 Navigating to login screen');
            return const MaterialPage(child: LoginScreen());
          },
        ),

        // Admin Management Routes
        GoRoute(
          path: '/admin/channels',
          name: 'admin-channels',
          pageBuilder: (context, state) {
            AppLogger.info('📺 Navigating to channel management');
            return const MaterialPage(child: ChannelManagementScreen());
          },
        ),
        GoRoute(
          path: '/admin/videos',
          name: 'admin-videos',
          pageBuilder: (context, state) {
            AppLogger.info('🎬 Navigating to video management');
            return const MaterialPage(child: VideoManagementScreen());
          },
        ),
        GoRoute(
          path: '/admin/users',
          name: 'admin-users',
          pageBuilder: (context, state) {
            AppLogger.info('👥 Navigating to user management');
            return const MaterialPage(child: UserManagementScreen());
          },
        ),
        GoRoute(
          path: '/admin/analytics',
          name: 'admin-analytics',
          pageBuilder: (context, state) {
            AppLogger.info('📊 Navigating to analytics');
            return const MaterialPage(child: AnalyticsScreen());
          },
        ),
      ],
    );
  }
}
