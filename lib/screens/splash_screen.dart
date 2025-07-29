import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/onboarding_service.dart';

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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon
              Icon(
                Icons.audiotrack,
                size: 80,
                color: Colors.white,
              ),
              SizedBox(height: 24),
              // App title
              Text(
                'Dictation Studio',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 40),
              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}