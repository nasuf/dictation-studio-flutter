import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/channel.dart';
import '../models/video.dart';
import '../models/progress.dart';
import '../models/progress_data.dart' as progress_data;
import '../models/verification_code.dart';
import '../models/transcript_item.dart';
import '../services/token_manager.dart';
import '../utils/logger.dart';
import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message (${statusCode ?? 'unknown'})';
}

class ApiService {
  // Use hardcoded production URL to avoid config issues
  static const String _baseUrl = 'https://www.dictationstudio.com/ds';

  final http.Client _client = http.Client();

  // Global navigation key for 401 error handling
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // Getter for base URL
  String get baseUrl => _baseUrl;

  // Get auth token for API requests
  Future<String?> getAuthToken() async {
    String? accessToken = await TokenManager.getAccessToken();
    if (accessToken != null) {
      // Check if token is expiring soon and refresh if needed
      if (await TokenManager.isTokenExpiringSoon()) {
        AppLogger.info('🔄 Token expiring soon, attempting refresh...');
        accessToken = await TokenManager.refreshAccessToken();
      }
    }
    return accessToken;
  }

  static void _handle401Error() {
    if (_navigatorKey?.currentContext != null) {
      final context = _navigatorKey!.currentContext!;

      // Show dialog and navigate to login
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Login Required',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Text(
              'Your session has expired. Please sign in again to continue.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Navigate directly to login screen
                  context.push('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Sign In'),
              ),
            ],
          );
        },
      );
    }
  }

  // Make HTTP request with automatic token handling
  Future<T> _makeRequest<T>(
    String endpoint,
    T Function(dynamic) fromJson, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requiresAuth = false,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      AppLogger.info('Making ${method.toUpperCase()} request to: $uri');

      // Always start with basic headers
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Auto-add Authorization header for ALL requests if token is available (like UI project)
      String? accessToken = await TokenManager.getAccessToken();

      if (accessToken != null) {
        // Check if token is expiring soon and refresh if needed
        if (await TokenManager.isTokenExpiringSoon()) {
          AppLogger.info('🔄 Token expiring soon, attempting refresh...');
          accessToken = await TokenManager.refreshAccessToken();
        }

        if (accessToken != null) {
          headers['Authorization'] = 'Bearer $accessToken';
          AppLogger.info('✅ Added Authorization header with token (auto)');
        } else {
          AppLogger.warning('⚠️ Token refresh failed, proceeding without auth');
        }
      } else {
        AppLogger.info('ℹ️ No access token available');
      }

      late http.Response response;

      // Apply timeout to all requests
      const timeout = Duration(minutes: 2);

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(timeout);
          break;
        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(timeout);
          break;
        default:
          throw UnsupportedError('HTTP method $method not supported');
      }

      AppLogger.info('Response status: ${response.statusCode}');
      AppLogger.info('Response headers: ${response.headers}');

      // Handle tokens from response headers (matching UI project logic)
      await TokenManager.handleTokensFromResponse(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Check for null or empty response body
        if (response.body.isEmpty) {
          AppLogger.error('❌ Empty response body received');
          throw ApiException('Empty response from server', response.statusCode);
        }

        try {
          final responseData = jsonDecode(response.body);
          AppLogger.info('Response data type: ${responseData.runtimeType}');
          return fromJson(responseData);
        } catch (jsonError) {
          AppLogger.error('❌ JSON decode error: $jsonError');
          AppLogger.error('❌ Response body: ${response.body}');
          throw ApiException(
            'Invalid JSON response: $jsonError',
            response.statusCode,
          );
        }
      } else if (response.statusCode == 401) {
        // Unauthorized - clear tokens, show dialog, and throw exception
        AppLogger.warning('❌ Unauthorized (401) - clearing tokens');
        await TokenManager.clearTokens();

        // Show login dialog
        _handle401Error();

        throw ApiException(
          'Authentication failed - please login again',
          response.statusCode,
        );
      } else {
        AppLogger.error(
          '❌ HTTP Error: ${response.statusCode} - ${response.body}',
        );
        throw ApiException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          response.statusCode,
        );
      }
    } catch (e) {
      AppLogger.error('❌ Request error: $e');
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException('Network error: $e', null);
    }
  }

  // Get channels list - expecting direct array from API
  Future<List<Channel>> getChannels({
    String visibility = AppConstants.visibilityPublic,
    String language = AppConstants.languageAll,
  }) async {
    try {
      return await _makeRequest<List<Channel>>(
        '/service/channel',
        (dynamic responseData) {
          AppLogger.info('Processing channels response...');
          AppLogger.info('Response data type: ${responseData.runtimeType}');
          AppLogger.info('Response data: $responseData');

          if (responseData == null) {
            AppLogger.error('❌ Response data is null');
            throw ApiException('Null response data received');
          }

          if (responseData is List) {
            AppLogger.info(
              'Response is List with ${responseData.length} items',
            );
            return responseData
                .map((item) {
                  if (item == null) {
                    AppLogger.warning('⚠️ Skipping null item in channel list');
                    return null;
                  }
                  return Channel.fromJson(item as Map<String, dynamic>);
                })
                .where((channel) => channel != null)
                .cast<Channel>()
                .toList();
          } else if (responseData is Map && responseData['data'] is List) {
            AppLogger.info('Response is wrapped object with data array');
            final data = responseData['data'] as List;
            return data
                .map((item) {
                  if (item == null) {
                    AppLogger.warning('⚠️ Skipping null item in channel list');
                    return null;
                  }
                  return Channel.fromJson(item as Map<String, dynamic>);
                })
                .where((channel) => channel != null)
                .cast<Channel>()
                .toList();
          } else {
            AppLogger.error('❌ Invalid response format: $responseData');
            throw ApiException(
              'Invalid response format: expected array or object with data array, got ${responseData.runtimeType}',
            );
          }
        },
        queryParams: {'visibility': visibility, 'language': language},
      );
    } catch (e) {
      AppLogger.error('Error fetching channels: $e');
      AppLogger.info(
        'URL: $_baseUrl/service/channel?visibility=$visibility&language=$language',
      );
      rethrow;
    }
  }

  // Get video list for a channel
  Future<VideoListResponse> getVideoList(
    String channelId, {
    String visibility = AppConstants.visibilityPublic,
    String? language,
  }) async {
    final queryParams = {
      'visibility': visibility,
      if (language != null) 'language': language,
    };

    return await _makeRequest<VideoListResponse>(
      '/service/video-list/$channelId',
      (dynamic responseData) {
        AppLogger.info('Processing video list response...');
        AppLogger.info('Response data type: ${responseData.runtimeType}');

        if (responseData is Map<String, dynamic>) {
          // If response has a 'data' field, use that
          if (responseData.containsKey('data')) {
            AppLogger.info('Response has data field, using that');
            return VideoListResponse.fromJson(responseData['data']);
          }
          // If response has a 'videos' field, use that
          if (responseData.containsKey('videos')) {
            AppLogger.info('Response has videos field, using that');
            return VideoListResponse.fromJson(responseData);
          }
          // If response is a direct array, wrap it
          if (responseData.containsKey('0') || responseData is List) {
            AppLogger.info('Response appears to be a list, wrapping it');
            return VideoListResponse(videos: []);
          }
        }

        // Default case: try to parse as VideoListResponse
        AppLogger.info('Using default parsing');
        return VideoListResponse.fromJson(responseData);
      },
      queryParams: queryParams,
    );
  }

  // Get channel progress
  Future<ChannelProgress> getChannelProgress(String channelId) async {
    try {
      return await _makeRequest<ChannelProgress>(
        '/user/progress/channel',
        (data) {
          // Handle different response formats
          if (data is Map<String, dynamic>) {
            if (data.containsKey('data')) {
              return ChannelProgress.fromJson(data['data']);
            }
            return ChannelProgress.fromJson(data);
          }
          return ChannelProgress.fromJson(data);
        },
        method: 'GET',
        queryParams: {'channelId': channelId},
        requiresAuth: true, // Channel progress requires authentication
      );
    } catch (e) {
      AppLogger.error('Get channel progress API error: $e');
      rethrow;
    }
  }

  // Get user progress for specific video
  Future<Map<String, dynamic>> getUserProgress(
    String channelId,
    String videoId,
  ) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/user/progress',
        (data) => data as Map<String, dynamic>,
        method: 'GET',
        queryParams: {'channelId': channelId, 'videoId': videoId},
        requiresAuth: true, // User progress requires authentication
      );
    } catch (e) {
      AppLogger.error('Get user progress API error: $e');
      rethrow;
    }
  }

  // Get video transcript
  Future<Map<String, dynamic>> getVideoTranscript(
    String channelId,
    String videoId,
  ) async {
    try {
      AppLogger.info(
        'Fetching transcript for channel: $channelId, video: $videoId',
      );
      final result = await _makeRequest<Map<String, dynamic>>(
        '/service/video-transcript/$channelId/$videoId',
        (data) => data as Map<String, dynamic>,
        method: 'GET',
        requiresAuth: true,
      );
      AppLogger.info('Transcript API response keys: ${result.keys.toList()}');
      return result;
    } catch (e) {
      AppLogger.error('Get video transcript API error: $e');
      rethrow;
    }
  }

  // Get video transcript items for editing
  Future<List<TranscriptItem>> getVideoTranscriptItems(
    String channelId,
    String videoId,
  ) async {
    try {
      AppLogger.info(
        'Fetching transcript items for channel: $channelId, video: $videoId',
      );
      
      final response = await getVideoTranscript(channelId, videoId);
      
      // Parse the transcript data
      List<TranscriptItem> transcriptItems = [];
      
      if (response.containsKey('transcript') && response['transcript'] is List) {
        final transcriptList = response['transcript'] as List;
        AppLogger.info('Found ${transcriptList.length} transcript segments');
        
        for (int i = 0; i < transcriptList.length; i++) {
          final item = transcriptList[i];
          if (item is Map<String, dynamic>) {
            try {
              // Convert API format to TranscriptItem
              final transcriptItem = TranscriptItem(
                start: (item['start'] as num?)?.toDouble() ?? 0.0,
                end: (item['end'] as num?)?.toDouble() ?? 1.0,
                transcript: (item['transcript'] ?? '').toString().trim(),
                index: i,
              );
              transcriptItems.add(transcriptItem);
            } catch (e) {
              AppLogger.warning('Failed to parse transcript item $i: $e');
              // Skip malformed items but continue parsing
            }
          }
        }
      } else if (response.containsKey('data') && response['data'] is Map) {
        // Check if data contains transcript array
        final data = response['data'] as Map<String, dynamic>;
        if (data.containsKey('transcript') && data['transcript'] is List) {
          final transcriptList = data['transcript'] as List;
          AppLogger.info('Found ${transcriptList.length} transcript segments in data');
          
          for (int i = 0; i < transcriptList.length; i++) {
            final item = transcriptList[i];
            if (item is Map<String, dynamic>) {
              try {
                final transcriptItem = TranscriptItem(
                  start: (item['start'] as num?)?.toDouble() ?? 0.0,
                  end: (item['end'] as num?)?.toDouble() ?? 1.0,
                  transcript: (item['transcript'] ?? '').toString().trim(),
                  index: i,
                );
                transcriptItems.add(transcriptItem);
              } catch (e) {
                AppLogger.warning('Failed to parse transcript item $i: $e');
              }
            }
          }
        }
      }
      
      if (transcriptItems.isEmpty) {
        AppLogger.warning('No transcript items found or parsed');
        // Return empty list instead of throwing error to allow manual transcript creation
      }
      
      AppLogger.info('Successfully parsed ${transcriptItems.length} transcript items');
      return transcriptItems;
      
    } catch (e) {
      AppLogger.error('Get video transcript items error: $e');
      // Return empty list to allow manual transcript creation
      return [];
    }
  }

  // Save video full transcript
  Future<Map<String, dynamic>> saveVideoFullTranscript(
    String channelId,
    String videoId,
    List<TranscriptItem> transcriptItems,
  ) async {
    try {
      AppLogger.info(
        'Saving full transcript for channel: $channelId, video: $videoId with ${transcriptItems.length} segments',
      );
      
      // Convert transcript items to API format
      final transcript = transcriptItems.map((item) => {
        'start': item.start,
        'end': item.end,
        'transcript': item.transcript.trim(),
      }).toList();
      
      final payload = {
        'transcript': transcript,
      };
      
      AppLogger.info('Transcript payload: ${transcript.length} segments');
      
      final result = await _makeRequest<Map<String, dynamic>>(
        '/service/$channelId/$videoId/full-transcript',
        (data) => data as Map<String, dynamic>,
        method: 'PUT',
        body: payload,
        requiresAuth: true,
      );
      
      AppLogger.info('Full transcript saved successfully');
      return result;
      
    } catch (e) {
      AppLogger.error('Save video full transcript error: $e');
      rethrow;
    }
  }

  // Restore original transcript
  Future<Map<String, dynamic>> restoreOriginalTranscript(
    String videoId,
  ) async {
    try {
      AppLogger.info(
        'Restoring original transcript for video: $videoId',
      );
      
      return await _makeRequest<Map<String, dynamic>>(
        '/service/deep_look/$videoId/restore-transcript',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        requiresAuth: true,
      );
    } catch (e) {
      AppLogger.error('Restore original transcript API error: $e');
      rethrow;
    }
  }

  // Save user progress
  Future<Map<String, dynamic>> saveUserProgress(
    ProgressData progressData,
  ) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/user/progress',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        body: progressData.toJson(),
        requiresAuth: true,
      );
    } catch (e) {
      AppLogger.error('Save user progress API error: $e');
      rethrow;
    }
  }

  // Get user duration data
  Future<Map<String, dynamic>> getUserDuration() async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/user/duration',
        (data) => data as Map<String, dynamic>,
        method: 'GET',
        requiresAuth: true,
      );
    } catch (e) {
      AppLogger.error('Get user duration API error: $e');
      rethrow;
    }
  }

  // Check dictation quota
  Future<bool> checkDictationQuota(String channelId, String videoId) async {
    try {
      final result = await _makeRequest<Map<String, dynamic>>(
        '/user/dictation_quota',
        (dynamic responseData) => responseData as Map<String, dynamic>,
        queryParams: {'channelId': channelId, 'videoId': videoId},
      );
      return result['hasQuota'] ?? false;
    } catch (e) {
      // If there's an error, assume no quota
      return false;
    }
  }

  // Register dictation video
  Future<void> registerDictationVideo(String channelId, String videoId) async {
    await _makeRequest<Map<String, dynamic>>(
      '/user/register_dictation',
      (dynamic responseData) => responseData as Map<String, dynamic>,
      method: 'POST',
      body: {'channelId': channelId, 'videoId': videoId},
    );
  }

  // Login API call to match backend /auth/login endpoint
  Future<Map<String, dynamic>> login(
    String email,
    String username,
    String avatar,
  ) async {
    try {
      final response = await _makeRequest<Map<String, dynamic>>(
        '/auth/login',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        body: {'email': email, 'username': username, 'avatar': avatar},
        requiresAuth: false, // Login doesn't require existing auth
      );

      AppLogger.info('Login response: $response');
      return response;
    } catch (e) {
      AppLogger.error('Login API error: $e');
      rethrow;
    }
  }

  // Logout API call
  Future<Map<String, dynamic>> logout() async {
    try {
      final response = await _makeRequest<Map<String, dynamic>>(
        '/auth/logout',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        requiresAuth: true, // Logout requires authentication
      );

      // Clear tokens after successful logout
      await TokenManager.clearTokens();
      return response;
    } catch (e) {
      AppLogger.error('Logout API error: $e');
      // Clear tokens even if logout fails
      await TokenManager.clearTokens();
      rethrow;
    }
  }

  // Save user config API call
  Future<Map<String, dynamic>> saveUserConfig(
    Map<String, dynamic> config,
  ) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/user/config',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        body: config,
        requiresAuth: true, // User config requires authentication
      );
    } catch (e) {
      AppLogger.error('Save user config API error: $e');
      rethrow;
    }
  }

  // Admin-related API methods

  // Get all users for admin
  Future<Map<String, dynamic>> getAllUsers() async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/auth/users', // Fixed: Use correct endpoint
        (data) => data as Map<String, dynamic>,
        method: 'GET',
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Get all users API error: $e');
      rethrow;
    }
  }

  // Get all channels for admin (raw response)
  Future<dynamic> getChannelsRaw(String visibility, String language) async {
    try {
      return await _makeRequest<dynamic>(
        '/service/channel',
        (data) => data, // Return data as-is without casting
        method: 'GET',
        queryParams: {'visibility': visibility, 'language': language},
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Get channels raw API error: $e');
      rethrow;
    }
  }

  // Get video list for a specific channel (raw response)
  Future<dynamic> getVideoListRaw(
    String channelId,
    String visibility, [
    String? language,
  ]) async {
    try {
      Map<String, String> queryParams = {'visibility': visibility};
      if (language != null) {
        queryParams['language'] = language;
      }

      return await _makeRequest<dynamic>(
        '/service/video-list/$channelId',
        (data) => data, // Return data as-is without casting
        method: 'GET',
        queryParams: queryParams,
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Get video list raw API error: $e');
      rethrow;
    }
  }

  // Get admin statistics (channels and videos count)
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/service/admin/stats',
        (data) => data as Map<String, dynamic>,
        method: 'GET',
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Get admin stats API error: $e');
      rethrow;
    }
  }

  // Add channels (admin operation)
  Future<Map<String, dynamic>> addChannels(List<Channel> channels) async {
    try {
      final channelsData = channels.map((channel) => channel.toJson()).toList();

      return await _makeRequest<Map<String, dynamic>>(
        '/service/channel',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        body: {'channels': channelsData},
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Add channels API error: $e');
      rethrow;
    }
  }

  // Update channel (admin operation)
  Future<Map<String, dynamic>> updateChannel(
    String channelId,
    Map<String, dynamic> updateData,
  ) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/service/channel/$channelId',
        (data) => data as Map<String, dynamic>,
        method: 'PUT',
        body: updateData,
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Update channel API error: $e');
      rethrow;
    }
  }

  // Delete channel (admin operation)
  Future<Map<String, dynamic>> deleteChannel(String channelId) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/service/channel/$channelId',
        (data) => data as Map<String, dynamic>,
        method: 'DELETE',
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Delete channel API error: $e');
      rethrow;
    }
  }

  // User Management API methods

  // Update user role (admin operation)
  Future<Map<String, dynamic>> updateUserRole(
    List<String> emails,
    String role,
  ) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/auth/user/role',
        (data) => data as Map<String, dynamic>,
        method: 'PUT',
        body: {'emails': emails, 'role': role},
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Update user role API error: $e');
      rethrow;
    }
  }

  // Update user plan (admin operation)
  Future<Map<String, dynamic>> updateUserPlan(
    List<String> emails,
    String plan, {
    int? duration,
  }) async {
    try {
      final body = {'emails': emails, 'plan': plan};

      if (duration != null) {
        body['duration'] = duration;
      }

      return await _makeRequest<Map<String, dynamic>>(
        '/auth/user/plan',
        (data) => data as Map<String, dynamic>,
        method: 'PUT',
        body: body,
        requiresAuth: true, // Admin operations require authentication
      );
    } catch (e) {
      AppLogger.error('Update user plan API error: $e');
      rethrow;
    }
  }

  // Get user progress by email (admin operation)
  Future<List<progress_data.ProgressData>> getUserProgressByEmail(
    String userEmail,
  ) async {
    try {
      AppLogger.info('Fetching user progress for email: $userEmail');

      final response = await _makeRequest<dynamic>(
        '/user/all-progress',
        (data) => data,
        method: 'GET',
        queryParams: {'userEmail': userEmail},
        requiresAuth: true,
      );

      AppLogger.info('User progress response type: ${response.runtimeType}');
      AppLogger.info('User progress response: $response');

      // Handle different response formats
      List<dynamic> progressList;
      if (response is List) {
        AppLogger.info('Response is direct list with ${response.length} items');
        progressList = response;
      } else if (response is Map && response.containsKey('progress')) {
        AppLogger.info(
          'Response contains progress field with ${(response['progress'] as List).length} items',
        );
        progressList = response['progress'] as List;
      } else if (response is Map && response.containsKey('data')) {
        AppLogger.info(
          'Response contains data field with ${(response['data'] as List).length} items',
        );
        progressList = response['data'] as List;
      } else {
        AppLogger.warning('Unknown response format, returning empty list');
        progressList = [];
      }

      AppLogger.info('Parsed ${progressList.length} progress items');
      final result = progressList
          .map(
            (item) => progress_data.ProgressData.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
      AppLogger.info(
        'Successfully converted to ${result.length} ProgressData objects',
      );

      return result;
    } catch (e) {
      AppLogger.error('Get user progress by email API error: $e');
      rethrow;
    }
  }

  // Generate verification code (admin operation)
  Future<Map<String, dynamic>> generateVerificationCode(String duration) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/payment/generate-code',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        body: {'duration': duration},
        requiresAuth: true,
      );
    } catch (e) {
      AppLogger.error('Generate verification code API error: $e');
      rethrow;
    }
  }

  // Generate custom verification code (admin operation)
  Future<Map<String, dynamic>> generateCustomVerificationCode(int days) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/payment/generate-custom-code',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        body: {'days': days},
        requiresAuth: true,
      );
    } catch (e) {
      AppLogger.error('Generate custom verification code API error: $e');
      rethrow;
    }
  }

  // Get all verification codes (admin operation)
  Future<List<VerificationCode>> getAllVerificationCodes() async {
    try {
      final response = await _makeRequest<dynamic>(
        '/payment/verification-codes',
        (data) => data,
        method: 'GET',
        requiresAuth: true,
      );

      // Handle different response formats
      List<dynamic> codeList;
      if (response is List) {
        codeList = response;
      } else if (response is Map && response.containsKey('codes')) {
        codeList = response['codes'] as List;
      } else if (response is Map && response.containsKey('data')) {
        codeList = response['data'] as List;
      } else {
        codeList = [];
      }

      return codeList
          .map(
            (item) => VerificationCode.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      AppLogger.error('Get all verification codes API error: $e');
      rethrow;
    }
  }

  // Assign verification code to user (admin operation)
  Future<Map<String, dynamic>> assignVerificationCode(
    String code,
    String userEmail,
  ) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/payment/assign-code',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        body: {'code': code, 'userEmail': userEmail},
        requiresAuth: true,
      );
    } catch (e) {
      AppLogger.error('Assign verification code API error: $e');
      rethrow;
    }
  }

  // Update user duration (admin operation)
  Future<Map<String, dynamic>> updateUserDuration(
    List<String> emails,
    int duration,
  ) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/user/update-duration',
        (data) => data as Map<String, dynamic>,
        method: 'POST',
        body: {'emails': emails, 'duration': duration},
        requiresAuth: true,
      );
    } catch (e) {
      AppLogger.error('Update user duration API error: $e');
      rethrow;
    }
  }

  // Get user usage stats (admin operation)
  Future<Map<String, dynamic>> getUserUsageStats(int days) async {
    try {
      return await _makeRequest<Map<String, dynamic>>(
        '/user/usage-stats',
        (data) => data as Map<String, dynamic>,
        method: 'GET',
        queryParams: {'days': days.toString()},
        requiresAuth: true,
      );
    } catch (e) {
      AppLogger.error('Get user usage stats API error: $e');
      rethrow;
    }
  }
}

// Singleton instance
final ApiService apiService = ApiService();
