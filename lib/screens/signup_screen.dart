import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screen.dart';


class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _displaynameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _message = '';

  Future<void> _createAccount() async {
    setState(() {
      _message = 'Đang tạo tài khoản...';
    });

    try {
      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: _usernameController.text,
        password: _passwordController.text,
      );

      final User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(_displaynameController.text); // Optional default name
        setState(() {
          // _message = 'Đã tạo tài khoản: ${user.email}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã tạo tài khoản: ${user.email}')),
          );
        });
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => AuthScreen()));
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = 'Lỗi Firebase: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _message = 'Lỗi: $e';
      });
    }
  }
  Future<void> updateUserProfile(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
      // await user.updatePhotoURL(photoUrl);
      await user.reload(); // refresh local user data
    }
  }

  // Future<void> _createAccountandupdateUserProfile() async {
  //   _createAccount();
  //   updateUserProfile(_displaynameController.text);
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo tài khoản'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context); // Go back manually
          },
        ),
      ),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
              TextField(
              controller: _displaynameController,
              decoration: const InputDecoration(labelText: 'Tên tài khoản'),
            ),
            TextField(
              controller: _usernameController,
              // obscureText: true,
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
                // ElevatedButton(
                //   onPressed: _signInWithCustomToken,
                //   child: const Text('Login'),
                // ),
              ],
            ),

            const SizedBox(height: 20),
            Text(_message, style: const TextStyle(color: Colors.red)),
              ],
            ),
        ),
    );
  }
}