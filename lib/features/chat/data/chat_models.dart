class ChatContact {
  const ChatContact({
    required this.id,
    required this.type,
    required this.name,
    this.subtitle,
  });

  final int id;
  final String type;
  final String name;
  final String? subtitle;

  factory ChatContact.fromJson(Map<String, dynamic> json) => ChatContact(
        id: (json['id'] as num?)?.toInt() ?? 0,
        type: '${json['type'] ?? ''}',
        name: '${json['name'] ?? 'Kontak'}',
        subtitle: json['subtitle']?.toString(),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.message,
    required this.senderName,
    required this.isMine,
    this.createdAt,
  });

  final int id;
  final String message;
  final String senderName;
  final bool isMine;
  final DateTime? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] as num?)?.toInt() ?? 0,
        message: '${json['message'] ?? ''}',
        senderName: '${json['sender_name'] ?? 'Kontak'}',
        isMine: json['is_mine'] == true,
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
      );
}
