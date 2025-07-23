class ProgressData {
  final String channelId;
  final String videoId;
  final Map<int, String> userInput;
  final int currentTime;
  final double overallCompletion;
  final int duration;
  final String? channelName;
  final String? videoTitle;
  final String? videoLink;

  ProgressData({
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

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      channelId: json['channelId'] ?? '',
      videoId: json['videoId'] ?? '',
      userInput: _parseUserInput(json['userInput'] ?? {}),
      currentTime: json['currentTime'] ?? 0,
      overallCompletion: (json['overallCompletion'] ?? 0).toDouble(),
      duration: json['duration'] ?? 0,
      channelName: json['channelName'],
      videoTitle: json['videoTitle'],
      videoLink: json['videoLink'],
    );
  }

  // Helper method to parse userInput with proper type conversion
  static Map<int, String> _parseUserInput(dynamic userInput) {
    if (userInput == null) return {};
    
    Map<int, String> result = {};
    if (userInput is Map) {
      userInput.forEach((key, value) {
        int? intKey;
        if (key is int) {
          intKey = key;
        } else if (key is String) {
          intKey = int.tryParse(key);
        }
        
        if (intKey != null && value is String) {
          result[intKey] = value;
        }
      });
    }
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'channelId': channelId,
      'videoId': videoId,
      'userInput': userInput,
      'currentTime': currentTime,
      'overallCompletion': overallCompletion,
      'duration': duration,
      'channelName': channelName,
      'videoTitle': videoTitle,
      'videoLink': videoLink,
    };
  }

  @override
  String toString() {
    return 'ProgressData{channelId: $channelId, videoId: $videoId, completion: ${overallCompletion.toStringAsFixed(1)}%}';
  }
}