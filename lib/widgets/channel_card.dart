import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../utils/constants.dart';
import '../theme/app_colors.dart';

class ChannelCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onTap;

  const ChannelCard({super.key, required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Channel image with fixed height
            SizedBox(
              height: 120,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppConstants.cardBorderRadius),
                ),
                child: _buildChannelImage(),
              ),
            ),

            // Channel info
            Padding(
              padding: const EdgeInsets.all(AppConstants.smallPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel name
                  Text(
                    channel.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Language and video count row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Language badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getLanguageColor(),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          channel.displayLanguage,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),

                      // Video count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E8), // Light green background
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${channel.videoCount} videos',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.techBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelImage() {
    return CachedNetworkImage(
      imageUrl: channel.imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 4),
            Text(
              'Channel',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color _getLanguageColor() {
    switch (channel.language.toLowerCase()) {
      case 'en':
        return AppColors.getLanguageColor('en');
      case 'zh':
        return AppColors.getLanguageColor('zh');
      case 'es':
        return AppColors.getLanguageColor('es');
      case 'fr':
        return AppColors.getLanguageColor('fr');
      case 'de':
        return AppColors.getLanguageColor('de');
      case 'ja':
        return AppColors.getLanguageColor('ja');
      case 'ko':
        return const Color(0xFF009688); // Teal (compatible with green theme)
      default:
        return const Color(0xFF9E9E9E); // Grey for unknown
    }
  }
}
