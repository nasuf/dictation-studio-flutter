import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/channel_provider.dart';
import 'providers/video_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/admin_provider.dart';
import 'screens/main_screen.dart';
import 'screens/video_list_screen.dart';
import 'services/deep_link_service.dart';
import 'utils/logger.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

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

class DictationStudioApp extends StatelessWidget {
  const DictationStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.info('🏗️ Building DictationStudioApp...');

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
        routerConfig: _buildRouter(),
        builder: (context, child) {
          // Add error boundary
          return child ?? const SizedBox();
        },
      ),
    );
  }

  // Build app theme with modern Material Design 3 style
  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 2,
        shadowColor: Colors.black26,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      scaffoldBackgroundColor: Colors.grey.shade50,
      fontFamily: 'Roboto',
    );
  }

  // Build app router using GoRouter
  GoRouter _buildRouter() {
    return GoRouter(
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
      ],
    );
  }
}
