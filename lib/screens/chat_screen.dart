import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:baseer/screens/profile.dart';
import 'package:baseer/screens/qrcode.dart';
import 'package:baseer/services/battery_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher_string.dart';
import '../services/chat_service.dart';
import '../services/location_service.dart';
import '../models/chat_message.dart';
import '../widgets/message_bubble.dart';
import 'package:just_audio/just_audio.dart';

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
  final BatteryService _batteryService = BatteryService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = false;
  bool _isListening = false;
  File? _imageFile; //بخزن فيه مكان الصورة اللي هتتحمل
  String? _base64Image; //بخزن فيه الصورة

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await LocationService.checkLocationPermission(context);
    await _flutterTts.setLanguage("ar");
    await _flutterTts.speak("مرحبًا بك في بصير");
  }

  @override
  void dispose() {
    _messageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _handleImagePicking(ImageSource source, String message) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
          requestFullMetadata: false,
          maxHeight: 800,
          maxWidth: 800,
          imageQuality: 50,
          source: source);
      if (pickedFile != null) {
        var imageBytes = await pickedFile.readAsBytes();
        setState(() {
          _imageFile = File(pickedFile.path);
          _base64Image = base64Encode(imageBytes).toString();
        });
        await _processAndSendImage(message); //message is ماذا يوجد في الصورة ؟
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
    });

    try {
      final base64Image = _base64Image!;

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

  Future<void> _handleMessageSubmit(String text,
      {bool isLocation = false}) async {
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      if (!isLocation) {
        _addMessage(ChatMessage(type: 'user', text: text));
      }
    });

    try {
      final response = await ChatService.sendMessage(text);
      log('response: $response');
      final aiMessage = ChatMessage(
        type: 'ai',
        text: response["message"],
        order: response["order"],
        phone: response["phone"],
      );

      _addMessage(aiMessage);
      await _speakMessage(aiMessage.text!);

      if (aiMessage.order == 'CAMERA') {
        await _handleImagePicking(ImageSource.camera, 'ماذا يوجد في الصورة ؟');
      } else if (aiMessage.order == 'LOCATION') {
        await _handleLocationRequest();
      } else if (aiMessage.order == 'PHONE') {
        await _launchPhone(aiMessage.phone!);
      } else if (aiMessage.order == 'EMERGENCY') {
        await _sendEmergencyMessage();
      } else if (aiMessage.order == 'TIME') {
        await _speakTime();
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

  Future<void> _launchPhone(String phoneNumber) async {
    try {
      final url = 'tel:+2$phoneNumber';
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      _showErrorSnackBar('Error launching phone: $e');
    }
  }

  Future<void> _sendEmergencyMessage() async {
    try {
      final location = await LocationService.getCurrentLocation();

      if (location != null) {
        final locationMessage =
            ' ${location.latitude} ${location.longitude} انا في خطر الحقني';
        await ChatService.sendEmergency(locationMessage);
      } else {
        throw Exception('لا يمكن الحصول على الموقع');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
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

  Future<void> _speakTime() async {
    final DateTime now = DateTime.now();
    final String currentTime =
        "الوقت الحالي ${now.hour}:${now.minute.toString().padLeft(2, '0')}"; // النص الذي سيُقرأ
    await _flutterTts.speak(currentTime);
  }

  void _addMessage(ChatMessage message) {
    //ماذا يوجد في الصورة ؟
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

  Future<void> _playClickAndSpeak(String text) async {
   
    await _audioPlayer.setAsset('assets/click.mp3');
    await _audioPlayer.play();
    await _flutterTts.speak(text);
  }

  Widget _buildVoiceMicButton() {
    return InkWell(
      onTap: _toggleListening,
      child: SizedBox(
        width: double.infinity,
        child: ColoredBox(
            color: const Color.fromARGB(255, 22, 74, 117),
            child: Icon(
              _isListening ? Icons.stop : Icons.mic,
              color: _isListening ? Colors.red : Colors.white,
              size: 70,
            )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "بصير",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 22, 74, 117),
        shadowColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: const Color.fromARGB(255, 165, 205, 238),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () {
                    _playClickAndSpeak("الملف الشخصي");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/profile.png',
                        width: 60,
                        height: 60,
                      ),
                      const SizedBox(height: 4), // المسافة بين الصورة والنص
                      const Text("الملف الشخصي",
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                    onTap: () {
                      _playClickAndSpeak("الماسح الضوئى");
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => QRScannerScreen()));
                    },
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/qrcode.png',
                          width: 60,
                          height: 60,
                        ),
                        const SizedBox(height: 4),
                        const Text("الماسح الضوئي",
                            style: TextStyle(fontSize: 12)),
                      ],
                    )),
                GestureDetector(
                  onTap: () {
                    _playClickAndSpeak("الموقع");
                    _handleLocationRequest();
                  },
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/location.png',
                        width: 60,
                        height: 60,
                      ),
                      const SizedBox(height: 4),
                      const Text("الموقع", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    String resultt =
                        await _batteryService.getBatteryPercentageInArabic();
                    _playClickAndSpeak(resultt);
                  },
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/charge.png',
                        width: 60,
                        height: 60,
                      ),
                      const SizedBox(height: 4),
                      const Text("البطارية", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color.fromARGB(255, 165, 205, 238),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => {
                    _playClickAndSpeak("المعرض"),
                    _handleImagePicking(
                      ImageSource.gallery,
                      'ماذا يوجد في الصورة ؟',
                    ),
                  },
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/picture.png',
                        width: 60,
                        height: 60,
                      ),
                      const SizedBox(height: 5),
                      const Text("المعرض", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => {
                    _playClickAndSpeak("الكاميرا"),
                    _handleImagePicking(
                      ImageSource.camera,
                      'ماذا يوجد في الصورة ؟',
                    ),
                  },
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/scanner.png',
                        width: 60, // حجم الأيقونة
                        height: 60,
                      ),
                      const SizedBox(height: 5),
                      const Text("الكاميرا", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // باقي محتويات الصفحة
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
          _buildVoiceMicButton(),
        ],
      ),
    );
  }
}
