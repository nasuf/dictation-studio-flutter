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
  @JsonKey(defaultValue: <String>[])
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

  factory Channel.fromJson(Map<String, dynamic> json) {
    // Handle null values with defaults
    return Channel(
      name: json['name'] as String? ?? '',
      id: json['id'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'public',
      language: json['language'] as String? ?? 'en',
      link: json['link'] as String? ?? '',
      videos:
          (json['videos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[],
    );
  }

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

  // Copy with method for updating properties
  Channel copyWith({
    String? name,
    String? id,
    String? imageUrl,
    String? visibility,
    String? language,
    String? link,
    List<String>? videos,
  }) {
    return Channel(
      name: name ?? this.name,
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      visibility: visibility ?? this.visibility,
      language: language ?? this.language,
      link: link ?? this.link,
      videos: videos ?? this.videos,
    );
  }
}
