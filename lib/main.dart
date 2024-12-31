import 'package:baseer/screens/chat_screen.dart';
import 'package:baseer/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ChatApp());
}

class ChatApp extends StatefulWidget {
  const ChatApp({Key? key}) : super(key: key);

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  bool? isLogin;

  Future<void> checkLoginStatus() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (mounted) {
        setState(() {
          isLogin = userId != null;
        });
      }
    } catch (e) {
      print('Error checking login status: $e');
      if (mounted) {
        setState(() {
          isLogin = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      home: isLogin == null
          ? const Center(child: CircularProgressIndicator())
          : isLogin == true
              ? const ChatScreen()
              : const Login(),
    );
  }
}
