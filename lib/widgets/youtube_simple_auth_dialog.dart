import 'package:flutter/material.dart';

import '../generated/app_localizations.dart';
import '../services/youtube_simple_auth_service.dart';
import '../utils/logger.dart';
import 'youtube_login_webview.dart';

/// 简化后的授权弹窗：统一引导用户在内置 WebView 登录。
class YouTubeSimpleAuthDialog extends StatefulWidget {
  const YouTubeSimpleAuthDialog({
    super.key,
    this.onAuthSuccess,
    this.onAuthError,
  });

  final VoidCallback? onAuthSuccess;
  final Function(String message)? onAuthError;

  @override
  State<YouTubeSimpleAuthDialog> createState() => _YouTubeSimpleAuthDialogState();
}

class _YouTubeSimpleAuthDialogState extends State<YouTubeSimpleAuthDialog> {
  final YouTubeSimpleAuthService _authService = YouTubeSimpleAuthService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.youtubeLoginRequired),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.youtubeLoginDescription1,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _buildStepItem(theme, '1. ${l10n.loginToYoutube}'),
          _buildStepItem(theme, '2. ${l10n.refreshingAfterLogin}'),
          _buildStepItem(theme, '3. ${l10n.youtubeAuthSuccessMessage}'),
          const SizedBox(height: 12),
          Text(
            l10n.videoPlayerLoginSuggestion,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _isProcessing ? null : _openLoginWebView,
          icon: const Icon(Icons.lock_open),
          label: Text(l10n.loginToYoutube),
        ),
      ],
    );
  }

  Widget _buildStepItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLoginWebView() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const YouTubeLoginWebView()),
      );

      setState(() => _isProcessing = false);

      if (result == true) {
        await _authService.prepareYouTubePlayerEnvironment();
        _authService.debugAuthState('dialog-success');
        widget.onAuthSuccess?.call();
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        AppLogger.info('YouTube login cancelled');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      final message = '登录失败：$e';
      AppLogger.error(message);
      widget.onAuthError?.call(message);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }
}

Future<void> showYouTubeSimpleAuthDialog({
  required BuildContext context,
  VoidCallback? onAuthSuccess,
  Function(String message)? onAuthError,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => YouTubeSimpleAuthDialog(
      onAuthSuccess: onAuthSuccess,
      onAuthError: onAuthError,
    ),
  );
}
