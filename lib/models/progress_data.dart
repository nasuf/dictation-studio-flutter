/// 听写进度数据模型
class ProgressData {
  final String channelId;
  final String channelName;
  final String videoId;
  final String videoTitle;
  final String videoLink;
  final double overallCompletion;
  final Map<int, String>? userInput;
  final double? currentTime;
  final double? duration;

  const ProgressData({
    required this.channelId,
    required this.channelName,
    required this.videoId,
    required this.videoTitle,
    required this.videoLink,
    required this.overallCompletion,
    this.userInput,
    this.currentTime,
    this.duration,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      channelId: json['channelId'] as String,
      channelName: json['channelName'] as String? ?? '',
      videoId: json['videoId'] as String,
      videoTitle: json['videoTitle'] as String? ?? '',
      videoLink: json['videoLink'] as String? ?? '',
      overallCompletion: (json['overallCompletion'] as num?)?.toDouble() ?? 0.0,
      userInput: json['userInput'] != null 
          ? Map<int, String>.from(json['userInput'])
          : null,
      currentTime: (json['currentTime'] as num?)?.toDouble(),
      duration: (json['duration'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channelId': channelId,
      'channelName': channelName,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'videoLink': videoLink,
      'overallCompletion': overallCompletion,
      if (userInput != null) 'userInput': userInput,
      if (currentTime != null) 'currentTime': currentTime,
      if (duration != null) 'duration': duration,
    };
  }

  @override
  String toString() {
    return 'ProgressData{channelId: $channelId, channelName: $channelName, videoId: $videoId, videoTitle: $videoTitle, overallCompletion: $overallCompletion}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressData &&
          runtimeType == other.runtimeType &&
          channelId == other.channelId &&
          videoId == other.videoId;

  @override
  int get hashCode => channelId.hashCode ^ videoId.hashCode;
}