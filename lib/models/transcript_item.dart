class TranscriptItem {
  final double start;
  final double end;
  final String transcript;

  TranscriptItem({
    required this.start,
    required this.end,
    required this.transcript,
  });

  factory TranscriptItem.fromJson(Map<String, dynamic> json) {
    return TranscriptItem(
      start: (json['start'] ?? 0).toDouble(),
      end: (json['end'] ?? 0).toDouble(),
      transcript: json['transcript'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      'end': end,
      'transcript': transcript,
    };
  }

  @override
  String toString() {
    return 'TranscriptItem{start: $start, end: $end, transcript: $transcript}';
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