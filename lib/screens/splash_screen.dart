import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/onboarding_service.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late AnimationController _logoController;
  String _displayedText = '';
  final String _fullText = 'Dictation Studio';
  bool _showCursor = true;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _typewriterController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _startAnimations();
    _checkAndNavigate();
  }

  void _startAnimations() async {
    // Start logo animation
    _logoController.forward();

    // Wait a bit then start typewriter effect
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      _startTypewriterEffect();
      _startCursorBlink();
    }
  }

  void _startTypewriterEffect() {
    int currentIndex = 0;

    void typeNextCharacter() {
      if (currentIndex <= _fullText.length && mounted) {
        setState(() {
          _displayedText = _fullText.substring(0, currentIndex);
        });
        currentIndex++;

        if (currentIndex <= _fullText.length) {
          Future.delayed(const Duration(milliseconds: 100), typeNextCharacter);
        }
      }
    }

    typeNextCharacter();
  }

  void _startCursorBlink() {
    void blink() {
      if (mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
        Future.delayed(const Duration(milliseconds: 500), blink);
      }
    }

    blink();
  }

  @override
  void dispose() {
    _typewriterController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _checkAndNavigate() async {
    // Add a minimum splash time for better UX and animations
    await Future.delayed(const Duration(milliseconds: 3000));
    
    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      print('🔍 [SplashScreen] Starting auth check...');
      print('🔍 [SplashScreen] Manually initializing AuthProvider...');
      
      // Manually initialize AuthProvider and wait for completion
      await authProvider.initialize();
      
      print('🔍 [SplashScreen] AuthProvider initialization completed');
      print('🔍 [SplashScreen] authProvider.isLoading: ${authProvider.isLoading}');
      print('🔍 [SplashScreen] authProvider.isLoggedIn: ${authProvider.isLoggedIn}');
      print('🔍 [SplashScreen] authProvider.currentUser: ${authProvider.currentUser?.email ?? 'null'}');
      
      if (!mounted) return;
      
      // Check if user is currently logged in
      if (authProvider.isLoggedIn) {
        print('✅ [SplashScreen] User is logged in, navigating to /main');
        // User is logged in, go to main screen
        context.go('/main');
        return;
      }
      
      print('❌ [SplashScreen] User is not logged in, checking onboarding status...');
      
      // User is not logged in, check onboarding status
      final isOnboardingCompleted = await OnboardingService.isOnboardingCompleted();
      print('🔍 [SplashScreen] Onboarding completed: $isOnboardingCompleted');
      
      if (!mounted) return;

      if (isOnboardingCompleted) {
        print('➡️ [SplashScreen] Navigating to /login (onboarding completed, user not logged in)');
        // User has seen onboarding but is not logged in, go to login
        context.go('/login');
      } else {
        print('➡️ [SplashScreen] Navigating to /onboarding (first time user)');
        // First time user, show onboarding
        context.go('/onboarding');
      }
    } catch (e) {
      print('❌ [SplashScreen] Error during navigation check: $e');
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
              // Animated Dictation Logo
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: Tween<double>(begin: 0.0, end: 1.0)
                        .animate(
                          CurvedAnimation(
                            parent: _logoController,
                            curve: Curves.elasticOut,
                          ),
                        )
                        .value,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isDark
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF007AFF), Color(0xFF0056CC)],
                              )
                            : null,
                        color: isDark ? null : Colors.white.withOpacity(0.2),
                        boxShadow: isDark
                            ? [
                                const BoxShadow(
                                  color: Color(0xFF000000),
                                  blurRadius: 20,
                                  offset: Offset(0, 4),
                                  spreadRadius: 0,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: _buildDictationLogo(isDark),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              // Typewriter App Name
              Container(
                height: 50,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Text part
                    Text(
                      _displayedText,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFE8E8EA)
                            : Colors.white,
                        letterSpacing: -1.0,
                        shadows: isDark
                            ? [
                                const Shadow(
                                  color: Color(0xFF000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ]
                            : [
                                const Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 8,
                                ),
                              ],
                      ),
                    ),
                    // Fixed-width cursor container
                    SizedBox(
                      width: 8, // Fixed width for cursor space
                      child: AnimatedOpacity(
                        opacity: _showCursor ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 50),
                        child: Text(
                          '|',
                          style: TextStyle(
                            fontSize: 32,
                            color: isDark
                                ? const Color(0xFF007AFF)
                                : Colors.white,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              // Loading Indicator - consistent with channel_list_screen
              SpinKitPulse(
                color: isDark ? const Color(0xFF007AFF) : Colors.white,
                size: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDictationLogo(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main microphone icon with gradient
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFFFFFFFF).withOpacity(0.9),
                      const Color(0xFFE0E0E0).withOpacity(0.8),
                    ]
                  : [
                      Colors.white,
                      const Color(0xFFF0F0F0),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: isDark 
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.mic,
            size: 40,
            color: isDark ? const Color(0xFF1A1A1D) : const Color(0xFF2E7D32),
          ),
        ),
        
        // Sound wave indicator - subtle animation effect
        Positioned(
          right: 8,
          top: 12,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF007AFF),
                        const Color(0xFF0056CC),
                      ]
                    : [
                        const Color(0xFF4CAF50),
                        const Color(0xFF388E3C),
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark 
                      ? const Color(0xFF007AFF) 
                      : const Color(0xFF4CAF50)).withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              Icons.graphic_eq,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}