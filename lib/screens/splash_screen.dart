import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/onboarding_service.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    // Add a minimum splash time for better UX
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Wait a bit more to allow any ongoing auth operations to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Check if user is currently logged in
      if (authProvider.isLoggedIn) {
        // User is logged in, go to main screen
        context.go('/main');
        return;
      }
      
      // User is not logged in, check onboarding status
      final isOnboardingCompleted = await OnboardingService.isOnboardingCompleted();
      
      if (!mounted) return;

      if (isOnboardingCompleted) {
        context.go('/main');
      } else {
        context.go('/onboarding');
      }
    } catch (e) {
      // If there's an error, default to onboarding
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1A1A1D), // Darker at top
                  Color(0xFF0A0A0B), // Darkest at bottom
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4CAF50), // Green
                  Color(0xFF66BB6A), // Light green
                  Color(0xFF81C784), // Soft green
                ],
                stops: [0.0, 0.5, 1.0],
              ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon with enhanced styling
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF007AFF),
                          Color(0xFF0056CC),
                        ],
                      )
                    : null,
                  color: isDark ? null : Colors.white.withValues(alpha: 0.2),
                  boxShadow: isDark ? [
                    const BoxShadow(
                      color: Color(0xFF000000),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                      spreadRadius: 0,
                    ),
                  ] : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.audiotrack,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // App title with tech styling
              Text(
                'Dictation Studio',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFE8E8EA) : Colors.white,
                  letterSpacing: -1.0,
                  shadows: isDark ? [
                    const Shadow(
                      color: Color(0xFF000000),
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ] : [
                    const Shadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Loading indicator with tech styling
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark 
                    ? const Color(0xFF1C1C1E).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.2),
                  border: Border.all(
                    color: isDark 
                      ? const Color(0xFF3A3A3F).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? const Color(0xFF007AFF) : Colors.white,
                  ),
                  strokeWidth: 3,
                  backgroundColor: isDark 
                    ? const Color(0xFF3A3A3F).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}