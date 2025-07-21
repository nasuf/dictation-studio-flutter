import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import '../providers/channel_provider.dart';
import '../widgets/channel_card.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class ChannelListScreen extends StatefulWidget {
  const ChannelListScreen({super.key});

  @override
  State<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends State<ChannelListScreen> {
  String _selectedLanguage = AppConstants.languageAll;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    // Only fetch once during initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized) {
        _hasInitialized = true;
        context.read<ChannelProvider>().fetchChannels();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info('ChannelListScreen build called');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictation Channels'),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          // Language filter button
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => _showLanguageFilter(context),
            tooltip: 'Filter by Language',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ChannelProvider>().fetchChannels();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<ChannelProvider>(
        builder: (context, channelProvider, child) {
          if (channelProvider.isLoading && channelProvider.channels.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitFadingCircle(color: Colors.blue, size: 50.0),
                  SizedBox(height: 16),
                  Text(
                    'Loading channels...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (channelProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading channels',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    channelProvider.error!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => channelProvider.fetchChannels(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (channelProvider.channels.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No channels available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Filter channels by selected language
          final filteredChannels = _selectedLanguage == AppConstants.languageAll
              ? channelProvider.channels
              : channelProvider.channels
                    .where((channel) => channel.language == _selectedLanguage)
                    .toList();

          return RefreshIndicator(
            onRefresh: () async {
              await channelProvider.fetchChannels();
            },
            child: CustomScrollView(
              slivers: [
                // Language filter section
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Language: ${LanguageHelper.getLanguageName(_selectedLanguage)}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Text(
                          '${filteredChannels.length} ${filteredChannels.length == 1 ? 'channel' : 'channels'}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Channels grid
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    itemBuilder: (context, index) {
                      final channel = filteredChannels[index];
                      return ChannelCard(
                        channel: channel,
                        onTap: () {
                          // Navigate to video list without auth requirement
                          context.push(
                            '/videos/${channel.id}',
                            extra: {'channelName': channel.name},
                          );
                        },
                      );
                    },
                    childCount: filteredChannels.length,
                  ),
                ),

                // Add some bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLanguageFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by Language',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('All Languages'),
                trailing: _selectedLanguage == AppConstants.languageAll
                    ? const Icon(Icons.check, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedLanguage = AppConstants.languageAll;
                  });
                  context.read<ChannelProvider>().setLanguageFilter(
                    _selectedLanguage,
                  );
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ...LanguageHelper.getSupportedLanguages().map(
                (language) => ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: _getLanguageColor(language),
                  ),
                  title: Text(LanguageHelper.getLanguageName(language)),
                  trailing: _selectedLanguage == language
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedLanguage = language;
                    });
                    context.read<ChannelProvider>().setLanguageFilter(
                      _selectedLanguage,
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Get language color for visual distinction
  Color _getLanguageColor(String language) {
    switch (language) {
      case AppConstants.languageEnglish:
        return Colors.blue;
      case AppConstants.languageChinese:
        return Colors.red;
      case AppConstants.languageJapanese:
        return Colors.pink;
      case AppConstants.languageKorean:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
