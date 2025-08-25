import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'firebase_options.dart';
import 'screens/profile_screen.dart' show ThemeProvider, initNotifications;
import 'screens/auth_screen.dart';
import 'screens/main_navigation.dart';

// Global variables
final FirebaseAuth _auth = FirebaseAuth.instance;
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("Error initializing cameras: $e");
  }

  // Init Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Init notifications
  await initNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ứng dụng Kiểm tra Thị lực',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      home: user != null ? const MainNavigation() : const AuthScreen(),
    );
  }
}
