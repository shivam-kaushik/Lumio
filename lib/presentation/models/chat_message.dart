enum ChatSender { user, ai, system }

class ChatMessage {
  final String id;
  final String text;
  final ChatSender sender;
  final DateTime timestamp;
  final Map<String, dynamic>? actionData; // If this message triggers an action (e.g. Plan Created)
  final bool isAction;
  final String? actionType;

  ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.actionData,
    this.isAction = false,
    this.actionType,
  });

  factory ChatMessage.user(String text) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      sender: ChatSender.user,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.ai(String text) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      sender: ChatSender.ai,
      timestamp: DateTime.now(),
    );
  }
  
  factory ChatMessage.action(String text, Map<String, dynamic> data, {String? type}) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      sender: ChatSender.ai,
      timestamp: DateTime.now(),
      isAction: true,
      actionData: data,
      actionType: type,
    );
  }
}
