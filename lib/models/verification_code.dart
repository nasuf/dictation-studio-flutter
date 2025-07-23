class VerificationCode {
  final String codePart;
  final String fullCode;
  final String duration;
  final int days;
  final int createdAt;
  final int expiresAt;
  final int remainingSeconds;

  VerificationCode({
    required this.codePart,
    required this.fullCode,
    required this.duration,
    required this.days,
    required this.createdAt,
    required this.expiresAt,
    required this.remainingSeconds,
  });

  factory VerificationCode.fromJson(Map<String, dynamic> json) {
    return VerificationCode(
      codePart: json['code_part'] ?? '',
      fullCode: json['full_code'] ?? '',
      duration: json['duration'] ?? '',
      days: json['days'] ?? 0,
      createdAt: _parseTimestamp(json['created_at']) ?? 0,
      expiresAt: _parseTimestamp(json['expires_at']) ?? 0,
      remainingSeconds: json['remaining_seconds'] ?? 0,
    );
  }

  // Helper method for type-safe timestamp parsing
  static int? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
  Map<String, dynamic> toJson() {
    return {
      'code_part': codePart,
      'full_code': fullCode,
      'duration': duration,
      'days': days,
      'created_at': createdAt,
      'expires_at': expiresAt,
      'remaining_seconds': remainingSeconds,
    };
  }

  bool get isExpired => remainingSeconds <= 0;

  String get timeRemaining {
    if (isExpired) return 'Expired';
    
    final days = remainingSeconds ~/ 86400;
    final hours = (remainingSeconds % 86400) ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    
    if (days > 0) {
      return '${days}d ${hours}h remaining';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m remaining';
    } else {
      return '${minutes}m remaining';
    }
  }

  @override
  String toString() {
    return 'VerificationCode{code: $codePart, duration: $duration, remaining: $timeRemaining}';
  }
}