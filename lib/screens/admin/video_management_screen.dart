import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/video.dart';
import '../../models/channel.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';
import 'dart:async';

class VideoManagementScreen extends StatefulWidget {
  const VideoManagementScreen({super.key});

  @override
  State<VideoManagementScreen> createState() => _VideoManagementScreenState();
}

class _VideoManagementScreenState extends State<VideoManagementScreen>
    with TickerProviderStateMixin {
  // Core state
  String? _selectedChannelId;
  String _selectedLanguage = AppConstants.languageAll;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  // Data
  List<Channel> _channels = [];
  List<Video> _videos = [];
  // List<TranscriptItem> _currentTranscript = []; // Removed unused field

  // Services
  final ApiService _apiService = ApiService();

  // Modal states - removed unused fields
  // bool _isAddVideoModalOpen = false;
  // bool _isEditVideoModalOpen = false;
  // bool _isTranscriptModalOpen = false;
  // Video? _editingVideo;
  // Video? _transcriptVideo;

  // Debounce timer
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load initial data without triggering widget rebuild during initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Load initial data
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _loadChannels();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load initial data: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load channels
  Future<void> _loadChannels() async {
    try {
      final channels = await _apiService.getChannels(
        visibility: AppConstants.visibilityAll,
        language: _selectedLanguage == AppConstants.languageAll
            ? AppConstants.languageAll
            : _selectedLanguage,
      );

      if (mounted) {
        setState(() {
          _channels = channels;
          // Auto-select first channel if none selected
          if (_selectedChannelId == null && channels.isNotEmpty) {
            _selectedChannelId = channels.first.id;
            // Load videos for the selected channel
            Future.microtask(() => _loadVideos());
          }
        });
      }
    } catch (e) {
      AppLogger.error('Error loading channels: $e');
      rethrow;
    }
  }

  // Load videos for selected channel
  Future<void> _loadVideos() async {
    if (_selectedChannelId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getVideoList(
        _selectedChannelId!,
        visibility: AppConstants.visibilityAll,
        language: _selectedLanguage == AppConstants.languageAll
            ? null
            : _selectedLanguage,
      );

      if (mounted) {
        setState(() {
          _videos = response.videos;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading videos: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load videos: $e';
          _isLoading = false;
        });
      }
    }
  }

  // Debounced search
  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
      }
    });
  }

  // Filter videos based on search query
  List<Video> get _filteredVideos {
    if (_searchQuery.isEmpty) return _videos;

    return _videos.where((video) {
      return video.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          video.videoId.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // Handle channel selection
  void _onChannelChanged(String? channelId) {
    if (channelId != null && channelId != _selectedChannelId) {
      setState(() {
        _selectedChannelId = channelId;
        _videos = []; // Clear videos while loading new ones
      });
      _loadVideos();
    }
  }

  // Handle language filter change
  void _onLanguageChanged(String? language) {
    if (language != null && language != _selectedLanguage) {
      setState(() {
        _selectedLanguage = language;
        _channels = []; // Clear channels while loading new ones
        _videos = [];
        _selectedChannelId = null;
      });
      _loadChannels();
    }
  }

  // Show add video modal
  void _showAddVideoModal() {
    if (_selectedChannelId == null) {
      _showErrorSnackBar('Please select a channel first');
      return;
    }
    setState(() {
      // _isAddVideoModalOpen = true; // Removed unused field
    });
  }

  // Show edit video modal
  void _showEditVideoModal(Video video) {
    setState(() {
      // _editingVideo = video; // Removed unused field
    });
  }

  // Show transcript modal
  void _showTranscriptModal(Video video) {
    setState(() {
      // _transcriptVideo = video; // Removed unused field
    });
    _loadTranscript(video);
  }

  // Load transcript for video
  Future<void> _loadTranscript(Video video) async {
    if (_selectedChannelId == null) return;

    try {
      // TODO: Implement transcript loading when API is available
      AppLogger.info('Loading transcript for video: ${video.videoId}');

      // Placeholder - simulate loading transcript
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          // _currentTranscript = [ // Removed unused field
          //   TranscriptItem(
          //     start: 0.0,
          //     end: 5.0,
          //     transcript: 'Transcript loading feature coming soon...',
          //   ),
          // ];
        });
      }
    } catch (e) {
      AppLogger.error('Error loading transcript: $e');
      _showErrorSnackBar('Failed to load transcript: $e');
    }
  }

  // Delete video
  Future<void> _deleteVideo(Video video) async {
    if (_selectedChannelId == null) return;

    final confirmed = await _showConfirmDialog(
      'Delete Video',
      'Are you sure you want to delete "${video.title}"? This action cannot be undone.',
    );

    if (!confirmed) return;

    try {
      // TODO: Implement video deletion when API is available
      AppLogger.info('Deleting video: ${video.videoId}');

      // Placeholder - simulate deletion
      await Future.delayed(const Duration(seconds: 1));
      _showSuccessSnackBar('Delete functionality coming soon');
      // await _loadVideos(); // Refresh video list when API is available
    } catch (e) {
      AppLogger.error('Error deleting video: $e');
      _showErrorSnackBar('Failed to delete video: $e');
    }
  }

  // Update video visibility
  Future<void> _updateVideoVisibility(Video video, String newVisibility) async {
    if (_selectedChannelId == null) return;

    try {
      // TODO: Implement video visibility update when API is available
      AppLogger.info(
        'Updating video ${video.videoId} visibility to $newVisibility',
      );

      // Placeholder - simulate update
      await Future.delayed(const Duration(seconds: 1));
      _showSuccessSnackBar('Visibility update functionality coming soon');
      // await _loadVideos(); // Refresh video list when API is available
    } catch (e) {
      AppLogger.error('Error updating video visibility: $e');
      _showErrorSnackBar('Failed to update video visibility: $e');
    }
  }

  // Launch video URL
  Future<void> _launchVideoUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.error('Error launching URL: $e');
      _showErrorSnackBar('Failed to open video link');
    }
  }

  // Show success snackbar
  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Show confirmation dialog
  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Videos', icon: Icon(Icons.video_library)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Settings', icon: Icon(Icons.settings)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVideosTab(),
          _buildAnalyticsTab(),
          _buildSettingsTab(),
        ],
      ),
      floatingActionButton: _selectedChannelId != null
          ? FloatingActionButton.extended(
              onPressed: _showAddVideoModal,
              icon: const Icon(Icons.add),
              label: const Text('Add Video'),
            )
          : null,
    );
  }

  // Build videos tab
  Widget _buildVideosTab() {
    return Column(
      children: [
        // Filters section
        _buildFiltersSection(),

        // Content area
        Expanded(child: _buildVideoContent()),
      ],
    );
  }

  // Build filters section
  Widget _buildFiltersSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Channel and language selection row
          Row(
            children: [
              // Language dropdown
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedLanguage,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: AppConstants.languageOptions.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.value,
                          child: Text(
                            entry.key,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onLanguageChanged,
                ),
              ),
              const SizedBox(width: 8),
              // Channel dropdown
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedChannelId,
                  decoration: const InputDecoration(
                    labelText: 'Channel',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: _channels
                      .map(
                        (channel) => DropdownMenuItem(
                          value: channel.id,
                          child: SizedBox(
                            width: double.infinity,
                            child: Text(
                              channel.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onChannelChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search bar
          SizedBox(
            width: double.infinity,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search videos...',
                hintText: 'Enter video title or ID',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: _onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }

  // Build video content area
  Widget _buildVideoContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading videos...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadVideos, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_selectedChannelId == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Select a channel to manage videos'),
          ],
        ),
      );
    }

    final filteredVideos = _filteredVideos;

    if (filteredVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(_videos.isEmpty ? 'No videos found' : 'No matching videos'),
            const SizedBox(height: 8),
            Text(
              _videos.isEmpty
                  ? 'Add your first video to get started'
                  : 'Try adjusting your search terms',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return _buildVideoList(filteredVideos);
  }

  // Build video list
  Widget _buildVideoList(List<Video> videos) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _buildVideoCard(video);
      },
    );
  }

  // Build video card
  Widget _buildVideoCard(Video video) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video title and actions
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${video.videoId}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleVideoAction(video, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view_transcript',
                      child: Row(
                        children: [
                          Icon(Icons.description),
                          SizedBox(width: 8),
                          Text('View Transcript'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Edit Video'),
                        ],
                      ),
                    ),
                    if (video.link.isNotEmpty)
                      const PopupMenuItem(
                        value: 'open_link',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new),
                            SizedBox(width: 8),
                            Text('Open Link'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'visibility_public',
                      child: Row(
                        children: [
                          Icon(
                            Icons.public,
                            color: video.visibility == 'public'
                                ? Colors.green
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text('Set Public'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'visibility_private',
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: video.visibility == 'private'
                                ? Colors.orange
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text('Set Private'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Video metadata
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    video.visibility.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: video.visibility == 'public'
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Chip(
                  label: Text(
                    _formatDate(video.createdDate),
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                if (video.link.isNotEmpty)
                  Chip(
                    label: const Text(
                      'HAS LINK',
                      style: TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.blue.withValues(alpha: 0.2),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Handle video actions
  void _handleVideoAction(Video video, String action) {
    switch (action) {
      case 'view_transcript':
        _showTranscriptModal(video);
        break;
      case 'edit':
        _showEditVideoModal(video);
        break;
      case 'open_link':
        if (video.link.isNotEmpty) {
          _launchVideoUrl(video.link);
        }
        break;
      case 'visibility_public':
        _updateVideoVisibility(video, 'public');
        break;
      case 'visibility_private':
        _updateVideoVisibility(video, 'private');
        break;
      case 'delete':
        _deleteVideo(video);
        break;
    }
  }

  // Build analytics tab (placeholder)
  Widget _buildAnalyticsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Analytics feature coming soon'),
        ],
      ),
    );
  }

  // Build settings tab (placeholder)
  Widget _buildSettingsTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Settings feature coming soon'),
        ],
      ),
    );
  }

  // Format date
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
