import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/video_provider.dart';
import '../providers/auth_provider.dart';
import '../generated/app_localizations.dart';

class VideoListScreen extends StatefulWidget {
  final String channelId;
  final String? channelName;

  const VideoListScreen({super.key, required this.channelId, this.channelName});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'recent'; // recent, alphabetical, progress
  String _progressFilter = 'all'; // all, done, in_progress, not_started
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only fetch videos if user is logged in
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isLoggedIn) {
        context.read<VideoProvider>().fetchVideos(widget.channelId);
      }
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Check if user is logged in
        if (!authProvider.isLoggedIn) {
          return _buildLoginRequiredView(context, theme);
        }

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Column(
            children: [
          // Header section - extends into status bar area
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 2,
              12,
              8,
            ),
            decoration: BoxDecoration(
              color: theme
                  .colorScheme
                  .primaryContainer, // Solid light green matching status bar
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Row - more compact
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                        },
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.channelName ?? AppLocalizations.of(context)!.videos,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Consumer<VideoProvider>(
                            builder: (context, provider, child) {
                              final videos = _getFilteredAndSortedVideos(
                                provider,
                              );
                              return Text(
                                AppLocalizations.of(context)!.videosCount(videos.length),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    _buildActionButtons(theme),
                  ],
                ),

                const SizedBox(height: 8),

                // Search Bar
                _buildSearchBar(theme),
              ],
            ),
          ),

          // Progress Stats (if videos exist)
          Consumer<VideoProvider>(
            builder: (context, provider, child) {
              final videos = _getFilteredAndSortedVideos(provider);
              if (videos.isNotEmpty) {
                return _buildProgressStats(theme, videos, provider);
              }
              return const SizedBox.shrink();
            },
          ),

          // Main Content - takes remaining space with SafeArea for bottom only
          Expanded(
            child: SafeArea(
              top:
                  false, // Don't add safe area at top since we handle it manually
              child: _buildVideoContent(theme),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildLoginRequiredView(BuildContext context, ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Header section - same as normal view
          Container(
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.of(context).padding.top + 2,
              12,
              8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channelName ?? AppLocalizations.of(context)!.videos,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        AppLocalizations.of(context)!.loginRequiredDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Login required content
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 80,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        AppLocalizations.of(context)!.loginRequired,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.loginRequiredDescription,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Navigate directly to login screen
                          context.push('/login');
                        },
                        icon: const Icon(Icons.login),
                        label: Text(AppLocalizations.of(context)!.signIn),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(
              Icons.sort_outlined,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            onPressed: () => _showSortOptions(context),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(
              Icons.refresh_outlined,
              color: theme.colorScheme.primary,
              size: 18,
            ),
            onPressed: () async {
              setState(() {
                _isRefreshing = true;
              });
              try {
                await context.read<VideoProvider>().fetchVideos(widget.channelId);
              } finally {
                if (mounted) {
                  setState(() {
                    _isRefreshing = false;
                  });
                }
              }
              HapticFeedback.lightImpact();
            },
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchVideos,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search_outlined,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
            size: 18,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    size: 16,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
        ),
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildProgressStats(
    ThemeData theme,
    List<dynamic> videos,
    VideoProvider videoProvider,
  ) {
    // Always calculate stats from all videos (not filtered ones)
    final allVideos = videoProvider.sortedVideos;
    final completed = _getVideosWithDoneProgress(allVideos, videoProvider);
    final inProgress = _getVideosWithProgress(allVideos, videoProvider);
    final notStarted = allVideos.length - completed - inProgress;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          _buildStatChip(
            theme,
            '$completed',
            AppLocalizations.of(context)!.done,
            theme.colorScheme.primary,
            'done',
            _progressFilter == 'done',
            completed > 0,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            theme,
            '$inProgress',
            AppLocalizations.of(context)!.inProgress,
            theme.colorScheme.secondary,
            'in_progress',
            _progressFilter == 'in_progress',
            inProgress > 0,
          ),
          const SizedBox(width: 8),
          _buildStatChip(
            theme,
            '$notStarted',
            AppLocalizations.of(context)!.notStarted,
            theme.colorScheme.outline,
            'not_started',
            _progressFilter == 'not_started',
            notStarted > 0,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    ThemeData theme,
    String count,
    String label,
    Color color,
    String filterType,
    bool isSelected,
    bool isClickable,
  ) {
    final effectiveColor = isClickable ? color : theme.colorScheme.outline.withValues(alpha: 0.5);
    
    return Expanded(
      child: GestureDetector(
        onTap: isClickable ? () {
          HapticFeedback.lightImpact();
          setState(() {
            // Toggle filter: if same filter is tapped, set to 'all', otherwise set to the tapped filter
            _progressFilter = _progressFilter == filterType ? 'all' : filterType;
          });
        } : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? effectiveColor : effectiveColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: effectiveColor.withValues(alpha: isSelected ? 1.0 : (isClickable ? 0.3 : 0.2)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                count,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isSelected ? Colors.white : effectiveColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected 
                      ? Colors.white.withValues(alpha: 0.9) 
                      : effectiveColor.withValues(alpha: isClickable ? 0.8 : 0.6),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(ThemeData theme) {
    return Consumer<VideoProvider>(
      builder: (context, videoProvider, child) {
        if ((videoProvider.isLoading && videoProvider.videos.isEmpty) || _isRefreshing) {
          return _buildLoadingState(theme);
        }

        if (videoProvider.error != null) {
          return _buildErrorState(theme, videoProvider.error!);
        }

        final filteredVideos = _getFilteredAndSortedVideos(videoProvider);

        if (filteredVideos.isEmpty) {
          return _buildEmptyState(theme);
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: filteredVideos.length,
          itemBuilder: (context, index) {
            final video = filteredVideos[index];
            return _buildVideoCard(video, index, theme, videoProvider);
          },
        );
      },
    );
  }

  Widget _buildVideoCard(
    dynamic video,
    int index,
    ThemeData theme,
    VideoProvider videoProvider,
  ) {
    final progress = videoProvider.getVideoProgress(video.videoId);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final animationValue = Tween<double>(begin: 0.0, end: 1.0)
            .animate(
              CurvedAnimation(
                parent: _animationController,
                curve: Interval(
                  (index * 0.05).clamp(0.0, 0.8),
                  ((index * 0.05) + 0.2).clamp(0.2, 1.0),
                  curve: Curves.easeOut,
                ),
              ),
            )
            .value
            .clamp(0.0, 1.0);

        return Transform.scale(
          scale: (animationValue * 0.2 + 0.8).clamp(0.8, 1.0),
          child: Opacity(
            opacity: animationValue.clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                // Navigate to dictation screen
                context.pushNamed(
                  'dictation',
                  pathParameters: {
                    'channelId': widget.channelId,
                    'videoId': video.videoId,
                  },
                  extra: {
                    'video': video,
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Thumbnail
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              // Thumbnail Image
                              CachedNetworkImage(
                                imageUrl: video.thumbnailUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(
                                      Icons.video_library_outlined,
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.5),
                                      size: 28,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: theme.colorScheme.outline,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                              // Progress Bar
                              if (progress > 0)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: progress / 100,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _getProgressColor(progress),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              // Play Button
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                              // Progress Badge
                              if (progress > 0)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getProgressColor(progress),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${progress.toInt()}%',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Video Info
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                video.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  _getStatusIcon(progress),
                                  size: 12,
                                  color: _getProgressColor(progress),
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    _getStatusText(progress),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: _getProgressColor(progress),
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitPulse(color: theme.colorScheme.primary, size: 50),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loadingVideos,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.unableToLoadVideos,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () =>
                  context.read<VideoProvider>().fetchVideos(widget.channelId),
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.tryAgain),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.video_library_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? AppLocalizations.of(context)!.noVideosFound
                  : AppLocalizations.of(context)!.noVideosAvailable,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyStateMessage(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _progressFilter != 'all') ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _progressFilter = 'all';
                  });
                },
                child: Text(AppLocalizations.of(context)!.clearFilters),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getEmptyStateMessage() {
    if (_searchQuery.isNotEmpty && _progressFilter != 'all') {
      return AppLocalizations.of(context)!.noVideosMatchFilter;
    } else if (_searchQuery.isNotEmpty) {
      return AppLocalizations.of(context)!.tryAdjustingTerms;
    } else if (_progressFilter != 'all') {
      switch (_progressFilter) {
        case 'done':
          return AppLocalizations.of(context)!.noCompletedVideos;
        case 'in_progress':
          return AppLocalizations.of(context)!.noVideosInProgress;
        case 'not_started':
          return AppLocalizations.of(context)!.noUnstartedVideos;
        default:
          return AppLocalizations.of(context)!.noVideosFound;
      }
    } else {
      return AppLocalizations.of(context)!.channelDoesntHaveVideos;
    }
  }

  List<dynamic> _getFilteredAndSortedVideos(VideoProvider provider) {
    List<dynamic> videos = provider.sortedVideos;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      videos = videos
          .where(
            (video) =>
                video.title.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Apply progress status filter
    if (_progressFilter != 'all') {
      videos = videos.where((video) {
        final progress = provider.getVideoProgress(video.videoId);
        switch (_progressFilter) {
          case 'done':
            return progress >= 100;
          case 'in_progress':
            return progress > 0 && progress < 100;
          case 'not_started':
            return progress == 0;
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'alphabetical':
        videos.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'progress':
        videos.sort((a, b) {
          final progressA = provider.getVideoProgress(a.videoId);
          final progressB = provider.getVideoProgress(b.videoId);
          return progressB.compareTo(progressA);
        });
        break;
      case 'recent':
      default:
        break;
    }

    return videos;
  }

  Color _getProgressColor(double progress) {
    if (progress >= 100) {
      return const Color(0xFF4CAF50);
    } else if (progress > 0) {
      return const Color(0xFF2196F3);
    } else {
      return const Color(0xFF9E9E9E);
    }
  }

  IconData _getStatusIcon(double progress) {
    if (progress >= 100) {
      return Icons.check_circle;
    } else if (progress > 0) {
      return Icons.play_circle_outline;
    } else {
      return Icons.play_circle_outline;
    }
  }

  String _getStatusText(double progress) {
    if (progress >= 100) {
      return AppLocalizations.of(context)!.completed;
    } else if (progress > 0) {
      return AppLocalizations.of(context)!.inProgress;
    } else {
      return AppLocalizations.of(context)!.notStarted;
    }
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.sortVideos,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSortOption(
                      AppLocalizations.of(context)!.recent,
                      'recent',
                      Icons.access_time,
                      theme,
                    ),
                    _buildSortOption(
                      AppLocalizations.of(context)!.alphabetical,
                      'alphabetical',
                      Icons.sort_by_alpha,
                      theme,
                    ),
                    _buildSortOption(
                      AppLocalizations.of(context)!.progress,
                      'progress',
                      Icons.trending_up,
                      theme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(
    String title,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    final isSelected = _sortBy == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _sortBy = value;
          });
          Navigator.pop(context);
          HapticFeedback.lightImpact();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  int _getVideosWithProgress(
    List<dynamic> videos,
    VideoProvider videoProvider,
  ) {
    return videos.where((video) {
      final progress = videoProvider.getVideoProgress(video.videoId);
      return progress > 0 && progress < 100;
    }).length;
  }

  int _getVideosWithDoneProgress(
    List<dynamic> videos,
    VideoProvider videoProvider,
  ) {
    return videos.where((video) {
      final progress = videoProvider.getVideoProgress(video.videoId);
      return progress >= 100;
    }).length;
  }
}
