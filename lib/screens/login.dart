import 'package:baseer/screens/chat_screen.dart';
import 'package:baseer/screens/register.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _illnessController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();

  bool _isLoading = false;

  Future<void> _cacheUserData(Map<String, dynamic> userData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userData['id'].toString());
    // await prefs.setString('username', userData['username'] ?? '');
    // You can cache more user data as needed
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        Map<String, String> requestBody = {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        };
        final response = await http.post(
          Uri.parse("https://basser-api.vercel.app/login"),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final responseData = jsonDecode(response.body);

          // Cache the user data
          //   await _cacheUserData(responseData);

          print(responseData);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تسجيل الدخول بنجاح'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
            // Navigate to home or profile page
            _cacheUserData(responseData);
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => ChatScreen()),(route) => false,
            );
          }
        } else {
          Map<String, dynamic> errorResponse;
          try {
            errorResponse = jsonDecode(response.body);
          } catch (e) {
            errorResponse = {'message': 'حدث خطأ غير متوقع'};
          }

          throw Exception(errorResponse['detail'] ??
              errorResponse['message'] ??
              'فشل في تسجيل الدخول');
        }
      } catch (e) {
        if (mounted) {
          print(e.toString());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Helper method to check if user is already logged in
  Future<bool> isLoggedIn() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user_id');
  }

  // Helper method to get cached user ID
  Future<String?> getUserId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id');
  }

  // Helper method to clear cached data (for logout)
  Future<void> clearUserData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  void initState() {
    super.initState();
    // Check if user is already logged in
    isLoggedIn().then((loggedIn) {
      if (loggedIn) {
        // Navigate to home page if already logged in
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(builder: (context) => HomePage()),
        // );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 200,
                ),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المستخدم',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال اسم المستخدم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال كلمة المرور';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'دخول',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Register()));
                        },
                        child: Text('ليس لدي حساب')),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _illnessController.dispose();
    _genderController.dispose();
    _ageController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }
}
