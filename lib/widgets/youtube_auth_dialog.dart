import 'package:flutter/material.dart';
import '../services/youtube_auth_service.dart';
import '../utils/logger.dart';

class YouTubeAuthDialog extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  final Function(String)? onAuthError;
  final VoidCallback? onCancel;

  const YouTubeAuthDialog({
    super.key,
    this.onAuthSuccess,
    this.onAuthError,
    this.onCancel,
  });

  @override
  State<YouTubeAuthDialog> createState() => _YouTubeAuthDialogState();
}

class _YouTubeAuthDialogState extends State<YouTubeAuthDialog> {
  final YouTubeAuthService _authService = YouTubeAuthService();
  bool _isLoading = false;
  bool _isYouTubeAppAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkYouTubeApp();
  }

  Future<void> _checkYouTubeApp() async {
    final isAvailable = await _authService.isYouTubeAppInstalled();
    if (mounted) {
      setState(() {
        _isYouTubeAppAvailable = isAvailable;
      });
    }
  }

  Future<void> _handleAuthMethod(Future<AuthResult> Function() authMethod) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await authMethod();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result.success) {
          AppLogger.info('Auth successful: ${result.message}');
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result.message)),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Call success callback
          widget.onAuthSuccess?.call();
          Navigator.of(context).pop();
        } else {
          AppLogger.error('Auth failed: ${result.message}');
          widget.onAuthError?.call(result.message);
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(result.message)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        final errorMessage = 'Authentication failed: $e';
        AppLogger.error(errorMessage);
        widget.onAuthError?.call(errorMessage);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      title: Row(
        children: [
          Icon(
            Icons.video_library,
            color: Colors.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text('YouTube Authentication'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose how you\'d like to authenticate with YouTube:',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            
            // Google Sign-In option
            _buildAuthOption(
              icon: Icons.account_circle,
              iconColor: Colors.blue,
              title: 'Google Sign-In',
              subtitle: 'Recommended - Full access with your Google account',
              onTap: _isLoading ? null : () => _handleAuthMethod(_authService.signInWithGoogle),
            ),
            
            const SizedBox(height: 12),
            
            // System browser option
            _buildAuthOption(
              icon: Icons.open_in_browser,
              iconColor: Colors.green,
              title: 'System Browser',
              subtitle: 'Login using your default browser',
              onTap: _isLoading ? null : () => _handleAuthMethod(_authService.signInWithBrowser),
            ),
            
            const SizedBox(height: 12),
            
            // YouTube app option (if available)
            if (_isYouTubeAppAvailable)
              _buildAuthOption(
                icon: Icons.play_circle_filled,
                iconColor: Colors.red,
                title: 'YouTube App',
                subtitle: 'Use your existing YouTube app login',
                onTap: _isLoading ? null : () => _handleAuthMethod(_authService.signInWithYouTubeApp),
              ),
            
            if (_isYouTubeAppAvailable)
              const SizedBox(height: 12),
            
            // Public access option
            _buildAuthOption(
              icon: Icons.public,
              iconColor: Colors.orange,
              title: 'Public Access',
              subtitle: 'No login required - Limited features',
              onTap: _isLoading ? null : () => _handleAuthMethod(_authService.usePublicAccess),
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
                      'Different methods provide different levels of access. Google Sign-In offers the best experience.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
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
          child: const Text('Cancel'),
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
                color: iconColor.withOpacity(0.1),
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                    ),
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

/// Helper function to show the auth dialog
Future<void> showYouTubeAuthDialog(
  BuildContext context, {
  VoidCallback? onAuthSuccess,
  Function(String)? onAuthError,
  VoidCallback? onCancel,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return YouTubeAuthDialog(
        onAuthSuccess: onAuthSuccess,
        onAuthError: onAuthError,
        onCancel: onCancel,
      );
    },
  );
}