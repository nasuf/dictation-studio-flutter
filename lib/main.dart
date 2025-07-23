import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/channel_provider.dart';
import 'providers/video_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/main_screen.dart';
import 'screens/video_list_screen.dart';
import 'screens/admin/channel_management_screen.dart';
import 'screens/admin/video_management_screen.dart';
import 'screens/admin/user_management_screen.dart';
import 'screens/admin/analytics_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dictation_screen.dart';
import 'services/deep_link_service.dart';
import 'services/api_service.dart';
import 'utils/logger.dart';

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

    AppLogger.info('🎯 Running app...');
    runApp(DictationStudioApp());
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

class DictationStudioApp extends StatelessWidget {
  DictationStudioApp({super.key});
  
  // Global navigation key for 401 error handling
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
            // Initialize auth provider asynchronously to avoid blocking
            Future.microtask(() => authProvider.initialize());
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
      ],
      child: MaterialApp.router(
        title: 'Dictation Studio',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        routerConfig: _buildRouter(_navigatorKey),
        builder: (context, child) {
          // Add error boundary
          return child ?? const SizedBox();
        },
      ),
    );
  }

  // Build comprehensive Material Design 3 theme with light green color scheme
  ThemeData _buildTheme() {
    // Create custom light green color scheme
    final lightGreenColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF66BB6A), // Light green primary
      brightness: Brightness.light,
      // Custom color overrides for light green theme
      primary: const Color(0xFF4CAF50),        // Green 500
      primaryContainer: const Color(0xFFE8F5E8), // Very light green
      secondary: const Color(0xFF8BC34A),       // Light green 500
      secondaryContainer: const Color(0xFFF1F8E9), // Very light lime
      tertiary: const Color(0xFF009688),        // Teal 500
      surface: Colors.white,
      surfaceContainerHighest: const Color(0xFFF1F8E9),  // Light green tint
      onSurface: const Color(0xFF1B5E20),       // Dark green for text
      outline: const Color(0xFF81C784),         // Medium green for borders
      shadow: Colors.black.withValues(alpha: 0.1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: lightGreenColorScheme,
      
      // AppBar theme with light green styling
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: lightGreenColorScheme.shadow,
        backgroundColor: lightGreenColorScheme.surface,
        surfaceTintColor: lightGreenColorScheme.primary,
        foregroundColor: lightGreenColorScheme.onSurface,
        titleTextStyle: TextStyle(
          color: lightGreenColorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.0,
        ),
        iconTheme: IconThemeData(
          color: lightGreenColorScheme.primary,
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: lightGreenColorScheme.primary,
          size: 24,
        ),
      ),

      // Modern button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          backgroundColor: lightGreenColorScheme.primary,
          foregroundColor: lightGreenColorScheme.onPrimary,
          disabledBackgroundColor: lightGreenColorScheme.outline.withValues(alpha: 0.12),
          disabledForegroundColor: lightGreenColorScheme.onSurface.withValues(alpha: 0.38),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.1,
          ),
        ),
      ),
      
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightGreenColorScheme.primary,
          foregroundColor: lightGreenColorScheme.onPrimary,
          disabledBackgroundColor: lightGreenColorScheme.onSurface.withValues(alpha: 0.12),
          disabledForegroundColor: lightGreenColorScheme.onSurface.withValues(alpha: 0.38),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightGreenColorScheme.primary,
          disabledForegroundColor: lightGreenColorScheme.onSurface.withValues(alpha: 0.38),
          side: BorderSide(color: lightGreenColorScheme.outline),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightGreenColorScheme.primary,
          disabledForegroundColor: lightGreenColorScheme.onSurface.withValues(alpha: 0.38),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: lightGreenColorScheme.primaryContainer,
        foregroundColor: lightGreenColorScheme.onPrimaryContainer,
        elevation: 3,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: lightGreenColorScheme.shadow,
        surfaceTintColor: lightGreenColorScheme.surfaceContainerHighest,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: lightGreenColorScheme.surfaceContainerHighest,
        deleteIconColor: lightGreenColorScheme.onSurfaceVariant,
        disabledColor: lightGreenColorScheme.onSurface.withValues(alpha: 0.12),
        selectedColor: lightGreenColorScheme.secondaryContainer,
        secondarySelectedColor: lightGreenColorScheme.secondary,
        shadowColor: lightGreenColorScheme.shadow,
        labelStyle: TextStyle(
          color: lightGreenColorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: lightGreenColorScheme.onSecondaryContainer,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        brightness: Brightness.light,
        elevation: 0,
        pressElevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightGreenColorScheme.surfaceContainerHighest,
        hintStyle: TextStyle(
          color: lightGreenColorScheme.onSurfaceVariant,
          fontSize: 16,
        ),
        labelStyle: TextStyle(
          color: lightGreenColorScheme.primary,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: lightGreenColorScheme.outline,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: lightGreenColorScheme.outline,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: lightGreenColorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
            color: lightGreenColorScheme.error,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Navigation theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightGreenColorScheme.surface,
        indicatorColor: lightGreenColorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: lightGreenColorScheme.onSecondaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
          }
          return TextStyle(
            color: lightGreenColorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: lightGreenColorScheme.onSecondaryContainer,
              size: 24,
            );
          }
          return IconThemeData(
            color: lightGreenColorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),

      // SnackBar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: lightGreenColorScheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: lightGreenColorScheme.onInverseSurface,
          fontSize: 14,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 3,
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: lightGreenColorScheme.surface,
        surfaceTintColor: lightGreenColorScheme.surfaceContainerHighest,
        elevation: 3,
        shadowColor: lightGreenColorScheme.shadow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          color: lightGreenColorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        contentTextStyle: TextStyle(
          color: lightGreenColorScheme.onSurfaceVariant,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Progress indicator theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: lightGreenColorScheme.primary,
        linearTrackColor: lightGreenColorScheme.surfaceContainerHighest,
        circularTrackColor: lightGreenColorScheme.surfaceContainerHighest,
      ),

      // Scaffold background
      scaffoldBackgroundColor: lightGreenColorScheme.surface,
      
      // Typography
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        displayLarge: TextStyle(color: lightGreenColorScheme.onSurface),
        displayMedium: TextStyle(color: lightGreenColorScheme.onSurface),
        displaySmall: TextStyle(color: lightGreenColorScheme.onSurface),
        headlineLarge: TextStyle(color: lightGreenColorScheme.onSurface),
        headlineMedium: TextStyle(color: lightGreenColorScheme.onSurface),
        headlineSmall: TextStyle(color: lightGreenColorScheme.onSurface),
        titleLarge: TextStyle(color: lightGreenColorScheme.onSurface, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(color: lightGreenColorScheme.onSurface, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: lightGreenColorScheme.onSurface, fontWeight: FontWeight.w500),
        labelLarge: TextStyle(color: lightGreenColorScheme.primary, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: lightGreenColorScheme.primary, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: lightGreenColorScheme.primary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: lightGreenColorScheme.onSurface),
        bodyMedium: TextStyle(color: lightGreenColorScheme.onSurface),
        bodySmall: TextStyle(color: lightGreenColorScheme.onSurfaceVariant),
      ),
    );
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
        // Main Screen with Tabs (Home)
        GoRoute(
          path: '/',
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
