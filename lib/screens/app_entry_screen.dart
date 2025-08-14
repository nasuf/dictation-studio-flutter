import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';

class AppEntryScreen extends StatefulWidget {
  const AppEntryScreen({super.key});

  @override
  State<AppEntryScreen> createState() => _AppEntryScreenState();
}

class _AppEntryScreenState extends State<AppEntryScreen>
    with TickerProviderStateMixin {
  late AnimationController _typewriterController;
  late AnimationController _logoController;
  late AnimationController _pulseController;
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

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _startAnimations();
  }

  void _startAnimations() async {
    // Start logo animation
    _logoController.forward();

    // Wait a bit then start typewriter effect
    await Future.delayed(const Duration(milliseconds: 600));

    if (mounted) {
      _startTypewriterEffect();

      // Start cursor blinking
      _startCursorBlink();

      // Start progress indicator pulse
      _pulseController.repeat(reverse: true);

      // Check onboarding status after animations
      await Future.delayed(const Duration(milliseconds: 3000));
      _checkOnboardingStatus();
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
  void dispose() {
    _typewriterController.dispose();
    _logoController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.techBlue,
                    AppColors.techCyan,
                    AppColors.techPurple
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
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

              const SizedBox(height: 40),

              // Typewriter App Name
              Container(
                height: 50,
                alignment: Alignment.center,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _displayedText,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFE8E8EA)
                              : Colors.white,
                          letterSpacing: -0.5,
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
                      // Cursor
                      if (_showCursor)
                        TextSpan(
                          text: '|',
                          style: TextStyle(
                            fontSize: 28,
                            color: isDark
                                ? const Color(0xFF007AFF)
                                : Colors.white,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // Loading Indicator - consistent with channel_list_screen
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_pulseController.value * 0.1),
                    child: SpinKitPulse(
                      color: isDark ? const Color(0xFF007AFF) : Colors.white,
                      size: 50,
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Loading Text
              Text(
                'Loading...',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF9E9EA3)
                      : Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  shadows: isDark
                      ? null
                      : [
                          const Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 2,
                          ),
                        ],
                ),
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
        // Microphone base
        const Icon(Icons.mic, size: 40, color: Colors.white),
        // Text/typing indicator overlay
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.techBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.edit, size: 8, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
