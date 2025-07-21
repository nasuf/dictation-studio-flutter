import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/logger.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load admin stats when screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.loadAdminStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          // Refresh button
          Consumer<AdminProvider>(
            builder: (context, adminProvider, child) {
              return IconButton(
                icon: adminProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: adminProvider.isLoading
                    ? null
                    : () => adminProvider.refreshAdminStats(),
                tooltip: 'Refresh Statistics',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Handle admin settings
            },
          ),
        ],
      ),
      body: Consumer2<AdminProvider, AuthProvider>(
        builder: (context, adminProvider, authProvider, child) {
          // Show access denied if not admin
          if (!authProvider.isLoggedIn ||
              authProvider.currentUser?.role != 'Admin') {
            return _buildAccessDeniedView(context);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error handling
                if (adminProvider.error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade600),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            adminProvider.error!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                        TextButton(
                          onPressed: () => adminProvider.refreshAdminStats(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),

                // Quick Stats Section
                _buildQuickStatsSection(context, adminProvider),
                const SizedBox(height: 20),

                // Management Section
                _buildManagementSection(context),
                const SizedBox(height: 20),

                // System Section
                _buildSystemSection(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccessDeniedView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Access Denied',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You need admin privileges to access this page.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsSection(
    BuildContext context,
    AdminProvider adminProvider,
  ) {
    final stats = adminProvider.adminStats;
    final isLoading = adminProvider.isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quick Stats',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Users',
                    isLoading ? '-' : (stats?.totalUsers.toString() ?? '0'),
                    Icons.people,
                    Colors.blue,
                    isLoading: isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Active Users',
                    isLoading ? '-' : (stats?.activeUsers.toString() ?? '0'),
                    Icons.person_outline,
                    Colors.green,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Channels',
                    isLoading ? '-' : (stats?.totalChannels.toString() ?? '0'),
                    Icons.video_library,
                    Colors.orange,
                    isLoading: isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    'Total Videos',
                    isLoading ? '-' : (stats?.totalVideos.toString() ?? '0'),
                    Icons.videocam,
                    Colors.purple,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Content Management',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          _buildManagementItem(
            context,
            Icons.video_library,
            'Manage Channels',
            'Add, edit, or remove channels',
            () {
              AppLogger.info('📺 Manage Channels tapped');
              context.push('/admin/channels');
            },
          ),
          _buildManagementItem(
            context,
            Icons.videocam,
            'Manage Videos',
            'Upload and organize videos',
            () {
              AppLogger.info('🎬 Manage Videos tapped');
              context.push('/admin/videos');
            },
          ),
          _buildManagementItem(
            context,
            Icons.people,
            'Manage Users',
            'View and manage user accounts',
            () {
              AppLogger.info('👥 User Management tapped');
              context.push('/admin/users');
            },
          ),
          _buildManagementItem(
            context,
            Icons.analytics,
            'Analytics',
            'View usage statistics and reports',
            () {
              AppLogger.info('📊 Analytics tapped');
              context.push('/admin/analytics');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSystemSection(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'System',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          _buildManagementItem(
            context,
            Icons.backup,
            'Backup & Restore',
            'Manage system backups',
            () {
              AppLogger.info('💾 Backup & Restore tapped');
              // TODO: Navigate to backup management
            },
          ),
          _buildManagementItem(
            context,
            Icons.security,
            'Security Settings',
            'Configure security policies',
            () {
              AppLogger.info('🔒 Security Settings tapped');
              // TODO: Navigate to security settings
            },
          ),
          _buildManagementItem(
            context,
            Icons.bug_report,
            'System Logs',
            'View system logs and errors',
            () {
              AppLogger.info('📋 System Logs tapped');
              // TODO: Navigate to system logs
            },
          ),
          _buildManagementItem(
            context,
            Icons.update,
            'System Updates',
            'Check for updates',
            () {
              AppLogger.info('⬆️ System Updates tapped');
              // TODO: Navigate to system updates
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManagementItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
