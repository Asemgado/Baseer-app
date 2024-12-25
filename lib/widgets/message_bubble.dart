import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.green,
          borderRadius: BorderRadius.circular(10),
        ),
        child: message.image != null
            ? Image.file(
                message.image!,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              )
            : Text(
                message.text ?? "",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
      ),
    );
  }
}
