import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../models/video.dart';
import '../utils/constants.dart';

class VideoCard extends StatelessWidget {
  final Video video;
  final double progress;
  final VoidCallback? onTap;
  final bool showProgress;

  const VideoCard({
    super.key,
    required this.video,
    this.progress = 0.0,
    this.onTap,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video thumbnail
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppConstants.cardBorderRadius),
                    ),
                    child: _buildVideoThumbnail(),
                  ),

                  // Play button overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppConstants.cardBorderRadius),
                        ),
                      ),
                      child: const Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 20,
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Progress indicator badge
                  if (showProgress && progress > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${progress.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Video info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.smallPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video title
                    Expanded(
                      child: Text(
                        video.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Progress bar
                    if (showProgress)
                      Column(
                        children: [
                          LinearPercentIndicator(
                            lineHeight: 4.0,
                            percent: progress / 100,
                            backgroundColor: Colors.grey.shade300,
                            progressColor: _getProgressColor(progress),
                            padding: EdgeInsets.zero,
                            barRadius: const Radius.circular(2),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),

                    // Date and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Progress percentage
                        Text(
                          progress > 0 ? '${progress.toInt()}%' : '0%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),

                        // Refined status
                        if (video.isRefined)
                          Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    return CachedNetworkImage(
      imageUrl: video.thumbnailUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'Thumbnail not available',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress < 25) {
      return Colors.grey;
    } else if (progress < 50) {
      return Colors.orange;
    } else if (progress < 75) {
      return Colors.yellow.shade600;
    } else {
      return Colors.green;
    }
  }
}
