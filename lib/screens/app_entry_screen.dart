import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/onboarding_service.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final isCompleted = await OnboardingService.isOnboardingCompleted();
    if (mounted) {
      // Navigate to appropriate screen based on onboarding status
      if (isCompleted) {
        // User has completed onboarding, go to main screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/main');
          }
        });
      } else {
        // User hasn't completed onboarding, go to onboarding screen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/onboarding');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Show loading indicator while checking onboarding status
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : null,
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
            : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? const Color(0xFF007AFF) : theme.colorScheme.primary,
                ),
                strokeWidth: 3,
                backgroundColor: isDark 
                  ? const Color(0xFF3A3A3F).withValues(alpha: 0.3)
                  : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Loading...',
                style: TextStyle(
                  color: isDark 
                    ? const Color(0xFF9E9EA3) 
                    : theme.colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
