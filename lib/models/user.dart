class Plan {
  final String name;
  final int? expireTime;
  final bool isRecurring;
  final String status;
  final int? nextPaymentTime;

  Plan({
    required this.name,
    this.expireTime,
    this.isRecurring = false,
    required this.status,
    this.nextPaymentTime,
  });

  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      name: json['name'] ?? 'Free',
      expireTime: _parseTimestamp(json['expireTime']),
      isRecurring: json['isRecurring'] ?? false,
      status: json['status'] ?? 'active',
      nextPaymentTime: _parseTimestamp(json['nextPaymentTime']),
    );
  }
  
  static int? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      // Try to parse string as integer
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
      
      // Try to parse as double and convert to int (in case of decimal)
      final double? doubleVal = double.tryParse(value);
      if (doubleVal != null) return doubleVal.toInt();
    }
    if (value is double) return value.toInt();
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'expireTime': expireTime,
      'isRecurring': isRecurring,
      'status': status,
      'nextPaymentTime': nextPaymentTime,
    };
  }
}

class ShortcutKeys {
  final String repeat;
  final String next;
  final String prev;

  ShortcutKeys({
    this.repeat = 'Tab',
    this.next = 'Enter',
    this.prev = 'ControlLeft',
  });

  factory ShortcutKeys.fromJson(Map<String, dynamic> json) {
    return ShortcutKeys(
      repeat: json['repeat'] ?? 'Tab',
      next: json['next'] ?? 'Enter',
      prev: json['prev'] ?? 'ControlLeft',
    );
  }

  Map<String, dynamic> toJson() {
    return {'repeat': repeat, 'next': next, 'prev': prev};
  }
}

class DictationConfig {
  final double playbackSpeed;
  final int autoRepeat;
  final ShortcutKeys shortcuts;
  final String? language;

  DictationConfig({
    this.playbackSpeed = 1.0,
    this.autoRepeat = 0,
    required this.shortcuts,
    this.language,
  });

  factory DictationConfig.fromJson(Map<String, dynamic> json) {
    return DictationConfig(
      playbackSpeed: (json['playback_speed'] ?? 1.0).toDouble(),
      autoRepeat: json['auto_repeat'] ?? 0,
      shortcuts: ShortcutKeys.fromJson(json['shortcuts'] ?? {}),
      language: json['language'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playback_speed': playbackSpeed,
      'auto_repeat': autoRepeat,
      'shortcuts': shortcuts.toJson(),
      'language': language,
    };
  }
}

class DictationProgress {
  final Map<int, String> userInput;
  final int currentTime;
  final double overallCompletion;

  DictationProgress({
    required this.userInput,
    required this.currentTime,
    required this.overallCompletion,
  });

  factory DictationProgress.fromJson(Map<String, dynamic> json) {
    // Convert string keys to int keys for userInput
    Map<int, String> userInput = {};
    final rawUserInput = json['userInput'] ?? {};
    if (rawUserInput is Map) {
      rawUserInput.forEach((key, value) {
        final intKey = int.tryParse(key.toString()) ?? 0;
        userInput[intKey] = value.toString();
      });
    }
    
    return DictationProgress(
      userInput: userInput,
      currentTime: _parseIntValue(json['currentTime']) ?? 0,
      overallCompletion: _parseDoubleValue(json['overallCompletion']) ?? 0.0,
    );
  }

  // Helper methods for type-safe parsing
  static int? _parseIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDoubleValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    // Convert int keys to string keys for JSON serialization
    Map<String, String> userInputJson = {};
    userInput.forEach((key, value) {
      userInputJson[key.toString()] = value;
    });
    
    return {
      'userInput': userInputJson,
      'currentTime': currentTime,
      'overallCompletion': overallCompletion,
    };
  }
}

class User {
  final String? id;
  final String email;
  final String username;
  final String avatar;
  final String language;
  final Plan plan;
  final String role;
  final DictationConfig dictationConfig;
  final int createdAt;
  final int? updatedAt;
  final Map<String, DictationProgress>? dictationProgress;

  User({
    this.id,
    required this.email,
    required this.username,
    required this.avatar,
    required this.language,
    required this.plan,
    required this.role,
    required this.dictationConfig,
    required this.createdAt,
    this.updatedAt,
    this.dictationProgress,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse dictation_progress
    Map<String, DictationProgress>? dictationProgress;
    if (json['dictation_progress'] != null) {
      dictationProgress = {};
      final progressData = json['dictation_progress'] as Map<String, dynamic>;
      progressData.forEach((key, value) {
        if (value != null) {
          dictationProgress![key] = DictationProgress.fromJson(value as Map<String, dynamic>);
        }
      });
    }

    return User(
      id: json['id'],
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatar: json['avatar'] ?? '',
      language: json['language'] ?? 'en',
      plan: Plan.fromJson(json['plan'] ?? {}),
      role: json['role'] ?? 'User',
      dictationConfig: DictationConfig.fromJson(json['dictation_config'] ?? {}),
      createdAt: _parseIntValue(json['created_at']) ?? 0,
      updatedAt: _parseIntValue(json['updated_at']),
      dictationProgress: dictationProgress,
    );
  }

  // Helper method for type-safe int parsing
  static int? _parseIntValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'avatar': avatar,
      'language': language,
      'plan': plan.toJson(),
      'role': role,
      'dictation_config': dictationConfig.toJson(),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'dictation_progress': dictationProgress?.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? username,
    String? avatar,
    String? language,
    Plan? plan,
    String? role,
    DictationConfig? dictationConfig,
    int? createdAt,
    int? updatedAt,
    Map<String, DictationProgress>? dictationProgress,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      avatar: avatar ?? this.avatar,
      language: language ?? this.language,
      plan: plan ?? this.plan,
      role: role ?? this.role,
      dictationConfig: dictationConfig ?? this.dictationConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dictationProgress: dictationProgress ?? this.dictationProgress,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && email == other.email;

  @override
  int get hashCode => email.hashCode;

  // Calculate last meaningful dictation input timestamp
  int getLastMeaningfulDictationInputTimestamp() {
    if (dictationProgress == null) return 0;
    
    int lastTimestamp = 0;
    
    for (final progress in dictationProgress!.values) {
      // Check if user has meaningful input (non-empty and length > 5)
      bool hasMeaningfulInput = progress.userInput.values
          .any((input) => input.isNotEmpty && input.length > 5);
      
      if (hasMeaningfulInput && progress.currentTime > lastTimestamp) {
        lastTimestamp = progress.currentTime;
      }
    }
    
    return lastTimestamp;
  }

  // Check if user has dictation input
  bool hasDictationInput() {
    if (dictationProgress == null) return false;
    
    return dictationProgress!.values.any((progress) =>
        progress.userInput.values.any((input) => input.isNotEmpty && input.length > 5));
  }

  // Get formatted last active date
  String getLastActiveDate() {
    final timestamp = getLastMeaningfulDictationInputTimestamp();
    if (timestamp == 0) return 'Never';
    
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  String toString() {
    return 'User{email: $email, username: $username, role: $role, plan: ${plan.name}}';
  }
}
