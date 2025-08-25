import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giới thiệu'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.visibility,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ứng dụng Kiểm tra Thị lực',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Phiên bản 1.0.0',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Giới thiệu Ứng dụng',
              content: 'Ứng dụng Kiểm tra Thị lực là công cụ kiểm tra mắt toàn diện sử dụng phân tích AI để đánh giá thị lực của bạn. Ứng dụng bao gồm kiểm tra biểu đồ Snellen để đo thị lực và kiểm tra lưới Amsler để tầm soát thoái hóa hoàng điểm.',
            ),
            _buildSection(
              title: 'Tính năng',
              content: '• Kiểm tra Snellen\n'
                  '• Kiểm tra Lưới Amsler cho sức khỏe hoàng điểm\n'
                  '• Phân tích và khuyến nghị bằng AI\n'
                  '• Lịch sử kiểm tra và theo dõi tiến trình\n'
                  '• Kết quả chi tiết với đánh giá rủi ro\n'
                  '• Xuất và chia sẻ kết quả kiểm tra',
            ),
            _buildSection(
              title: 'Cách hoạt động',
              content: 'Ứng dụng sử dụng camera của thiết bị để giám sát chuyển động và phản ứng của mắt trong quá trình kiểm tra thị lực. Thuật toán học máy phân tích hiệu suất của bạn để đưa ra đánh giá chính xác và khuyến nghị cá nhân hóa.',
            ),
            _buildSection(
              title: 'Khuyến cáo',
              content: 'Ứng dụng này chỉ dùng cho mục đích giáo dục và sàng lọc. Nó không phải là sự thay thế cho lời khuyên, chẩn đoán hoặc điều trị y khoa chuyên nghiệp. Luôn tư vấn với nhà cung cấp dịch vụ y tế có trình độ cho các vấn đề y khoa.',
              isWarning: true,
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Liên hệ & Hỗ trợ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildContactItem(
                      icon: Icons.email,
                      title: 'Hỗ trợ Email',
                      subtitle: 'grillcheesesandwichez@gmail.com',
                    ),
                    _buildContactItem(
                      icon: Icons.web,
                      title: 'Trang web',
                      subtitle: 'not available',
                    ),
                    _buildContactItem(
                      icon: Icons.privacy_tip,
                      title: 'Chính sách Bảo mật',
                      subtitle: 'Xem chính sách bảo mật của chúng tôi',
                    ),
                    _buildContactItem(
                      icon: Icons.gavel,
                      title: 'Điều khoản Dịch vụ',
                      subtitle: 'Xem điều khoản và điều kiện',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const Text(
                    'Làm bằng ❤️ cho sức khỏe thị lực tốt hơn',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2024 Ứng dụng Kiểm tra Thị lực. Tất cả quyền được bảo lưu.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    bool isWarning = false,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isWarning) ...[
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isWarning ? Colors.orange : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}