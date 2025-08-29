import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'splash_screen.dart';
import 'signup_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  // Login using custom token
  Future<void> _signInWithCustomToken() async {
    setState(() {
      // _message = 'Đang xác thực...';
    });

    try {
      final response = await http.post(
        Uri.parse('https://4b05a0660d9d.ngrok-free.app/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Không nhận được token: ${response.body}');
      }

      final customToken = jsonDecode(response.body)['customToken'] as String;

      if (customToken.isEmpty) {
        throw Exception('Không có token');
      }

      final UserCredential userCredential =
      await _auth.signInWithCustomToken(customToken);
      final User? user = userCredential.user;

      if (user != null) {
        setState(() {
          // _message = 'Đã đăng nhập: ${user.email ?? user.uid}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã đăng nhập: ${user.email ?? user.uid}')),
          );
          Navigator.of(context)
              .pushReplacement(MaterialPageRoute(builder: (_) => SplashScreen()));
        });
      } else {
        setState(() {
          // _message = 'Không thể đăng nhập.';
        });
      }
    } catch (e) {
      // setState(() {
      //   // _message = 'Lỗi: $e';
      // });
      print('Lỗi: $e');
      rethrow;
    }
  }

  Future<void> _handleLogin() async {
    try {
      await _signInWithCustomToken();
      // Navigate to home if successful
      // if (mounted) {
      //   Navigator.of(context)
      //       .pushReplacement(MaterialPageRoute(builder: (_) => SplashScreen()));
      //   }
    } catch (e) {
      String errorMessage = "Có lỗi xảy ra, vui lòng thử lại.";

      // Nếu muốn phân loại lỗi
      if (e.toString().contains("credential")) {
        errorMessage = "Sai email hoặc mật khẩu.";
      } else if (e.toString().contains("token")) {
        errorMessage = "Hệ thống gặp sự cố, vui lòng thử lại sau.";
      } else if (e.toString().contains("host")) {
        errorMessage = "Không thể kết nối mạng. Kiểm tra kết nối Internet.";
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Lỗi đăng nhập"),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  // Create new Firebase account
  Future<void> _createAccount() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Blue header (like home_screen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 80, bottom: 40),
              decoration: BoxDecoration( // Removed 'const' because Gradient is not a const constructor
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2196F3), // Starting color of the gradient
                    Color(0xFF1976D2), // Ending color of the gradient (example, a darker blue)
                  ],
                  begin: Alignment.topCenter, // Gradient starts at the top
                  end: Alignment.bottomCenter, // Gradient ends at the bottom
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.remove_red_eye,
                    color: Colors.white,
                    size: 72,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chào mừng trở lại!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Đăng nhập để tiếp tục',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Auth form card
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng nhập mật khẩu';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Login/Signup button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              FocusScope.of(context).unfocus();
                              _handleLogin();
                            }
                          },
                          child: Text(
                            'Đăng nhập',
                            style: const TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () {
                               _createAccount();
                          },
                          child: Text(
                                'Chưa có tài khoản? Đăng ký',
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}