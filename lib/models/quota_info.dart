class QuotaInfo {
  final int used;
  final int limit;
  final bool canProceed;
  final bool notifyQuota;
  final DateTime? startDate;
  final DateTime? endDate;

  const QuotaInfo({
    required this.used,
    required this.limit,
    required this.canProceed,
    required this.notifyQuota,
    this.startDate,
    this.endDate,
  });

  factory QuotaInfo.fromJson(Map<String, dynamic> json) {
    return QuotaInfo(
      used: _parseInt(json['used']) ?? 0,
      limit: _parseInt(json['limit']) ?? -1,
      canProceed: json['canProceed'] == true,
      notifyQuota: json['notifyQuota'] == true,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
    );
  }

  @override
  String toString() {
    return 'QuotaInfo(used: $used, limit: $limit, canProceed: $canProceed, notifyQuota: $notifyQuota, startDate: $startDate, endDate: $endDate)';
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      // Assume milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
