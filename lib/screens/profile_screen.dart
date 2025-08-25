import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'auth_screen.dart';

// ===================== ProfileScreen =====================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Avatar + Info =====
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? 'Chưa có tên hiển thị',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? 'Chưa có email',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            const Text(
              'Cài đặt',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ===== Settings List =====
            _buildSettingsItem(
              icon: Icons.notifications,
              title: 'Thông báo',
              subtitle: 'Nhắc nhở kiểm tra và cảnh báo',
              onTap: () async {
                await _showTestNotification();
              },
            ),
            _buildSettingsItem(
              icon: Icons.dark_mode,
              title: 'Chế độ Tối',
              subtitle: 'Chuyển đổi chế độ tối/sáng',
              onTap: () {
                Provider.of<ThemeProvider>(context, listen: false)
                    .toggleTheme();
              },
            ),
            _buildSettingsItem(
              icon: Icons.language,
              title: 'Ngôn ngữ',
              subtitle: 'Cài đặt ngôn ngữ ứng dụng',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chức năng Ngôn ngữ chưa được triển khai')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.privacy_tip,
              title: 'Riêng tư',
              subtitle: 'Cài đặt riêng tư và dữ liệu',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chức năng Riêng tư chưa được triển khai')),
                );
              },
            ),
            _buildSettingsItem(
              icon: Icons.backup,
              title: 'Sao lưu Dữ liệu',
              subtitle: 'Sao lưu kết quả kiểm tra của bạn',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang sao lưu dữ liệu...')),
                );
              },
            ),

            const SizedBox(height: 24),
            const Text(
              'Giới thiệu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildSettingsItem(
              icon: Icons.info,
              title: 'Thông tin Ứng dụng',
              subtitle: 'Phiên bản 1.0.0',
              onTap: () {},
            ),
            _buildSettingsItem(
              icon: Icons.help,
              title: 'Trợ giúp & Hỗ trợ',
              subtitle: 'Nhận trợ giúp về ứng dụng',
              onTap: () {},
            ),
            _buildSettingsItem(
              icon: Icons.feedback,
              title: 'Gửi Phản hồi',
              subtitle: 'Báo cáo sự cố hoặc đề xuất',
              onTap: () {},
            ),

            const SizedBox(height: 32),
            // ===== Logout Button =====
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _showLogoutDialog(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Đăng xuất'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đăng xuất thành công')),
              );
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

// ===================== ThemeProvider =====================
class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

// ===================== Notifications =====================
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> _showTestNotification() async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'test_channel',
    'Test Notifications',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails =
  NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    0,
    'Thông báo mẫu',
    'Bạn vừa bật thử chức năng thông báo!',
    platformDetails,
  );
}
