import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../generated/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isNavigating = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_isNavigating) return; // Prevent multiple taps
    
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() {
        _isNavigating = true;
      });
      _navigateToLogin();
    }
  }

  void _navigateToLogin() async {
    // Add a small delay to prevent rapid taps
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      context.go('/login');
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
                  AppColors.techBlue,
                  AppColors.techCyan,
                  AppColors.techPurple
                ],
                stops: [0.0, 0.5, 1.0],
              ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Language selector at top
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildLanguageSelector(theme),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    _buildWelcomePage(theme),
                    _buildFeaturePage1(theme),
                    _buildFeaturePage2(theme),
                  ],
                ),
              ),

              // Bottom navigation
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Page indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action buttons
                    Row(
                      children: [
                        if (_currentPage > 0)
                          TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Text(
                              'Back',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        
                        const Spacer(),
                        
                        ElevatedButton(
                          onPressed: _isNavigating ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.techBlue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: _isNavigating && _currentPage == 2
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.techBlue,
                                    ),
                                  ),
                                )
                              : Text(
                                  _currentPage == 2
                                      ? AppLocalizations.of(context)!.getStarted
                                      : 'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
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

  Widget _buildLanguageSelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark 
              ? const Color(0xFF1C1C1E).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark 
                ? const Color(0xFF3A3A3F).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.3),
            ),
            boxShadow: isDark ? [
              const BoxShadow(
                color: Color(0xFF000000),
                blurRadius: 8,
                offset: Offset(0, 2),
                spreadRadius: 0,
              ),
            ] : null,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: localeProvider.locale.toString(),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white,
                size: 20,
              ),
              dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              style: TextStyle(
                color: isDark ? const Color(0xFFE8E8EA) : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              items: [
                DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: isDark ? const Color(0xFFE8E8EA) : Colors.black87))),
                DropdownMenuItem(value: 'zh', child: Text('简体中文', style: TextStyle(color: isDark ? const Color(0xFFE8E8EA) : Colors.black87))),
                DropdownMenuItem(value: 'zh_TW', child: Text('繁體中文', style: TextStyle(color: isDark ? const Color(0xFFE8E8EA) : Colors.black87))),
                DropdownMenuItem(value: 'ja', child: Text('日本語', style: TextStyle(color: isDark ? const Color(0xFFE8E8EA) : Colors.black87))),
                DropdownMenuItem(value: 'ko', child: Text('한국어', style: TextStyle(color: isDark ? const Color(0xFFE8E8EA) : Colors.black87))),
              ],
              onChanged: (String? newValue) {
                if (newValue != null) {
                  localeProvider.setLocale(newValue);
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomePage(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // App icon with enhanced styling
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
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
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark 
                  ? const Color(0xFF3A3A3F).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: isDark ? [
                const BoxShadow(
                  color: Color(0xFF000000),
                  blurRadius: 20,
                  offset: Offset(0, 4),
                  spreadRadius: 0,
                ),
              ] : null,
            ),
            child: const Icon(
              Icons.audiotrack,
              size: 60,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 40),
          
          // App title with enhanced styling
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
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Subtitle
          Text(
            AppLocalizations.of(context)!.welcomeMessage,
            style: TextStyle(
              fontSize: 20,
              color: isDark 
                ? const Color(0xFF9E9EA3)
                : Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            AppLocalizations.of(context)!.appDescription,
            style: TextStyle(
              fontSize: 16,
              color: isDark 
                ? const Color(0xFF8E8E93)
                : Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage1(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.language,
              size: 50,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 40),
          
          Text(
            AppLocalizations.of(context)!.feature1Title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          Text(
            AppLocalizations.of(context)!.feature1Description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          // Language flags or icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLanguageFlag('🇺🇸', 'EN'),
              _buildLanguageFlag('🇨🇳', '中'),
              _buildLanguageFlag('🇯🇵', '日'),
              _buildLanguageFlag('🇰🇷', '한'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage2(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(
              Icons.trending_up,
              size: 50,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 40),
          
          Text(
            AppLocalizations.of(context)!.feature2Title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 20),
          
          Text(
            AppLocalizations.of(context)!.feature2Description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 40),
          
          // Feature highlights
          Column(
            children: [
              _buildFeatureHighlight(Icons.show_chart, AppLocalizations.of(context)!.practiceListening),
              const SizedBox(height: 16),
              _buildFeatureHighlight(Icons.school, AppLocalizations.of(context)!.learnLanguages),
              const SizedBox(height: 16),
              _buildFeatureHighlight(Icons.star, AppLocalizations.of(context)!.improveSkills),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageFlag(String flag, String code) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            flag,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureHighlight(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}