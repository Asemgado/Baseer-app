import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:image/image.dart' as img;
import '../services/chat_service.dart';
import '../services/location_service.dart';
import '../models/chat_message.dart';
import '../widgets/message_bubble.dart';

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
  final List<ChatMessage> _messages = [];
  
  bool _isLoading = false;
  bool _isListening = false;
  File? _imageFile;
  String? _base64Image;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await LocationService.checkLocationPermission(context);
    await _flutterTts.setLanguage("ar");
  }

  @override
  void dispose() {
    _messageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _handleImagePicking(ImageSource source, String message) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        var imageBytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = File(pickedFile.path);
          _base64Image = base64Encode(imageBytes);
        });
        await _processAndSendImage(message);
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _processAndSendImage(String message) async {
    if (_base64Image == null) return;

    setState(() {
      _isLoading = true;
      _addMessage(ChatMessage(type: 'user', image: _imageFile));
      _addMessage(ChatMessage(type: 'user', text: message));
    });

    try {

      final base64Image = 'data:image/jpeg;base64,$_base64Image';

      final response = await ChatService.sendImage(message, base64Image);
    
      final aiMessage = ChatMessage(
        type: 'ai',
        text: response["message"] ?? "Image processed successfully.",
      );
    
      _addMessage(aiMessage);
      await _speakMessage(aiMessage.text!);
    } catch (e) {
      _showErrorSnackBar('Error processing image: $e');
    } finally {

      setState(() {
        _isLoading = false;
        _imageFile = null;
        _base64Image = null;
      });
    }
  }

  Future<void> _handleMessageSubmit(String text, {bool isLocation = false}) async {
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      if (!isLocation) {
        _addMessage(ChatMessage(type: 'user', text: text));
      }
    });

    try {
      final response = await ChatService.sendMessage(text);
      
      final aiMessage = ChatMessage(
        type: 'ai',
        text: response["message"],
        order: response["order"],
      );
      
      _addMessage(aiMessage);
      await _speakMessage(aiMessage.text!);

      if (aiMessage.order == 'CAMERA') {
        await _handleImagePicking(ImageSource.camera, 'ماذا يوجد في الصورة ؟');
      } else if (aiMessage.order == 'LOCATION') {
        await _handleLocationRequest();
      }
    } catch (e) {
      _showErrorSnackBar('Error sending message: $e');
    } finally {

      setState(() {
        _isLoading = false;
        _messageController.clear();
      });
    }
  }

  Future<void> _handleLocationRequest() async {
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        final locationMessage = 
          'موقعي الحالي: خط العرض: ${position.latitude} خط الطول اخبرني اين انا : ${position.longitude}';
        await _handleMessageSubmit(locationMessage, isLocation: true);
      }
    } catch (e) {
      _showErrorSnackBar('Error getting location: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    try {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() => _isListening = true);
        await _speechToText.listen(
          localeId: 'ar',
          onResult: (result) {
            setState(() {
              _messageController.text = result.recognizedWords;
            });
          },
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error with speech recognition: $e');
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    await _speechToText.stop();
    if (_messageController.text.isNotEmpty) {
      await _handleMessageSubmit(_messageController.text);
      _messageController.clear();
    }
  }

  Future<void> _speakMessage(String message) async {

    try {
      await _flutterTts.speak(message);
    } catch (e) {
      _showErrorSnackBar('Error speaking message: $e');
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() => _messages.add(message));
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isListening ? Icons.stop : Icons.mic),
            color: _isListening ? Colors.red : Colors.blue,
            onPressed: _toggleListening,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Type your message",
                border: OutlineInputBorder(),
              ),
              onSubmitted: _handleMessageSubmit,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleMessageSubmit(_messageController.text),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat App"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _handleImagePicking(
              ImageSource.camera,
              'ماذا يوجد في الصورة ؟',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () => _handleImagePicking(
              ImageSource.gallery,
              'ماذا يوجد في الصورة ؟',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: _handleLocationRequest,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) => MessageBubble(
                message: _messages[index],
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }
}