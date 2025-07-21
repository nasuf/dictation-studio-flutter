import 'package:json_annotation/json_annotation.dart';

part 'progress.g.dart';

@JsonSerializable()
class ProgressData {
  final String channelId;
  final String videoId;
  final Map<String, String> userInput;
  final double currentTime;
  final double overallCompletion;
  final double duration;
  final String? channelName;
  final String? videoTitle;
  final String? videoLink;

  const ProgressData({
    required this.channelId,
    required this.videoId,
    required this.userInput,
    required this.currentTime,
    required this.overallCompletion,
    required this.duration,
    this.channelName,
    this.videoTitle,
    this.videoLink,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) =>
      _$ProgressDataFromJson(json);
  Map<String, dynamic> toJson() => _$ProgressDataToJson(this);
}

@JsonSerializable()
class ChannelProgress {
  final Map<String, double> progress;

  const ChannelProgress({required this.progress});

  factory ChannelProgress.fromJson(Map<String, dynamic> json) =>
      _$ChannelProgressFromJson(json);
  Map<String, dynamic> toJson() => _$ChannelProgressToJson(this);

  // Get progress for a specific video
  double getVideoProgress(String videoId) => progress[videoId] ?? 0.0;

  // Check if video has any progress
  bool hasProgress(String videoId) =>
      progress.containsKey(videoId) && progress[videoId]! > 0;
}
