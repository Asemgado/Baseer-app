import 'dart:io';

class ChatMessage {
  final String? text;
  final File? image;
  final String type;
  final String? order;

  ChatMessage({
    this.text,
    this.image,
    required this.type,
    this.order,
  });

  bool get isUser => type == 'user';
}