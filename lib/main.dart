import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';

import 'firebase_options.dart';
import 'screens/profile_screen.dart' show ThemeProvider, initNotifications;
import 'screens/main_navigation.dart';

// Global variables
List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init cameras
  try {
    cameras = await availableCameras();
  } catch (e) {
    // print("Error initializing cameras: $e");
  }

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

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ứng dụng Kiểm tra Thị lực',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeProvider.themeMode,
      home: const MainNavigation(),
    );
  }
}
