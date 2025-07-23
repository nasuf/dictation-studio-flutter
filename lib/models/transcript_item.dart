class TranscriptItem {
  final double start;
  final double end;
  final String transcript;
  final int? index;
  final String? userInput;

  TranscriptItem({
    required this.start,
    required this.end,
    required this.transcript,
    this.index,
    this.userInput,
  });

  factory TranscriptItem.fromJson(Map<String, dynamic> json) {
    return TranscriptItem(
      start: (json['start'] ?? 0).toDouble(),
      end: (json['end'] ?? 0).toDouble(),
      transcript: json['transcript'] ?? '',
      index: json['index'],
      userInput: json['userInput'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'transcript': transcript,
      if (index != null) 'index': index,
      if (userInput != null) 'userInput': userInput,
    };
  }

  // Duration in seconds
  double get duration => end - start;

  // Check if this item overlaps with another
  bool overlapsWith(TranscriptItem other) {
    return start < other.end && end > other.start;
  }

  // Check if this item contains a specific time
  bool containsTime(double time) {
    return time >= start && time <= end;
  }

  @override
  String toString() {
    return 'TranscriptItem{start: $start, end: $end, transcript: "$transcript"}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptItem &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          transcript == other.transcript;

  @override
  int get hashCode => start.hashCode ^ end.hashCode ^ transcript.hashCode;

  // Create a copy with modified properties
  TranscriptItem copyWith({
    double? start,
    double? end,
    String? transcript,
    int? index,
    String? userInput,
  }) {
    return TranscriptItem(
      start: start ?? this.start,
      end: end ?? this.end,
      transcript: transcript ?? this.transcript,
      index: index ?? this.index,
      userInput: userInput ?? this.userInput,
    );
  }
}

class TranscriptResponse {
  final List<TranscriptItem> transcript;

  TranscriptResponse({required this.transcript});

  factory TranscriptResponse.fromJson(Map<String, dynamic> json) {
    final transcriptList = json['transcript'] as List<dynamic>? ?? [];
    return TranscriptResponse(
      transcript: transcriptList
          .map((item) => TranscriptItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transcript': transcript.map((item) => item.toJson()).toList(),
    };
  }
}