import 'package:json_annotation/json_annotation.dart';

part 'video.g.dart';

@JsonSerializable()
class Video {
  @JsonKey(name: 'video_id')
  final String videoId;
  final String title;
  final String link;
  final String visibility;
  @JsonKey(name: 'created_at')
  final int createdAt;
  @JsonKey(name: 'updated_at')
  final int updatedAt;
  @JsonKey(name: 'is_refined')
  final bool isRefined;
  @JsonKey(name: 'refined_at')
  final int? refinedAt;

  const Video({
    required this.videoId,
    required this.title,
    required this.link,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    required this.isRefined,
    this.refinedAt,
  });

  factory Video.fromJson(Map<String, dynamic> json) => _$VideoFromJson(json);
  Map<String, dynamic> toJson() => _$VideoToJson(this);

  // Get YouTube thumbnail URL
  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

  // Get formatted creation date
  DateTime get createdDate =>
      DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

  // Get formatted update date
  DateTime get updatedDate =>
      DateTime.fromMillisecondsSinceEpoch(updatedAt * 1000);

  // Check if video is public
  bool get isPublic => visibility == 'public';

  // Get YouTube watch URL
  String get youtubeUrl => 'https://www.youtube.com/watch?v=$videoId';
}

@JsonSerializable()
class VideoListResponse {
  final List<Video> videos;

  const VideoListResponse({required this.videos});

  factory VideoListResponse.fromJson(Map<String, dynamic> json) =>
      _$VideoListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$VideoListResponseToJson(this);
}
