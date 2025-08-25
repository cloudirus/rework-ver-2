import 'package:flutter/material.dart';
import '../screens/history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/about_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(
            icon: Icons.home,
            title: 'Trang chủ',
            onTap: () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            icon: Icons.visibility,
            title: 'Bắt đầu Kiểm tra Thị lực',
            onTap: () {
              Navigator.pop(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.history,
            title: 'Lịch sử Kiểm tra',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.person,
            title: 'Hồ sơ',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Cài đặt',
            onTap: () {
              Navigator.pop(context);
              _showSettingsDialog(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.help,
            title: 'Trợ giúp & Hỗ trợ',
            onTap: () {
              Navigator.pop(context);
              _showHelpDialog(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.info,
            title: 'Giới thiệu',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.share,
            title: 'Chia sẻ Ứng dụng',
            onTap: () {
              Navigator.pop(context);
              _showShareDialog(context);
            },
          ),
          _buildDrawerItem(
            icon: Icons.star_rate,
            title: 'Đánh giá Ứng dụng',
            onTap: () {
              Navigator.pop(context);
              _showRatingDialog(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return DrawerHeader(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.visibility,
            size: 40,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            'Ứng dụng Kiểm tra Thị lực',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chăm sóc Mắt Toàn diện',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              const Icon(
                Icons.person,
                size: 16,
                color: Colors.white70,
              ),
              const SizedBox(width: 4),
              const Text(
                'John Doe',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cài đặt'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Chế độ Tối'),
              value: false,
              onChanged: null,
            ),
            SwitchListTile(
              title: Text('Thông báo'),
              value: true,
              onChanged: null,
            ),
            SwitchListTile(
              title: Text('Hiệu ứng Âm thanh'),
              value: true,
              onChanged: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trợ giúp & Hỗ trợ'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cách thực hiện kiểm tra thị lực:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('1. Đảm bảo ánh sáng tốt'),
            Text('2. Đứng ở khoảng cách đúng'),
            Text('3. Che một mắt mỗi lần'),
            Text('4. Làm theo hướng dẫn trên màn hình'),
            SizedBox(height: 16),
            Text(
              'Để nhận hỗ trợ kỹ thuật, liên hệ:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Email: grillcheesesandwichez@gmail.com'),
            Text('Phone: 727'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chia sẻ Ứng dụng'),
        content: const Text(
          'Chia sẻ Ứng dụng Kiểm tra Thị lực với bạn bè và gia đình để giúp họ giám sát sức khỏe mắt!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chia sẻ ứng dụng thành công!')),
              );
            },
            child: const Text('Chia sẻ'),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đánh giá Ứng dụng của chúng tôi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bạn đánh giá trải nghiệm của mình như thế nào?'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: const Icon(Icons.star, color: Colors.amber),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cảm ơn bạn đã đánh giá ${index + 1} sao!'),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Sau này'),
          ),
        ],
      ),
    );
  }
}