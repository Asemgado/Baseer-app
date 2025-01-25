import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  static const String _baseUrl = "https://basser-api.vercel.app";
  //why map
  static Future<Map<String, dynamic>> sendMessage(String message) async {
    final userID = (await SharedPreferences.getInstance()).getString('user_id');

    final response = await http.post(
      Uri.parse("$_baseUrl/chat"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: utf8.encode(jsonEncode({"user_id": userID, "message": message})),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception("Failed to send message: ${response.statusCode}");
    }
  }

  static Future<Map<String, dynamic>> sendEmergency(String message) async {
    final userID = (await SharedPreferences.getInstance()).getString('user_id');
    final response = await http.post(
      Uri.parse("$_baseUrl/emergency"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: utf8.encode(jsonEncode({'user_id': userID, "message": message})),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception("Failed to send message: ${response.statusCode}");
    }
  }

  static Future<Map<String, dynamic>> sendImage(
      String message, String base64Image) async {
    final userID = (await SharedPreferences.getInstance()).getString('user_id');

    log(base64Image);
    final response = await http.post(
      Uri.parse("$_baseUrl/image"),
      headers: {"Content-Type": "application/json; charset=utf-8"},
      body: jsonEncode({
        'user_id': userID,
        "message": message.toString(),
        "image": base64Image,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      log(response.body);
      throw Exception("Failed to process image: ${response.body}");
    }
  }
}
