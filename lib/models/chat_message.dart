class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> quickReplies;
  final String? orderId;
  final bool isGuardrail;
  final bool isLoading;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickReplies = const [],
    this.orderId,
    this.isGuardrail = false,
    this.isLoading = false,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<String>? quickReplies,
    String? orderId,
    bool? isGuardrail,
    bool? isLoading,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      quickReplies: quickReplies ?? this.quickReplies,
      orderId: orderId ?? this.orderId,
      isGuardrail: isGuardrail ?? this.isGuardrail,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'quickReplies': quickReplies,
        'orderId': orderId,
        'isGuardrail': isGuardrail,
        'isLoading': isLoading,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        text: json['text'] as String? ?? '',
        isUser: json['isUser'] as bool? ?? false,
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
        quickReplies: (json['quickReplies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        orderId: json['orderId'] as String?,
        isGuardrail: json['isGuardrail'] as bool? ?? false,
        isLoading: json['isLoading'] as bool? ?? false,
      );
}
