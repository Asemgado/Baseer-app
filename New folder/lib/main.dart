import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:image/image.dart' as img;

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;

  File? _imageFile;
  String? _base64Image;

  @override
  void dispose() {
    _messageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // Function to check and request location permission at the start
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable them.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission is permanently denied, we cannot access location.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();

    _flutterTts.setLanguage("ar");
  }

  // Function to pick an image
  Future<void> pickImage(String message) async {
    if (!mounted) return;
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _base64Image = base64Encode(_imageFile!.readAsBytesSync());
        });

        await sendImageToApi(message);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image selected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to send message to chat API
  Future<void> sendMessageToChatApi(String message, bool isloaction) async {
    if (message.isEmpty) return;

    try {
      if (!isloaction) {
        setState(() {
          _isLoading = true;
          _messages.add({
            "type": "user",
            "text": message,
          });
        });
      }
      log(message);

      final uri = Uri.parse("https://basser-api.vercel.app/chat");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: utf8.encode(jsonEncode({"message": message})),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        log('Chat API Response: $responseBody');

        setState(() {
          _messages.add({
            "type": "ai",
            "order": responseBody['order'],
            "text": responseBody["message"] ?? "Response received.",
          });
        });
        await _flutterTts
            .speak(responseBody["message"] ?? "Response received.");
        if (responseBody['order'] == 'CAMERA') {
          await _openCamera();
        } else if (responseBody['order'] == 'LOCATION') {
          await getCurrentLocation();
        }

        await _flutterTts
            .speak(responseBody["message"] ?? "Response received.");
      } else {
        throw Exception("Failed to send message: ${response.statusCode}");
      }
    } catch (e) {
      log('Error sending message to chat API: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to open the camera
  Future<void> _openCamera() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        var image1 = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = File(pickedFile.path);
          _base64Image = base64Encode(image1);
        });

        await sendImageToApi('ماذا يوجد في الصورة ؟');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No image captured'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to send image to the API
  Future<void> sendImageToApi(String message) async {
    if (_base64Image == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _messages.add({"type": "user", "image": _imageFile});
        _messages.add({"type": "user", "text": message});
      });

      // Convert image to JPEG and then to base64
      final image = img.decodeImage(_imageFile!.readAsBytesSync());
      if (image == null) throw Exception("Failed to decode image");

      final jpegImage = img.encodeJpg(image);
      final base64Image = 'data:image/jpeg;base64,${base64Encode(jpegImage)}';

      final uri = Uri.parse("https://basser-api.vercel.app/image");
      String utf8Message = utf8.encode(message).toString();

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({
          "message": utf8Message,
          "image": base64Image,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        log('Image API Response: $responseBody');

        setState(() {
          _messages.add({
            "type": "ai",
            "text": responseBody["message"] ?? "Image processed successfully.",
          });
        });

        await _flutterTts
            .speak(responseBody["message"] ?? "Image processed successfully.");
      } else {
        throw Exception("Failed to process image: ${response.statusCode}");
      }
    } catch (e) {
      log('Error sending image to image API: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to start listening for voice input
  Future<void> startListening() async {
    try {
      bool available = await _speechToText.initialize();

      if (available) {
        setState(() {
          _isListening = true;
        });
        await _speechToText.listen(
            localeId: 'ar',
            onResult: (result) {
              setState(() {
                _messageController.text = result.recognizedWords;
              });
            });
      } else {
        throw Exception("Speech recognition not available.");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to stop listening and send the message
  Future<void> stopListening() async {
    setState(() {
      _isListening = false;
    });
    await _speechToText.stop();

    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      _messageController.clear();
      await sendMessageToChatApi(message, false);
      _messageController.clear();
    }
  }

  // Function to get current location
  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled. Please enable them.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Location permission is permanently denied, we cannot access location.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    final locationMessage =
        'موقعي الحالي: خط العرض: ${position.latitude} خط الطول اخبرني اين انا : ${position.longitude}';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(locationMessage),
        backgroundColor: Colors.blue,
      ),
    );
    await sendMessageToChatApi(locationMessage, true);
  }

  // Build method for UI
  Widget _buildMessage(Map<String, dynamic> message) {
    bool isUser = message["type"] == "user";
    File? imageFile = message["image"];

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.green,
          borderRadius: BorderRadius.circular(10),
        ),
        child: imageFile != null
            ? Image.file(
                imageFile,
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              )
            : Text(
                message["text"] ?? "",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat App"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessage(message);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.mic),
                color: _isListening ? Colors.red : Colors.blue,
                onPressed: _isListening ? stopListening : startListening,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: "Type your message",
                  ),
                  onSubmitted: (value) async {
                    if (value.isNotEmpty) {
                      await sendMessageToChatApi(value, false);
                      _messageController.clear();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  if (_messageController.text.isNotEmpty) {
                    await sendMessageToChatApi(_messageController.text, false);
                    _messageController.clear();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
