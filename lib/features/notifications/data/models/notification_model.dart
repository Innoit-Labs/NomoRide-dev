class NotificationModel {
  final String id;
  final String title;
  final String message;
  final int? recipients;
  final bool isRead;
  final DateTime? createdAt;
  final String? rawCreatedAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.recipients,
    this.isRead = false,
    this.createdAt,
    this.rawCreatedAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final dateRaw = json['created_at'] ?? json['createdAt'] ?? json['time'];
    if (dateRaw != null) {
      try {
        parsedDate = DateTime.parse(dateRaw.toString());
      } catch (_) {}
    }

    final isReadRaw = json['is_read'] ?? json['isRead'];
    final isRead = isReadRaw == true || isReadRaw == 1 || isReadRaw == '1';

    final recipientsRaw = json['recipients'];
    int? recipients;
    if (recipientsRaw is num) {
      recipients = recipientsRaw.toInt();
    } else if (recipientsRaw is String) {
      recipients = int.tryParse(recipientsRaw);
    }

    return NotificationModel(
      id: (json['notification_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? json['subtitle'] ?? json['body'] ?? '').toString(),
      recipients: recipients,
      isRead: isRead,
      createdAt: parsedDate,
      rawCreatedAt: dateRaw?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notification_id': id,
      'title': title,
      'message': message,
      'recipients': recipients,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt?.toIso8601String() ?? rawCreatedAt,
    };
  }

  String get formattedTime {
    if (createdAt != null) {
      final now = DateTime.now();
      final difference = now.difference(createdAt!.toLocal());

      if (difference.isNegative || difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins min${mins == 1 ? '' : 's'} ago';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours hr${hours == 1 ? '' : 's'} ago';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return '$days day${days == 1 ? '' : 's'} ago';
      } else {
        final local = createdAt!.toLocal();
        final day = local.day.toString().padLeft(2, '0');
        final month = local.month.toString().padLeft(2, '0');
        final year = local.year.toString();
        return '$day/$month/$year';
      }
    }
    return rawCreatedAt ?? '';
  }
}
