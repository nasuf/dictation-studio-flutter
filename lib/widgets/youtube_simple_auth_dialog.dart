import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/youtube_simple_auth_service.dart';
import '../utils/logger.dart';
import '../generated/app_localizations.dart';

class YouTubeSimpleAuthDialog extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  final Function(String)? onAuthError;
  final VoidCallback? onCancel;

  const YouTubeSimpleAuthDialog({
    super.key,
    this.onAuthSuccess,
    this.onAuthError,
    this.onCancel,
  });

  @override
  State<YouTubeSimpleAuthDialog> createState() => _YouTubeSimpleAuthDialogState();
}

class _YouTubeSimpleAuthDialogState extends State<YouTubeSimpleAuthDialog> {
  final YouTubeSimpleAuthService _authService = YouTubeSimpleAuthService();
  bool _isLoading = false;

  String _localizeMessage(String message) {
    final l10n = AppLocalizations.of(context)!;
    
    // Map English messages to localized versions
    if (message.contains('Test mode enabled')) {
      return l10n.testModeEnabled;
    } else if (message.contains('Authentication confirmed')) {
      return l10n.authenticationConfirmed;
    } else if (message.contains('Public access mode enabled')) {
      return l10n.publicAccessEnabled;
    }
    
    // Return original message if no mapping found
    return message;
  }

  Future<void> _handleAuthMethod(Future<SimpleAuthResult> Function() authMethod, String methodName) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.info('Starting $methodName authentication');
      final result = await authMethod();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result.success) {
          AppLogger.info('$methodName successful: ${result.message}');
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _localizeMessage(result.message),
                      style: const TextStyle(fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );

          // Call success callback
          widget.onAuthSuccess?.call();
          Navigator.of(context).pop();
        } else {
          AppLogger.error('$methodName failed: ${result.message}');
          widget.onAuthError?.call(result.message);
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.message,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        final errorMessage = '$methodName failed: $e';
        AppLogger.error(errorMessage);
        widget.onAuthError?.call(errorMessage);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _openBrowserAndConfirm() async {
    try {
      const String youtubeUrl = 'https://www.youtube.com/';
      final Uri url = Uri.parse(youtubeUrl);
      
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
        
        // Show confirmation dialog
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(l10n.confirmLogin),
                content: Text(l10n.confirmLoginInstructions),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n.confirmLoginButton),
                  ),
                ],
              );
            },
          );
          
          if (confirmed == true) {
            await _handleAuthMethod(
              () => _authService.markAsAuthenticated(userInfo: 'Browser User'),
              'Browser Login Confirmation'
            );
          }
        }
      } else {
        widget.onAuthError?.call('Cannot open browser');
      }
    } catch (e) {
      widget.onAuthError?.call('Browser login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      title: Row(
        children: [
          Icon(
            Icons.video_library,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.youtubeVideoAccess,
              style: const TextStyle(fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 400,
          maxHeight: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chooseVideoAccessMethod,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            // Test mode option (recommended for now)
            _buildAuthOption(
              icon: Icons.play_circle_filled,
              iconColor: Colors.green,
              title: l10n.enableVideoPlayback,
              subtitle: l10n.enableVideoPlaybackDesc,
              onTap: _isLoading ? null : () => _handleAuthMethod(
                _authService.enableTestMode,
                'Test Mode'
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Browser login option
            _buildAuthOption(
              icon: Icons.open_in_browser,
              iconColor: Colors.blue,
              title: l10n.browserLogin,
              subtitle: l10n.browserLoginDesc,
              onTap: _isLoading ? null : _openBrowserAndConfirm,
            ),
            
            const SizedBox(height: 12),
            
            // Public access option
            _buildAuthOption(
              icon: Icons.public,
              iconColor: Colors.orange,
              title: l10n.tryWithoutLogin,
              subtitle: l10n.tryWithoutLoginDesc,
              onTap: _isLoading ? null : () => _handleAuthMethod(
                _authService.enableNoAuthMode,
                'No-Auth Mode'
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.videoAccessInfo,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        TextButton(
          onPressed: _isLoading ? null : () {
            widget.onCancel?.call();
            Navigator.of(context).pop();
          },
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildAuthOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap == null)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.grey[500] : Colors.grey[400],
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the simple auth dialog
Future<void> showYouTubeSimpleAuthDialog(
  BuildContext context, {
  VoidCallback? onAuthSuccess,
  Function(String)? onAuthError,
  VoidCallback? onCancel,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return YouTubeSimpleAuthDialog(
        onAuthSuccess: onAuthSuccess,
        onAuthError: onAuthError,
        onCancel: onCancel,
      );
    },
  );
}