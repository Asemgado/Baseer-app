import 'dart:io';

class ChatMessage {
  final String? text;
  final File? image;
  final String type;
  final String? order;
  final String? phone;

  ChatMessage({
    this.text,
    this.image,
    required this.type,
    this.order,
    this.phone,
  });

  bool get isUser => type == 'user';
}
