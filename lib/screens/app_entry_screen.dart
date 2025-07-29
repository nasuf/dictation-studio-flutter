import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/onboarding_service.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_screen.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen> {
  bool? _isOnboardingCompleted;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final isCompleted = await OnboardingService.isOnboardingCompleted();
    if (mounted) {
      setState(() {
        _isOnboardingCompleted = isCompleted;
      });
      
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
    // Show loading indicator while checking onboarding status
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}