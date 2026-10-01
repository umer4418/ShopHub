class SupportMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole; // 'customer' or 'admin'
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  bool get isFromAdmin => senderRole.toLowerCase() == 'admin';
  bool get isFromCustomer => senderRole.toLowerCase() == 'customer';

  SupportMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderRole,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'message': message,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toSupabaseMap() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'sender_type': senderRole,
        'sender_role': senderRole,
        'message': message,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'] as String? ?? '',
      conversationId: (json['conversation_id'] ?? json['conversationId']) as String? ?? '',
      senderId: (json['sender_id'] ?? json['senderId']) as String? ?? '',
      senderRole: (json['sender_role'] ?? json['sender_type'] ?? json['senderRole'] ?? json['senderType']) as String? ?? 'customer',
      message: (json['message'] ?? json['text']) as String? ?? '',
      isRead: (json['is_read'] ?? json['isRead']) as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
              : DateTime.now()),
    );
  }
}
