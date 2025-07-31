import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/logger.dart';
import '../providers/auth_provider.dart';
import '../generated/app_localizations.dart';
import 'channel_list_screen.dart';
import 'profile_screen.dart';
import 'admin_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info('MainScreen build called');

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Determine if admin tab should be shown
        final bool isAdmin =
            authProvider.isLoggedIn &&
            authProvider.currentUser?.role == 'Admin';

        // Build screens list based on user role
        final List<Widget> screens = [
          const ChannelListScreen(),
          const ProfileScreen(),
          if (isAdmin) const AdminScreen(),
        ];

        // Build navigation destinations based on user role (Material Design 3)
        final List<NavigationDestination> navDestinations = [
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library),
            label: AppLocalizations.of(context)!.channels,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: AppLocalizations.of(context)!.profile,
          ),
          if (isAdmin)
            NavigationDestination(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: const Icon(Icons.admin_panel_settings),
              label: AppLocalizations.of(context)!.admin,
            ),
        ];

        // Adjust current index if admin tab is removed and we were on it
        if (!isAdmin && _currentIndex >= 2) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _currentIndex = 1; // Go to profile tab
            });
            _pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        }

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0A0B) : null,
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
              // Animate to the selected page
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            destinations: navDestinations,
            elevation: isDark ? 0 : 2,
            backgroundColor: isDark ? const Color(0xFF1C1C1E) : null,
            shadowColor: isDark ? Colors.transparent : theme.colorScheme.shadow,
            surfaceTintColor: isDark ? Colors.transparent : theme.colorScheme.surfaceContainerHighest,
            indicatorColor: isDark ? const Color(0xFF007AFF).withValues(alpha: 0.2) : null,
          ),
        );
      },
    );
  }
}
