// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProgressData _$ProgressDataFromJson(Map<String, dynamic> json) => ProgressData(
  channelId: json['channelId'] as String,
  videoId: json['videoId'] as String,
  userInput: Map<String, String>.from(json['userInput'] as Map),
  currentTime: (json['currentTime'] as num).toDouble(),
  overallCompletion: (json['overallCompletion'] as num).toDouble(),
  duration: (json['duration'] as num).toDouble(),
  channelName: json['channelName'] as String?,
  videoTitle: json['videoTitle'] as String?,
  videoLink: json['videoLink'] as String?,
);

Map<String, dynamic> _$ProgressDataToJson(ProgressData instance) =>
    <String, dynamic>{
      'channelId': instance.channelId,
      'videoId': instance.videoId,
      'userInput': instance.userInput,
      'currentTime': instance.currentTime,
      'overallCompletion': instance.overallCompletion,
      'duration': instance.duration,
      'channelName': instance.channelName,
      'videoTitle': instance.videoTitle,
      'videoLink': instance.videoLink,
    };

ChannelProgress _$ChannelProgressFromJson(Map<String, dynamic> json) =>
    ChannelProgress(
      progress: (json['progress'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ),
    );

Map<String, dynamic> _$ChannelProgressToJson(ChannelProgress instance) =>
    <String, dynamic>{'progress': instance.progress};
