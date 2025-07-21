// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Video _$VideoFromJson(Map<String, dynamic> json) => Video(
  videoId: json['video_id'] as String,
  title: json['title'] as String,
  link: json['link'] as String,
  visibility: json['visibility'] as String,
  createdAt: (json['created_at'] as num).toInt(),
  updatedAt: (json['updated_at'] as num).toInt(),
  isRefined: json['is_refined'] as bool,
  refinedAt: (json['refined_at'] as num?)?.toInt(),
);

Map<String, dynamic> _$VideoToJson(Video instance) => <String, dynamic>{
  'video_id': instance.videoId,
  'title': instance.title,
  'link': instance.link,
  'visibility': instance.visibility,
  'created_at': instance.createdAt,
  'updated_at': instance.updatedAt,
  'is_refined': instance.isRefined,
  'refined_at': instance.refinedAt,
};

VideoListResponse _$VideoListResponseFromJson(Map<String, dynamic> json) =>
    VideoListResponse(
      videos: (json['videos'] as List<dynamic>)
          .map((e) => Video.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VideoListResponseToJson(VideoListResponse instance) =>
    <String, dynamic>{'videos': instance.videos};
