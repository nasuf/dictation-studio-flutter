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
      expireTime: json['expireTime'],
      isRecurring: json['isRecurring'] ?? false,
      status: json['status'] ?? 'active',
      nextPaymentTime: json['nextPaymentTime'],
    );
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
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatar: json['avatar'] ?? '',
      language: json['language'] ?? 'en',
      plan: Plan.fromJson(json['plan'] ?? {}),
      role: json['role'] ?? 'user',
      dictationConfig: DictationConfig.fromJson(json['dictation_config'] ?? {}),
      createdAt: json['created_at'] ?? 0,
      updatedAt: json['updated_at'],
    );
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && email == other.email;

  @override
  int get hashCode => email.hashCode;

  @override
  String toString() {
    return 'User{email: $email, username: $username, role: $role, plan: ${plan.name}}';
  }
}
