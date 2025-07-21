// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Channel _$ChannelFromJson(Map<String, dynamic> json) => Channel(
  name: json['name'] as String,
  id: json['id'] as String,
  imageUrl: json['image_url'] as String,
  visibility: json['visibility'] as String,
  language: json['language'] as String,
  link: json['link'] as String,
  videos:
      (json['videos'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      [],
);

Map<String, dynamic> _$ChannelToJson(Channel instance) => <String, dynamic>{
  'name': instance.name,
  'id': instance.id,
  'image_url': instance.imageUrl,
  'visibility': instance.visibility,
  'language': instance.language,
  'link': instance.link,
  'videos': instance.videos,
};
