import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/channel_provider.dart';
import '../../providers/video_provider.dart';
import '../../models/video.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';

class VideoManagementScreen extends StatefulWidget {
  const VideoManagementScreen({super.key});

  @override
  State<VideoManagementScreen> createState() => _VideoManagementScreenState();
}

class _VideoManagementScreenState extends State<VideoManagementScreen> {
  String? _selectedChannelId;
  String _selectedLanguage = AppConstants.languageAll;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChannels();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadChannels() async {
    try {
      await context.read<ChannelProvider>().fetchChannels(
        language: AppConstants.languageAll,
        visibility: AppConstants.visibilityAll,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load channels: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadVideos() async {
    if (_selectedChannelId == null) return;

    try {
      await context.read<VideoProvider>().fetchVideos(
        _selectedChannelId!,
        language: _selectedLanguage,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load videos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Video> _getFilteredVideos(List<Video> videos) {
    if (_searchQuery.isEmpty) return videos;

    return videos.where((video) {
      return video.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          video.videoId.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _showVideoDetails(Video video) {
    showDialog(
      context: context,
      builder: (context) => _VideoDetailsDialog(
        video: video,
        onVideoUpdated: () {
          _loadVideos();
        },
      ),
    );
  }

  void _showAddVideoModal() {
    if (_selectedChannelId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a channel first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AddVideoDialog(
        channelId: _selectedChannelId!,
        onVideoAdded: () {
          _loadVideos();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Management'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
            tooltip: 'Refresh Videos',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Channel Selection
                Consumer<ChannelProvider>(
                  builder: (context, channelProvider, child) {
                    final channels = channelProvider.channels;

                    return DropdownButtonFormField<String>(
                      value: _selectedChannelId,
                      decoration: const InputDecoration(
                        labelText: 'Select Channel',
                        border: OutlineInputBorder(),
                      ),
                      hint: const Text('Choose a channel'),
                      items: channels
                          .map(
                            (channel) => DropdownMenuItem(
                              value: channel.id,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundImage: NetworkImage(
                                      channel.imageUrl,
                                    ),
                                    onBackgroundImageError: (_, __) {},
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      channel.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '(${channel.videos.length})',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedChannelId = value;
                        });
                        if (value != null) {
                          _loadVideos();
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Search and Language Filter Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search videos...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Language',
                          border: OutlineInputBorder(),
                        ),
                        items: AppConstants.languageOptions.entries
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.value,
                                child: Text(entry.key),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLanguage = value!;
                          });
                          _loadVideos();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Videos List
          Expanded(
            child: _selectedChannelId == null
                ? Center(
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
                          'Select a channel to view videos',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : Consumer<VideoProvider>(
                    builder: (context, videoProvider, child) {
                      if (videoProvider.isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final videos = videoProvider.videos;
                      final filteredVideos = _getFilteredVideos(videos);

                      if (filteredVideos.isEmpty) {
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
                                videos.isEmpty
                                    ? 'No videos found'
                                    : 'No matching videos',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: Colors.grey.shade600),
                              ),
                              if (videos.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Upload your first video',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(color: Colors.grey.shade500),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredVideos.length,
                        itemBuilder: (context, index) {
                          final video = filteredVideos[index];
                          return _buildVideoCard(video);
                        },
                      );
                    },
                  ),
          ),
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

  Widget _buildVideoCard(Video video) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: video.link.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://img.youtube.com/vi/${video.videoId}/mqdefault.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.video_library, size: 32);
                    },
                  ),
                )
              : const Icon(Icons.video_library, size: 32),
        ),
        title: Text(
          video.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${video.videoId}'),
            if (video.link.isNotEmpty) Text('Link: ${video.link}'),
            Row(
              children: [
                Chip(
                  label: Text(
                    video.visibility.toUpperCase(),
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: video.visibility == 'public'
                      ? Colors.green.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    _formatDate(video.createdDate),
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showVideoDetails(video),
              tooltip: 'View Details',
            ),
            if (video.link.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  // TODO: Launch URL
                  AppLogger.info('Opening video link: ${video.link}');
                },
                tooltip: 'Open Video Link',
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _VideoDetailsDialog extends StatefulWidget {
  final Video video;
  final VoidCallback onVideoUpdated;

  const _VideoDetailsDialog({
    required this.video,
    required this.onVideoUpdated,
  });

  @override
  State<_VideoDetailsDialog> createState() => _VideoDetailsDialogState();
}

class _VideoDetailsDialogState extends State<_VideoDetailsDialog> {
  late TextEditingController _titleController;
  late String _visibility;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.video.title);
    _visibility = widget.video.visibility;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Video Details'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Preview
              if (widget.video.link.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://img.youtube.com/vi/${widget.video.videoId}/mqdefault.jpg',
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.video_library, size: 64),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Video ID (Read-only)
              TextFormField(
                initialValue: widget.video.videoId,
                decoration: const InputDecoration(
                  labelText: 'Video ID',
                  border: OutlineInputBorder(),
                ),
                enabled: false,
              ),
              const SizedBox(height: 16),

              // Link (Read-only)
              if (widget.video.link.isNotEmpty) ...[
                TextFormField(
                  initialValue: widget.video.link,
                  decoration: const InputDecoration(
                    labelText: 'Link',
                    border: OutlineInputBorder(),
                  ),
                  enabled: false,
                ),
                const SizedBox(height: 16),
              ],

              // Visibility Dropdown
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: 'Visibility',
                  border: OutlineInputBorder(),
                ),
                items: AppConstants.visibilityOptions.entries
                    .where((entry) => entry.value != AppConstants.visibilityAll)
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.value,
                        child: Text(entry.key),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _visibility = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Metadata
              Text(
                'Created: ${widget.video.createdDate}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveChanges,
          child: const Text('Save Changes'),
        ),
      ],
    );
  }

  void _saveChanges() {
    // TODO: Implement video update functionality
    AppLogger.info('Updating video: ${widget.video.videoId}');
    AppLogger.info('New title: ${_titleController.text}');
    AppLogger.info('New visibility: $_visibility');

    // For now, just close the dialog
    Navigator.of(context).pop();
    widget.onVideoUpdated();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Video updated successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _AddVideoDialog extends StatefulWidget {
  final String channelId;
  final VoidCallback onVideoAdded;

  const _AddVideoDialog({required this.channelId, required this.onVideoAdded});

  @override
  State<_AddVideoDialog> createState() => _AddVideoDialogState();
}

class _AddVideoDialogState extends State<_AddVideoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _linkController = TextEditingController();
  final _titleController = TextEditingController();
  String _visibility = 'public';
  bool _isLoading = false;

  @override
  void dispose() {
    _linkController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Video'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'YouTube Video URL *',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Video URL is required';
                  }
                  if (!value.contains('youtube.com') &&
                      !value.contains('youtu.be')) {
                    return 'Please enter a valid YouTube URL';
                  }
                  return null;
                },
                onChanged: _extractVideoTitle,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Video Title *',
                  hintText: 'Enter video title',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Video title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: 'Visibility',
                  border: OutlineInputBorder(),
                ),
                items: AppConstants.visibilityOptions.entries
                    .where((entry) => entry.value != AppConstants.visibilityAll)
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.value,
                        child: Text(entry.key),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _visibility = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addVideo,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Video'),
        ),
      ],
    );
  }

  void _extractVideoTitle(String url) {
    // TODO: Extract video title from YouTube URL
    // For now, just log the URL
    AppLogger.info('YouTube URL entered: $url');
  }

  void _addVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Implement video upload functionality
      AppLogger.info('Adding video to channel: ${widget.channelId}');
      AppLogger.info('Video URL: ${_linkController.text}');
      AppLogger.info('Video title: ${_titleController.text}');
      AppLogger.info('Visibility: $_visibility');

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
        widget.onVideoAdded();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error adding video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add video: $e'),
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
}
