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
  String _message = '';

  // Login using custom token
  Future<void> _signInWithCustomToken() async {
    setState(() {
      _message = 'Đang xác thực...';
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
        });
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => SplashScreen()));
      } else {
        setState(() {
          _message = 'Không thể đăng nhập.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Lỗi: $e';
      });
      print('Lỗi: $e');
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
      appBar: AppBar(
        title: const Text('Đăng nhập'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mật khẩu'),
            ),
            const SizedBox(height: 20),

            // Row with two buttons side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _createAccount,
                  child: const Text('Tạo tài khoản'),
                ),
                ElevatedButton(
                  onPressed: _signInWithCustomToken,
                  child: const Text('Đăng nhập'),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Text(_message, style: const TextStyle(color: Colors.red)),

            // StreamBuilder<User?>(
            //   stream: _auth.authStateChanges(),
            //   builder: (context, snapshot) {
            //     if (snapshot.hasData && snapshot.data != null) {
            //       return Text(
            //           'Currently signed in: ${snapshot.data!.email ?? snapshot.data!.uid}');
            //     }
            //     return const Text('Not signed in.');
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
