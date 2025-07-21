import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../providers/video_provider.dart';
import '../models/video.dart';

import '../widgets/video_card.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class VideoListScreen extends StatefulWidget {
  final String channelId;
  final String? channelName;

  const VideoListScreen({super.key, required this.channelId, this.channelName});

  @override
  State<VideoListScreen> createState() => _VideoListScreenState();
}

class _VideoListScreenState extends State<VideoListScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch videos when the screen is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoProvider>().fetchVideos(widget.channelId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.channelName ?? 'Channel Videos',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                'Video List',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          elevation: 2,
          shadowColor: Colors.black26,
          actions: [
            // Refresh button
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                context.read<VideoProvider>().refreshVideos();
              },
            ),
          ],
        ),
        body: Consumer<VideoProvider>(
          builder: (context, videoProvider, child) {
            // Loading state
            if (videoProvider.isLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpinKitFadingCircle(color: Colors.blue, size: 50.0),
                    SizedBox(height: 16),
                    Text(
                      'Loading videos...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // Error state
            if (videoProvider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load videos',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      videoProvider.error!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<VideoProvider>().fetchVideos(
                          widget.channelId,
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final videos = videoProvider
                .sortedVideos; // Use sorted videos instead of unsorted

            // Debug information
            AppLogger.debug(
              '🔍 VideoListScreen: ${videos.length} videos loaded',
            );
            if (videos.isNotEmpty) {
              AppLogger.debug(
                '🔍 First video: ${videos.first.title} (${videos.first.videoId})',
              );
              AppLogger.debug(
                '🔍 Progress for first video: ${videoProvider.getVideoProgress(videos.first.videoId)}',
              );

              // Debug sorting - show first 5 videos with their progress
              AppLogger.debug('🔍 Sorting verification:');
              for (int i = 0; i < videos.length && i < 5; i++) {
                final video = videos[i];
                final progress = videoProvider.getVideoProgress(video.videoId);
                AppLogger.debug('  ${i + 1}. ${video.title} - ${progress}%');
              }
            }

            // Empty state
            if (videos.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No videos found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This channel doesn\'t have any videos yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<VideoProvider>().fetchVideos(
                          widget.channelId,
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            }

            // Videos grid
            return Column(
              children: [
                // Header with video count and progress
                Container(
                  padding: const EdgeInsets.all(AppConstants.defaultPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${videos.length} videos',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_getVideosWithProgress(videos, videoProvider)} in progress / ${_getVideosWithDoneProgress(videos, videoProvider)} done',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.green.shade600),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.channelName ?? 'Channel',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Videos list
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.defaultPadding),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        final progress = videoProvider.getVideoProgress(
                          video.videoId,
                        );

                        return VideoCard(
                          video: video,
                          progress: progress,
                          onTap: () {
                            // Show video details or play video
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Playing ${video.title}'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  int _getVideosWithProgress(List<Video> videos, VideoProvider videoProvider) {
    return videos.where((Video video) {
      final progress = videoProvider.getVideoProgress(video.videoId);
      return progress > 0;
    }).length;
  }

  int _getVideosWithDoneProgress(
    List<Video> videos,
    VideoProvider videoProvider,
  ) {
    return videos.where((Video video) {
      final progress = videoProvider.getVideoProgress(video.videoId);
      return progress >= 100;
    }).length;
  }
}
