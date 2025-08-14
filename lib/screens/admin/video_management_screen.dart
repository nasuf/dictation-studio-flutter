import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/video.dart';
import '../../models/channel.dart';
import '../../models/transcript_item.dart';
import '../../models/analytics.dart';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';
import 'video_transcript_editor_screen.dart';
import 'add_video_screen.dart';
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
  Analytics? _analytics;
  bool _isLoadingAnalytics = false;
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
    
    // Add listener for tab changes to load analytics when analytics tab is selected
    _tabController.addListener(() {
      if (_tabController.index == 1 && _analytics == null && !_isLoadingAnalytics) {
        // Analytics tab selected and data not loaded yet
        _loadAnalytics();
      }
    });

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

  // Load analytics data
  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoadingAnalytics = true;
    });

    try {
      final analyticsData = await _apiService.getAnalytics();
      if (mounted) {
        setState(() {
          _analytics = Analytics.fromJson(analyticsData);
          _isLoadingAnalytics = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _isLoadingAnalytics = false;
        });
        _showErrorSnackBar('Failed to load analytics: $e');
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

  // Navigate to add video screen
  void _showAddVideoModal() async {
    if (_selectedChannelId == null) {
      _showErrorSnackBar('Please select a channel first');
      return;
    }
    
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AddVideoScreen(channelId: _selectedChannelId!),
      ),
    );
    
    // If videos were successfully added, refresh the list
    if (result == true) {
      _loadVideos();
    }
  }

  // Show edit video modal
  void _showEditVideoModal(Video video) async {
    final titleController = TextEditingController(text: video.title);
    final linkController = TextEditingController(text: video.link);
    String selectedVisibility = video.visibility;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Video'),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video ID: ${video.videoId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Video Title',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: linkController,
                      decoration: const InputDecoration(
                        labelText: 'Video Link',
                        border: OutlineInputBorder(),
                        hintText: 'https://www.youtube.com/watch?v=...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedVisibility,
                      decoration: const InputDecoration(
                        labelText: 'Visibility',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'public',
                          child: Row(
                            children: [
                              Icon(Icons.public, size: 18),
                              SizedBox(width: 8),
                              Text('Public'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'private',
                          child: Row(
                            children: [
                              Icon(Icons.lock, size: 18),
                              SizedBox(width: 8),
                              Text('Private'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedVisibility = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final updatedData = <String, dynamic>{};
                    
                    if (titleController.text != video.title) {
                      updatedData['title'] = titleController.text;
                    }
                    
                    if (linkController.text != video.link) {
                      updatedData['link'] = linkController.text;
                    }
                    
                    if (selectedVisibility != video.visibility) {
                      updatedData['visibility'] = selectedVisibility;
                    }
                    
                    Navigator.of(context).pop(updatedData);
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
    
    titleController.dispose();
    linkController.dispose();
    
    if (result != null && result.isNotEmpty) {
      await _updateVideo(video, result);
    }
  }
  
  // Toggle video refined status
  Future<void> _toggleVideoRefined(Video video, bool isRefined) async {
    if (_selectedChannelId == null) return;
    
    try {
      AppLogger.info('Toggling video ${video.videoId} refined status to $isRefined');
      await _apiService.markVideoRefined(_selectedChannelId!, video.videoId, isRefined);
      _showSuccessSnackBar('Video marked as ${isRefined ? 'refined' : 'unrefined'}');
      await _loadVideos(); // Refresh video list
    } catch (e) {
      AppLogger.error('Error toggling video refined status: $e');
      _showErrorSnackBar('Failed to update refined status: $e');
    }
  }
  
  // Update video with given data
  Future<void> _updateVideo(Video video, Map<String, dynamic> updateData) async {
    if (_selectedChannelId == null) return;
    
    try {
      AppLogger.info('Updating video ${video.videoId} with data: $updateData');
      await _apiService.updateVideo(_selectedChannelId!, video.videoId, updateData);
      
      final List<String> updatedFields = [];
      if (updateData.containsKey('title')) {
        updatedFields.add('title');
      }
      if (updateData.containsKey('link')) {
        updatedFields.add('link');
      }
      if (updateData.containsKey('visibility')) {
        updatedFields.add('visibility');
      }
      
      _showSuccessSnackBar('Video ${updatedFields.join(" and ")} updated successfully');
      await _loadVideos(); // Refresh video list
    } catch (e) {
      AppLogger.error('Error updating video: $e');
      _showErrorSnackBar('Failed to update video: $e');
    }
  }

  // Show transcript editor
  void _showTranscriptEditor(Video video) async {
    if (_selectedChannelId == null) return;

    try {
      AppLogger.info('Opening transcript editor for video: ${video.videoId}');

      // Load or create initial transcript
      final transcript = await _loadTranscript(video);

      if (mounted) {
        final result = await Navigator.of(context).push<List<TranscriptItem>>(
          MaterialPageRoute(
            builder: (context) => VideoTranscriptEditorScreen(
              video: video,
              channelId: _selectedChannelId!,
              initialTranscript: transcript,
            ),
          ),
        );

        if (result != null) {
          // Transcript was saved, show success message
          _showSuccessSnackBar(
            'Transcript updated with ${result.length} segments',
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error opening transcript editor: $e');
      _showErrorSnackBar('Failed to open transcript editor: $e');
    }
  }

  // Load transcript for video
  Future<List<TranscriptItem>> _loadTranscript(Video video) async {
    try {
      AppLogger.info('Loading transcript for video: ${video.videoId}');

      // Use real API to load transcript
      final transcriptItems = await _apiService.getVideoTranscriptItems(
        _selectedChannelId!,
        video.videoId,
      );

      AppLogger.info('Loaded ${transcriptItems.length} transcript items');
      return transcriptItems;
    } catch (e) {
      AppLogger.error('Error loading transcript: $e');

      // Show error to user
      if (mounted) {
        _showErrorSnackBar('Failed to load transcript: ${e.toString()}');
      }

      // Return empty list to allow manual transcript creation
      return [];
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
      AppLogger.info('Deleting video: ${video.videoId}');
      await _apiService.deleteVideo(_selectedChannelId!, video.videoId);
      _showSuccessSnackBar('Video deleted successfully');
      await _loadVideos(); // Refresh video list
    } catch (e) {
      AppLogger.error('Error deleting video: $e');
      _showErrorSnackBar('Failed to delete video: $e');
    }
  }

  // Update video visibility
  Future<void> _updateVideoVisibility(Video video, String newVisibility) async {
    if (_selectedChannelId == null) return;

    try {
      AppLogger.info(
        'Updating video ${video.videoId} visibility to $newVisibility',
      );

      await _apiService.updateVideo(_selectedChannelId!, video.videoId, {
        'visibility': newVisibility,
      });
      _showSuccessSnackBar('Video visibility updated to $newVisibility');
      await _loadVideos(); // Refresh video list
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
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: theme.colorScheme.primary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: theme.colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Show confirmation dialog
  Future<bool> _showConfirmDialog(String title, String content) async {
    final theme = Theme.of(context);
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
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0B) : theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Video Management',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFE8E8EA) : null,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A1D) : theme.colorScheme.surface,
        foregroundColor: isDark ? const Color(0xFFE8E8EA) : theme.colorScheme.onSurface,
        elevation: isDark ? 0 : 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: isDark ? const Color(0xFF007AFF) : theme.colorScheme.primary,
          unselectedLabelColor: isDark 
            ? const Color(0xFF8E8E93)
            : theme.colorScheme.onSurfaceVariant,
          indicatorColor: isDark ? const Color(0xFF007AFF) : theme.colorScheme.primary,
          dividerColor: isDark ? const Color(0xFF3A3A3F).withValues(alpha: 0.3) : null,
          tabs: const [
            Tab(text: 'Videos', icon: Icon(Icons.video_library)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
            Tab(text: 'Settings', icon: Icon(Icons.settings)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh based on current tab
              if (_tabController.index == 0) {
                _loadVideos();
              } else if (_tabController.index == 1) {
                _loadAnalytics();
              }
            },
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
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

          // Channel statistics (only show when channel is selected and videos are loaded)
          if (_selectedChannelId != null && !_isLoading && _error == null) ...[
            const SizedBox(height: 12),
            _buildChannelStats(theme),
          ],
        ],
      ),
    );
  }

  // Build video content area
  Widget _buildVideoContent() {
    final theme = Theme.of(context);
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
            Icon(Icons.error, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadVideos, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_selectedChannelId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            const Text('Select a channel to manage videos'),
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
            Icon(
              Icons.video_library_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(_videos.isEmpty ? 'No videos found' : 'No matching videos'),
            const SizedBox(height: 8),
            Text(
              _videos.isEmpty
                  ? 'Add your first video to get started'
                  : 'Try adjusting your search terms',
              style: TextStyle(color: theme.colorScheme.outline),
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
    final theme = Theme.of(context);
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
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
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
                                ? theme.colorScheme.primary
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
                                ? theme.colorScheme.secondary
                                : null,
                          ),
                          const SizedBox(width: 8),
                          const Text('Set Private'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: video.isRefined ? 'mark_unrefined' : 'mark_refined',
                      child: Row(
                        children: [
                          Icon(
                            video.isRefined ? Icons.remove_circle_outline : Icons.check_circle_outline,
                            color: video.isRefined 
                                ? theme.colorScheme.error 
                                : theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            video.isRefined ? 'Mark Unrefined' : 'Mark Refined',
                            style: TextStyle(
                              color: video.isRefined 
                                  ? theme.colorScheme.error 
                                  : theme.colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Video metadata - simplified
            Row(
              children: [
                Chip(
                  label: Text(
                    video.visibility.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: video.visibility == 'public'
                      ? theme.colorScheme.primary.withOpacity(0.2)
                      : theme.colorScheme.secondary.withOpacity(0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                // Refined status chip
                Chip(
                  label: Text(
                    video.isRefined ? 'REFINED' : 'UNREFINED',
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: video.isRefined
                      ? theme.colorScheme.surface.withOpacity(0.8)
                      : theme.colorScheme.error.withOpacity(0.2),
                  side: video.isRefined
                      ? BorderSide(color: theme.colorScheme.outline)
                      : null,
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
        _showTranscriptEditor(video);
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
      case 'mark_refined':
        _toggleVideoRefined(video, true);
        break;
      case 'mark_unrefined':
        _toggleVideoRefined(video, false);
        break;
      case 'delete':
        _deleteVideo(video);
        break;
    }
  }

  // Build analytics tab
  Widget _buildAnalyticsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoadingAnalytics) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading analytics...'),
          ],
        ),
      );
    }

    if (_analytics == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            const Text('Failed to load analytics'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalytics,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary section
          _buildAnalyticsSummarySection(theme, isDark),
          
          const SizedBox(height: 24),
          
          // Channel breakdown section
          _buildChannelBreakdownSection(theme, isDark),
        ],
      ),
    );
  }

  // Build analytics summary section
  Widget _buildAnalyticsSummarySection(ThemeData theme, bool isDark) {
    final summary = _analytics!.summary;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Video Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Total videos
            _buildSummaryRow(
              theme,
              'Total Videos',
              summary.totalVideos,
              Colors.blue,
              Icons.video_library,
            ),
            
            const Divider(height: 24),
            
            // Visibility breakdown
            Text(
              'By Visibility',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildSummaryRow(
              theme,
              'Public Videos',
              summary.publicVideos,
              Colors.green,
              Icons.public,
            ),
            
            _buildSummaryRow(
              theme,
              'Private Videos',
              summary.privateVideos,
              Colors.orange,
              Icons.lock,
            ),
            
            const Divider(height: 24),
            
            // Refined status breakdown
            Text(
              'By Refinement Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildSummaryRow(
              theme,
              'Refined Videos',
              summary.refinedVideos,
              Colors.teal,
              Icons.check_circle,
            ),
            
            _buildSummaryRow(
              theme,
              'Unrefined Videos',
              summary.unrefinedVideos,
              Colors.red,
              Icons.warning,
            ),
          ],
        ),
      ),
    );
  }

  // Build summary row
  Widget _buildSummaryRow(
    ThemeData theme,
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build channel breakdown section
  Widget _buildChannelBreakdownSection(ThemeData theme, bool isDark) {
    final channels = _analytics!.channels;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.playlist_play, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Channel Statistics',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (channels.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No channels found',
                        style: TextStyle(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...channels.map((channel) => _buildChannelCard(theme, channel)),
          ],
        ),
      ),
    );
  }

  // Build individual channel card
  Widget _buildChannelCard(ThemeData theme, ChannelAnalytics channel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Channel header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tv,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.channelName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'ID: ${channel.channelId}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              // Total videos badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${channel.totalVideos}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Channel statistics
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChannelStatChip(
                theme,
                'Public',
                channel.publicVideos,
                Colors.green,
              ),
              _buildChannelStatChip(
                theme,
                'Private',
                channel.privateVideos,
                Colors.orange,
              ),
              _buildChannelStatChip(
                theme,
                'Refined',
                channel.refinedVideos,
                Colors.teal,
              ),
              _buildChannelStatChip(
                theme,
                'Unrefined',
                channel.unrefinedVideos,
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build channel statistic chip
  Widget _buildChannelStatChip(
    ThemeData theme,
    String label,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Build settings tab (placeholder)
  Widget _buildSettingsTab() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          const Text('Settings feature coming soon'),
        ],
      ),
    );
  }

  // Build channel statistics display
  Widget _buildChannelStats(ThemeData theme) {
    final totalVideos = _videos.length;
    final refinedVideos = _videos.where((video) => video.isRefined).length;
    final unrefinedVideos = totalVideos - refinedVideos;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            'Stats:',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          _buildCompactStatChip(
            theme,
            totalVideos.toString(),
            theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          _buildCompactStatChip(
            theme,
            refinedVideos.toString(),
            theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 4),
          _buildCompactStatChip(
            theme,
            unrefinedVideos.toString(),
            theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

  // Build compact stat chip
  Widget _buildCompactStatChip(ThemeData theme, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.surface,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
