// lib/models/chat_model.dart

class Chat {
  final String name;
  final String time;
  final String avatarAsset;
  final String lastMessage;
  final bool isGroup;
  final bool isOnline;
  final bool hasUnreadMessages;

  Chat({
    required this.name,
    required this.time,
    required this.avatarAsset,
    required this.lastMessage,
    this.isGroup = false,
    this.isOnline = false,
    this.hasUnreadMessages = false,
  });
}
