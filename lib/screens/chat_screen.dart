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
  late AudioPlayer _audioPlayer;

  bool _isLoading = false;
  bool _isListening = false;
  File? _imageFile;
  String? _base64Image;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
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
        await _processAndSendImage(message);
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
      [];
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
      );

      _addMessage(aiMessage);
      await _speakMessage(aiMessage.text!);

      if (aiMessage.order == 'CAMERA') {
        await _handleImagePicking(ImageSource.camera, 'ماذا يوجد في الصورة ؟');
      } else if (aiMessage.order == 'LOCATION') {
        await _handleLocationRequest();
      } else if (aiMessage.order == 'PHONE') {
        await _launchPhone(aiMessage.text!);
      } else if (aiMessage.order == 'EMERGENCY') {
        await _sendEmergencyMessage();
      }
      // else if (aiMessage.order == 'WHATSAPP') {
      //
      //   await launchWhatsApp(aiMessage.text!, message:'برجاء الاتصال بي');
      // }
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
      // Validate phone number format

      final url = 'tel:+2$phoneNumber';

      // Check if can launch before attempting
      if (await canLaunchUrlString(url)) {
        final bool launched = await launchUrlString(
          url,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          _showErrorSnackBar('لا يمكن الاتصال بالرقم: $phoneNumber');
        }
      } else {
        print("$phoneNumber");
        _showErrorSnackBar('لا يمكن إجراء المكالمة');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في الاتصال: $e');
    }
  }

  Future<void> _sendEmergencyMessage() async {
    try {
      // Validate phone number format

      final location = await LocationService.getCurrentLocation();

      if (location != null) {
        final locationMessage =
            'موقعي الحالي: خط العرض: ${location.latitude} خط الطول: ${location.longitude}';
        await ChatService.sendEmergency(locationMessage);
      } else {
        throw Exception('لا يمكن الحصول على الموقع');
      }
    } catch (e) {
      _showErrorSnackBar(e.toString());
    }
  }

  // Future<void> launchWhatsApp(String phoneNumber, {String message = ''}) async {
  //   try {
  //     // Remove any non-numeric characters from phone number
  //     //final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

  //     // URL encode the message
  //     final encodedMessage = Uri.encodeComponent(message);

  //     // WhatsApp URL scheme with country code (Egypt +20) and message
  //     final url = 'whatsapp://send?phone=20$phoneNumber&text=$encodedMessage';

  //     // Alternative URL for web WhatsApp
  //     final webUrl = 'https://wa.me/20$phoneNumber?text=$encodedMessage';

  //     if (await canLaunchUrlString(url)) {
  //       final bool launched = await launchUrlString(
  //         url,
  //         mode: LaunchMode.externalApplication,
  //       );

  //       if (!launched) {
  //         // Try web URL as fallback
  //         if (await canLaunchUrlString(webUrl)) {
  //           await launchUrlString(webUrl);
  //         } else {
  //           _showErrorSnackBar('لا يمكن فتح واتساب');
  //         }
  //       }
  //     } else {
  //       // Try web URL if app URL fails
  //       if (await canLaunchUrlString(webUrl)) {
  //         await launchUrlString(webUrl);
  //       } else {
  //         _showErrorSnackBar('الرجاء التأكد من تثبيت واتساب');
  //       }
  //     }
  //   } catch (e) {
  //     _showErrorSnackBar('خطأ في فتح واتساب: $e');
  //   }
  // }

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

  Future<void> _playClickAndSpeak(String text) async {
    // تشغيل صوت النقر
    await _audioPlayer.setAsset('assets/click.mp3');
    await _audioPlayer.play();

    // قراءة النص
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
            color: Colors.white, // لون النص
            fontSize: 28, // حجم الخط
            fontWeight: FontWeight.bold, // وزن الخط
            shadows: [
              Shadow(
                offset: Offset(2, 2), // اتجاه الظل
                color: Colors.black26, // لون الظل
                blurRadius: 4, // شدة التمويه للظل
              ),
            ],
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 22, 74, 117),
        shadowColor: Colors.transparent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // الشريط المخصص للأيقونات
          Container(
            color:
                const Color.fromARGB(255, 165, 205, 238), // لون الخلفية للشريط
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
                      const SizedBox(height: 4),
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
