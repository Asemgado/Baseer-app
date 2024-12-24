import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(ChatApp());
}

class ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final TextEditingController _messageController = TextEditingController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;

  File? _imageFile;
  String? _base64Image;

  // Function to check and request location permission at the start
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, request user to enable it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location services are disabled. Please enable them.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check the location permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Handle denial of permission
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // If permission is permanently denied, show message
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
    _checkLocationPermission(); // Request location permission at the start
  }

  // Function to pick an image
  Future<void> pickImage(String message) async {
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
        print("No image selected.");
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  // Function to send message to chat API
  Future<void> sendMessageToChatApi(String message) async {
    try {
      setState(() {
        _isLoading = true;
      });

      setState(() {
        _messages.add({
          "type": "user",
          "text": message,
        });
      });

      final uri = Uri.parse("https://b...content-available-to-author-only...l.app/chat");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: utf8.encode(jsonEncode({"message": message})),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        log('Chat API Response: $responseBody');

        // Add AI's response to the chat
        setState(() {
          _messages.add({
            "type": "ai",
            "text": responseBody["message"] ?? "Response received.",
          });
        });
        if (responseBody['order'] == 'open camera') {
          _openCamera();
        } else if (responseBody['order'] == 'getloaction') {
          getCurrentLocation();
        }

        // Speak the AI response
        _flutterTts.speak(responseBody["message"] ?? "Response received.");
      } else {
        throw Exception("Failed to send message: ${response.statusCode}");
      }
    } catch (e) {
      log('Error sending message to chat API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  File? _image;

  // Function to open the camera
  Future<void> _openCamera() async {
    // Pick image using the camera
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    } else {
      // Handle the case where no image was picked or camera access is denied
      print("No image picked");
    }
  }

  // Function to send image to the API
  Future<void> sendImageToApi(String message) async {
    if (_base64Image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an image first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _messages.add({"type": "user", "image": _imageFile});
        _messages.add({"type": "user", "text": message});
      });

      final uri = Uri.parse("https://b...content-available-to-author-only...l.app/image");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json; charset=utf-8",
        },
        body: utf8.encode(
          jsonEncode({"message": message, "image": _base64Image}),
        ),
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

        print(responseBody['order']);
        // Speak the AI response
        _flutterTts
            .speak(responseBody["message"] ?? "Image processed successfully.");
      } else {
        throw Exception("Failed to process image: ${response.statusCode}");
      }
    } catch (e) {
      log('Error sending image to image API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to start listening for voice input
  Future<void> startListening() async {
    bool available = await _speechToText.initialize();

    if (available) {
      setState(() {
        _isListening = true;
      });
      _speechToText.listen(onResult: (result) {
        setState(() {
          _messageController.text = result.recognizedWords;
        });
      });
    } else {
      print("Speech recognition not available.");
    }
  }

  // Function to stop listening and send the message
  Future<void> stopListening() async {
    setState(() {
      _isListening = false;
    });
    _speechToText.stop();

    // Send the message after stopping the listening
    String message = _messageController.text.trim();
    if (message.isNotEmpty) {
      // Add user's message to the chat
      setState(() {
        _messages.add({"type": "user", "text": message});
      });

      // Send the message to the chat API
      await sendMessageToChatApi(message);
    }
  }

  // Function to get current location
  Future<void> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, request user to enable it
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location services are disabled. Please enable them.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check the location permission status
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Handle denial of permission
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission denied.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // If permission is permanently denied, show message
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Location permission is permanently denied, we cannot access location.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Get the current position of the device
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Log current position
    log('Current position: Lat: ${position.latitude}, Long: ${position.longitude}');

    // Add location information to the chat
    setState(() {
      _messages.add({
        "type": "user",
        "text":
            'Current location: Lat: ${position.latitude}, Long: ${position.longitude}',
      });
    });

    // Optionally, speak the location
    _flutterTts.speak(
        'Current location: Latitude: ${position.latitude}, Longitude: ${position.longitude}');
  }

  // Function to build the chat message UI
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
        title: const Text('Chat with AI, Image, & Voice'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[_messages.length - 1 - index]);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (value) {
                      sendMessageToChatApi(value);
                      _messageController.clear();
                    },
                    decoration: InputDecoration(
                      hintText: "Type or use the mic...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isListening ? stopListening : startListening,
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: _isListening ? Colors.red : Colors.green,
                    child: Icon(
                      _isListening ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => pickImage(_messageController.text),
                  child: const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.image,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: getCurrentLocation,
                  child: const CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.orange,
                    child: Icon(
                      Icons.location_on,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
