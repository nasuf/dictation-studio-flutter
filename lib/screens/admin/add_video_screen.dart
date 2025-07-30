import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../services/api_service.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';

// Data model for video entry
class VideoEntry {
  String link;
  String title;
  File? srtFile;
  bool isLoadingTitle;
  String? titleError;
  bool isUploadingFile;
  String? videoId;

  VideoEntry({
    this.link = '',
    this.title = '',
    this.srtFile,
    this.isLoadingTitle = false,
    this.titleError,
    this.isUploadingFile = false,
    this.videoId,
  });
}

class AddVideoScreen extends StatefulWidget {
  final String channelId;

  const AddVideoScreen({
    super.key,
    required this.channelId,
  });

  @override
  State<AddVideoScreen> createState() => _AddVideoScreenState();
}

class _AddVideoScreenState extends State<AddVideoScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  List<VideoEntry> _videoEntries = [VideoEntry()];
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;
  String? _uploadStatus;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isSubmitting) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: _buildUploadProgress(),
      );
    }
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Add Videos'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 1,
        actions: [
          TextButton(
            onPressed: _canSubmit() ? _submitVideos : null,
            child: Text(
              'Upload Videos',
              style: TextStyle(
                color: _canSubmit() ? theme.colorScheme.primary : theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _buildVideoForm(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVideoEntry,
        icon: const Icon(Icons.add),
        label: const Text('Add Video'),
      ),
    );
  }

  Widget _buildVideoForm() {
    return Form(
      key: _formKey,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _videoEntries.length,
        itemBuilder: (context, index) => _buildVideoEntryCard(index),
      ),
    );
  }

  Widget _buildVideoEntryCard(int index) {
    final theme = Theme.of(context);
    final entry = _videoEntries[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with remove button
            Row(
              children: [
                Text(
                  'Video ${index + 1}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_videoEntries.length > 1)
                  IconButton(
                    onPressed: () => _removeVideoEntry(index),
                    icon: Icon(Icons.delete, color: theme.colorScheme.error),
                    tooltip: 'Remove video',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Video URL field with Download SRT button
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'YouTube URL *',
                      hintText: 'https://www.youtube.com/watch?v=...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    validator: (value) => _validateVideoUrl(value),
                    onChanged: (value) => _onVideoUrlChanged(index, value),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56, // Match TextFormField height
                  child: ElevatedButton.icon(
                    onPressed: _isValidYouTubeUrl(entry.link) 
                        ? () => _downloadSrtForVideo(entry.link)
                        : null,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('SRT'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Video title field
            TextFormField(
              initialValue: entry.title,
              decoration: InputDecoration(
                labelText: 'Video Title *',
                hintText: 'Enter or auto-fetch video title',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.title),
                suffixIcon: entry.isLoadingTitle
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : entry.link.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _fetchVideoTitle(index),
                            tooltip: 'Fetch title',
                          )
                        : null,
              ),
              validator: (value) => value?.trim().isEmpty == true ? 'Title is required' : null,
              onChanged: (value) => _onVideoTitleChanged(index, value),
            ),
            if (entry.titleError != null) ...[
              const SizedBox(height: 8),
              Text(
                entry.titleError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            
            // SRT file upload
            _buildSrtUploadSection(index, entry),
          ],
        ),
      ),
    );
  }

  Widget _buildSrtUploadSection(int index, VideoEntry entry) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Subtitle File (SRT) *',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            entry.isUploadingFile
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton.icon(
                    onPressed: () => _pickSrtFile(index),
                    icon: Icon(entry.srtFile != null ? Icons.refresh : Icons.upload_file),
                    label: Text(entry.srtFile != null ? 'Change File' : 'Choose File'),
                  ),
          ],
        ),
        const SizedBox(height: 8),
        if (entry.srtFile != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.description, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.srtFile!.path.split('/').last,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeSrtFile(index),
                  icon: Icon(Icons.close, color: theme.colorScheme.error, size: 16),
                  tooltip: 'Remove file',
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: theme.colorScheme.error, size: 20),
                const SizedBox(width: 8),
                Text(
                  'SRT file is required for each video',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUploadProgress() {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 24),
            Text(
              'Uploading Videos...',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (_uploadStatus != null)
              Text(
                _uploadStatus!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 8),
            Text(
              '${(_uploadProgress * 100).toInt()}% Complete',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Validation and utility methods
  String? _validateVideoUrl(String? value) {
    if (value?.trim().isEmpty == true) {
      return 'YouTube URL is required';
    }
    
    final url = value!.trim();
    if (!_isValidYouTubeUrl(url)) {
      return 'Please enter a valid YouTube URL';
    }
    
    return null;
  }

  bool _isValidYouTubeUrl(String url) {
    final regExp = RegExp(
      r'^https?:\/\/(?:www\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|v\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    return regExp.hasMatch(url);
  }

  String? _extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:watch\?v=|embed\/|v\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(1);
  }

  // Event handlers
  void _addVideoEntry() {
    setState(() {
      _videoEntries.add(VideoEntry());
    });
  }

  void _removeVideoEntry(int index) {
    setState(() {
      _videoEntries.removeAt(index);
    });
  }

  void _onVideoUrlChanged(int index, String value) {
    setState(() {
      _videoEntries[index].link = value;
      _videoEntries[index].videoId = _extractVideoId(value);
      _videoEntries[index].titleError = null;
    });
    
    // Auto-fetch title if URL is valid
    if (_isValidYouTubeUrl(value) && _videoEntries[index].title.isEmpty) {
      _fetchVideoTitle(index);
    }
  }

  void _onVideoTitleChanged(int index, String value) {
    setState(() {
      _videoEntries[index].title = value;
    });
  }

  Future<void> _fetchVideoTitle(int index) async {
    final entry = _videoEntries[index];
    if (!_isValidYouTubeUrl(entry.link)) return;

    setState(() {
      entry.isLoadingTitle = true;
      entry.titleError = null;
    });

    try {
      // Extract video ID
      final videoId = _extractVideoId(entry.link);
      if (videoId == null) throw Exception('Invalid video ID');

      // TODO: Implement YouTube API integration to fetch title
      // For now, simulate the API call
      await Future.delayed(const Duration(seconds: 2));
      
      // Placeholder title generation
      setState(() {
        entry.title = 'Video Title for $videoId'; // Replace with actual API call
        entry.isLoadingTitle = false;
      });
    } catch (e) {
      setState(() {
        entry.titleError = 'Failed to fetch title: ${e.toString()}';
        entry.isLoadingTitle = false;
      });
    }
  }

  Future<void> _pickSrtFile(int index) async {
    setState(() {
      _videoEntries[index].isUploadingFile = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        setState(() {
          _videoEntries[index].srtFile = file;
        });
      }
    } catch (e) {
      AppLogger.error('Error picking SRT file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick file: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        _videoEntries[index].isUploadingFile = false;
      });
    }
  }

  void _removeSrtFile(int index) {
    setState(() {
      _videoEntries[index].srtFile = null;
    });
  }

  Future<void> _downloadSrtForVideo(String videoUrl) async {
    final videoId = _extractVideoId(videoUrl);
    if (videoId == null) return;
    
    // Navigate to downsub.com with the specific video URL
    final downloadUrl = 'https://downsub.com/?url=${Uri.encodeComponent(videoUrl)}';
    
    try {
      await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.error('Error launching download URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open download page: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  bool _canSubmit() {
    if (_videoEntries.isEmpty) return false;
    
    for (final entry in _videoEntries) {
      if (entry.link.trim().isEmpty ||
          entry.title.trim().isEmpty ||
          entry.srtFile == null ||
          !_isValidYouTubeUrl(entry.link)) {
        return false;
      }
    }
    
    return true;
  }

  Future<void> _submitVideos() async {
    if (!_formKey.currentState!.validate() || !_canSubmit()) return;

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
      _uploadStatus = 'Preparing videos...';
    });

    try {
      // Process videos in batches (similar to React version)
      const batchSize = 5;
      final batches = <List<VideoEntry>>[];
      
      for (int i = 0; i < _videoEntries.length; i += batchSize) {
        final end = (i + batchSize < _videoEntries.length) ? i + batchSize : _videoEntries.length;
        batches.add(_videoEntries.sublist(i, end));
      }

      int completedBatches = 0;
      
      for (final batch in batches) {
        setState(() {
          _uploadStatus = 'Uploading batch ${completedBatches + 1} of ${batches.length}...';
        });
        
        await _uploadVideoBatch(batch);
        
        completedBatches++;
        setState(() {
          _uploadProgress = completedBatches / batches.length;
        });
      }

      setState(() {
        _uploadStatus = 'Upload completed successfully!';
      });

      // Wait a moment to show success message
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully uploaded ${_videoEntries.length} videos'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Error uploading videos: $e');
      setState(() {
        _uploadStatus = 'Upload failed: ${e.toString()}';
        _isSubmitting = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload videos: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadVideoBatch(List<VideoEntry> batch) async {
    try {
      // Prepare video data
      final videoData = batch.map((entry) => {
        'channel_id': widget.channelId,
        'video_link': entry.link,
        'title': entry.title,
        'visibility': AppConstants.visibilityPrivate, // Default to private
      }).toList();

      // Create FormData equivalent
      final request = http.MultipartRequest('POST', Uri.parse('${_apiService.baseUrl}/service/video-list'));
      
      // Add authorization header
      final token = await _apiService.getAuthToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Add video data
      request.fields['data'] = jsonEncode(videoData);
      
      // Add transcript files
      for (int i = 0; i < batch.length; i++) {
        final entry = batch[i];
        if (entry.srtFile != null) {
          final videoId = _extractVideoId(entry.link) ?? 'unknown';
          request.files.add(
            await http.MultipartFile.fromPath(
              'transcript_files',
              entry.srtFile!.path,
              filename: '$videoId.srt',
            ),
          );
        }
      }

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode} - $responseBody');
      }
      
      AppLogger.info('Successfully uploaded batch of ${batch.length} videos');
    } catch (e) {
      AppLogger.error('Error uploading video batch: $e');
      rethrow;
    }
  }
}