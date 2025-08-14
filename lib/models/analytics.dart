class AnalyticsSummary {
  final int totalVideos;
  final int publicVideos;
  final int privateVideos;
  final int refinedVideos;
  final int unrefinedVideos;

  AnalyticsSummary({
    required this.totalVideos,
    required this.publicVideos,
    required this.privateVideos,
    required this.refinedVideos,
    required this.unrefinedVideos,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      totalVideos: json['total_videos'] ?? 0,
      publicVideos: json['public_videos'] ?? 0,
      privateVideos: json['private_videos'] ?? 0,
      refinedVideos: json['refined_videos'] ?? 0,
      unrefinedVideos: json['unrefined_videos'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_videos': totalVideos,
      'public_videos': publicVideos,
      'private_videos': privateVideos,
      'refined_videos': refinedVideos,
      'unrefined_videos': unrefinedVideos,
    };
  }
}

class ChannelAnalytics {
  final String channelId;
  final String channelName;
  final int totalVideos;
  final int publicVideos;
  final int privateVideos;
  final int refinedVideos;

  ChannelAnalytics({
    required this.channelId,
    required this.channelName,
    required this.totalVideos,
    required this.publicVideos,
    required this.privateVideos,
    required this.refinedVideos,
  });

  factory ChannelAnalytics.fromJson(Map<String, dynamic> json) {
    return ChannelAnalytics(
      channelId: json['channel_id'] ?? '',
      channelName: json['channel_name'] ?? 'Unknown Channel',
      totalVideos: json['total_videos'] ?? 0,
      publicVideos: json['public_videos'] ?? 0,
      privateVideos: json['private_videos'] ?? 0,
      refinedVideos: json['refined_videos'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'channel_name': channelName,
      'total_videos': totalVideos,
      'public_videos': publicVideos,
      'private_videos': privateVideos,
      'refined_videos': refinedVideos,
    };
  }

  // Calculate unrefined videos
  int get unrefinedVideos => totalVideos - refinedVideos;
}

class Analytics {
  final AnalyticsSummary summary;
  final List<ChannelAnalytics> channels;
  final int timestamp;

  Analytics({
    required this.summary,
    required this.channels,
    required this.timestamp,
  });

  factory Analytics.fromJson(Map<String, dynamic> json) {
    return Analytics(
      summary: AnalyticsSummary.fromJson(json['summary'] ?? {}),
      channels: (json['channels'] as List<dynamic>? ?? [])
          .map((channelJson) => ChannelAnalytics.fromJson(channelJson))
          .toList(),
      timestamp: json['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'summary': summary.toJson(),
      'channels': channels.map((channel) => channel.toJson()).toList(),
      'timestamp': timestamp,
    };
  }
}