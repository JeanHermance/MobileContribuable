class NotificationModel {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final bool isArchived;
  final String priority;
  final Map<String, bool> channels;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    required this.isRead,
    required this.isArchived,
    required this.priority,
    required this.channels,
    this.scheduledAt,
    this.sentAt,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final priorityString = _safeParseString(json['priority']);
    return NotificationModel(
      id: _safeParseString(json['id_notification'] ?? json['id']),
      userId: _safeParseString(json['userId']),
      type: _safeParseString(json['type']),
      title: _safeParseString(json['title']),
      message: _safeParseString(json['message']),
      data: json['data'] as Map<String, dynamic>?,
      isRead: _safeParseBool(json['isRead']),
      isArchived: _safeParseBool(json['isArchived']),
      priority: priorityString.isEmpty ? 'MEDIUM' : priorityString,
      channels: _safeParseChannels(json['channels']),
      scheduledAt: _safeParseDateTime(json['scheduledAt']),
      sentAt: _safeParseDateTime(json['sentAt']),
      readAt: _safeParseDateTime(json['readAt']),
      createdAt: _safeParseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _safeParseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }
  
  /// Convertit de manière sécurisée une valeur en String
  static String _safeParseString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }
  
  /// Convertit de manière sécurisée une valeur en bool
  static bool _safeParseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    if (value is int) return value != 0;
    return false;
  }
  
  /// Convertit de manière sécurisée une valeur en DateTime
  static DateTime? _safeParseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
  
  /// Convertit de manière sécurisée les channels
  static Map<String, bool> _safeParseChannels(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key, _safeParseBool(val)));
    }
    return {};
  }

  Map<String, dynamic> toJson() {
    return {
      'id_notification': id,
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'data': data,
      'isRead': isRead,
      'isArchived': isArchived,
      'priority': priority,
      'channels': channels,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    Map<String, dynamic>? data,
    bool? isRead,
    bool? isArchived,
    String? priority,
    Map<String, bool>? channels,
    DateTime? scheduledAt,
    DateTime? sentAt,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      isArchived: isArchived ?? this.isArchived,
      priority: priority ?? this.priority,
      channels: channels ?? this.channels,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
