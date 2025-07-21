import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../utils/logger.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _selectedPeriod = '7 days';
  bool _isLoading = true;

  // Mock analytics data
  final Map<String, dynamic> _analyticsData = {
    'userActivity': {
      'totalSessions': 1250,
      'activeUsers': 342,
      'newUsers': 87,
      'avgSessionDuration': 1842, // seconds
    },
    'contentUsage': {
      'totalVideosWatched': 3421,
      'totalWatchTime': 125400, // seconds
      'popularChannels': [
        {'name': 'English Learning', 'views': 890},
        {'name': 'Business English', 'views': 567},
        {'name': 'Daily Conversation', 'views': 432},
      ],
      'popularLanguages': [
        {'language': 'English', 'usage': 78.5},
        {'language': 'Chinese', 'usage': 12.3},
        {'language': 'Japanese', 'usage': 6.8},
        {'language': 'Korean', 'usage': 2.4},
      ],
    },
    'engagement': {
      'completionRate': 73.2,
      'averageProgress': 68.5,
      'retentionRate': 82.1,
    },
    'technical': {
      'platformDistribution': [
        {'platform': 'Android', 'percentage': 65.2},
        {'platform': 'iOS', 'percentage': 28.7},
        {'platform': 'Web', 'percentage': 6.1},
      ],
      'errorRate': 0.8,
      'averageLoadTime': 2.3,
    },
  };

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.info('Loading analytics for period: $_selectedPeriod');

      // Simulate API call
      await Future.delayed(const Duration(seconds: 1));

      AppLogger.info('Analytics loaded successfully');
    } catch (e) {
      AppLogger.error('Failed to load analytics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load analytics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range),
            initialValue: _selectedPeriod,
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
              _loadAnalytics();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: '1 day', child: Text('Last 24 hours')),
              const PopupMenuItem(value: '7 days', child: Text('Last 7 days')),
              const PopupMenuItem(
                value: '30 days',
                child: Text('Last 30 days'),
              ),
              const PopupMenuItem(
                value: '90 days',
                child: Text('Last 3 months'),
              ),
            ],
            tooltip: 'Select Time Period',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Header
                  Text(
                    'Analytics for $_selectedPeriod',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Overview Cards
                  _buildOverviewSection(),
                  const SizedBox(height: 24),

                  // User Activity Section
                  _buildUserActivitySection(),
                  const SizedBox(height: 24),

                  // Content Usage Section
                  _buildContentUsageSection(),
                  const SizedBox(height: 24),

                  // Engagement Metrics
                  _buildEngagementSection(),
                  const SizedBox(height: 24),

                  // Technical Metrics
                  _buildTechnicalSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewSection() {
    return Consumer<AdminProvider>(
      builder: (context, adminProvider, child) {
        final stats = adminProvider.adminStats;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  'Total Users',
                  stats?.totalUsers.toString() ?? '0',
                  Icons.people,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'Active Users',
                  stats?.activeUsers.toString() ?? '0',
                  Icons.person_outline,
                  Colors.green,
                ),
                _buildMetricCard(
                  'Total Channels',
                  stats?.totalChannels.toString() ?? '0',
                  Icons.video_library,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Total Videos',
                  stats?.totalVideos.toString() ?? '0',
                  Icons.play_circle_outline,
                  Colors.purple,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserActivitySection() {
    final userActivity = _analyticsData['userActivity'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'User Activity',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActivityRow(
                  'Total Sessions',
                  _formatNumber(userActivity['totalSessions']),
                  Icons.analytics,
                ),
                const Divider(),
                _buildActivityRow(
                  'New Users',
                  _formatNumber(userActivity['newUsers']),
                  Icons.person_add,
                ),
                const Divider(),
                _buildActivityRow(
                  'Avg Session Duration',
                  _formatDuration(userActivity['avgSessionDuration']),
                  Icons.timer,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentUsageSection() {
    final contentUsage = _analyticsData['contentUsage'] as Map<String, dynamic>;
    final popularChannels = contentUsage['popularChannels'] as List<dynamic>;
    final popularLanguages = contentUsage['popularLanguages'] as List<dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content Usage',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Usage Stats
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActivityRow(
                  'Videos Watched',
                  _formatNumber(contentUsage['totalVideosWatched']),
                  Icons.play_arrow,
                ),
                const Divider(),
                _buildActivityRow(
                  'Total Watch Time',
                  _formatDuration(contentUsage['totalWatchTime']),
                  Icons.schedule,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Popular Channels
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Popular Channels',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...popularChannels.map(
                  (channel) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(channel['name'])),
                        Text(
                          '${channel['views']} views',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Language Distribution
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Language Usage',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...popularLanguages.map(
                  (language) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(language['language']),
                            Text(
                              '${language['usage'].toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: language['usage'] / 100,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementSection() {
    final engagement = _analyticsData['engagement'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Engagement Metrics',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildEngagementMetric(
                  'Completion Rate',
                  engagement['completionRate'],
                  Colors.green,
                ),
                const SizedBox(height: 16),
                _buildEngagementMetric(
                  'Average Progress',
                  engagement['averageProgress'],
                  Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildEngagementMetric(
                  'Retention Rate',
                  engagement['retentionRate'],
                  Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalSection() {
    final technical = _analyticsData['technical'] as Map<String, dynamic>;
    final platformDistribution =
        technical['platformDistribution'] as List<dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Technical Metrics',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Technical Stats
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActivityRow(
                  'Error Rate',
                  '${technical['errorRate']}%',
                  Icons.error_outline,
                ),
                const Divider(),
                _buildActivityRow(
                  'Avg Load Time',
                  '${technical['averageLoadTime']}s',
                  Icons.speed,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Platform Distribution
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform Distribution',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...platformDistribution.map(
                  (platform) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(platform['platform'])),
                        Text(
                          '${platform['percentage'].toStringAsFixed(1)}%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEngagementMetric(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / 100,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}
