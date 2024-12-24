import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String _baseUrl = "https://basser-api.vercel.app";

  static Future<Map<String, dynamic>> sendMessage(String message) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/chat"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: utf8.encode(jsonEncode({"message": message})),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception("Failed to send message: ${response.statusCode}");
    }
  }

  static Future<Map<String, dynamic>> sendImage(String message, String base64Image) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/image"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode({
        "message": utf8.encode(message).toString(),
        "image": base64Image,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception("Failed to process image: ${response.statusCode}");
    }
  }
}