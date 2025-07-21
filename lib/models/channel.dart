import 'package:json_annotation/json_annotation.dart';

part 'channel.g.dart';

@JsonSerializable()
class Channel {
  final String name;
  final String id;
  @JsonKey(name: 'image_url')
  final String imageUrl;
  final String visibility;
  final String language;
  final String link;
  final List<String> videos;

  const Channel({
    required this.name,
    required this.id,
    required this.imageUrl,
    required this.visibility,
    required this.language,
    required this.link,
    required this.videos,
  });

  factory Channel.fromJson(Map<String, dynamic> json) =>
      _$ChannelFromJson(json);
  Map<String, dynamic> toJson() => _$ChannelToJson(this);

  // Get display language name
  String get displayLanguage {
    switch (language) {
      case 'en':
        return 'English';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      case 'ko':
        return 'Korean';
      default:
        return language.toUpperCase();
    }
  }

  // Check if channel is public
  bool get isPublic => visibility == 'public';

  // Get video count
  int get videoCount => videos.length;
}
