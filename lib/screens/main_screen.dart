import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/logger.dart';
import '../providers/auth_provider.dart';
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

        // Build bottom nav items based on user role
        final List<BottomNavigationBarItem> bottomNavItems = [
          const BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            activeIcon: Icon(Icons.video_library),
            label: 'Channels',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              activeIcon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
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

        return Scaffold(
          body: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
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
            type: BottomNavigationBarType.fixed,
            items: bottomNavItems,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            backgroundColor: Colors.white,
            elevation: 8,
            selectedFontSize: 12,
            unselectedFontSize: 12,
          ),
        );
      },
    );
  }
}
