import 'package:flutter/material.dart';
import 'snellen_test_screen.dart';
import 'history_screen.dart';
import '../widgets/app_header.dart';
import '../services/test_data_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class OverallStats {
  final int totalTest;
  final double averageScore;
  final int lowRiskCount;
  final int mediumRiskCount;
  final int highRiskCount;
  final DateTime? lastTestDate; // ✅ add this

  OverallStats({
    required this.totalTest,
    required this.averageScore,
    required this.lowRiskCount,
    required this.mediumRiskCount,
    required this.highRiskCount,
    required this.lastTestDate,
  });

  factory OverallStats.fromJson(Map<String, dynamic> json) {
    return OverallStats(
      totalTest: (json['totalTest'] as int?) ?? 0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0.0,
      lowRiskCount: (json['lowRiskCount'] as int?) ?? 0,
      mediumRiskCount: (json['mediumRiskCount'] as int?) ?? 0,
      highRiskCount: (json['highRiskCount'] as int?) ?? 0,
      lastTestDate: json['lastTestDate'] != null
          ? DateTime.tryParse(json['lastTestDate'])
          : null,
    );
  }

  void operator [](String other) {}
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TestDataService _testDataService = TestDataService();
  OverallStats? _stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/run_history/overall/overall.json");
      if (await file.exists()) {
    final content = await file.readAsString();
    final data = jsonDecode(content);
    setState(() {
    _stats = OverallStats.fromJson(data);
    });
    } else {
    print("⚠️ overall.json not found in ${dir.path}/run_history/overall");
    }
    } catch (e) {
    print("⚠️ Failed to load overall stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Ứng dụng Kiểm tra Thị lực'),
      body: RefreshIndicator(
        onRefresh: _loadStats, // <-- pull down to refresh
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // important for pull-to-refresh
          child: Column(
            children: [
              _buildWelcomeHeader(),
              _buildQuickStats(),
              _buildQuickActions(context),
              _buildRecentActivity(),
              _buildTestReminder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade400, Colors.blue.shade600],
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.visibility,
            size: 60,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          const Text(
            'Chào mừng!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sẵn sàng cho cuộc kiểm tra thị lực tiếp theo?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalTests = _stats?.totalTest ?? 0;
    final averageScore = _stats?.averageScore ?? 0.0;
    final mediumRiskCount = _stats?.mediumRiskCount ?? 0;
    final highRiskCount = _stats?.highRiskCount ?? 0;

    if (totalTests == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có Dữ liệu Kiểm tra',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thực hiện kiểm tra thị lực đầu tiên để xem thống kê tại đây',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    String riskLevel = 'Thấp';
    if (highRiskCount > 0) {
      riskLevel = 'Cao';
    } else if (mediumRiskCount > 0) {
      riskLevel = 'Vừa';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatCard('Số lần Kiểm tra', totalTests.toString(), Icons.assignment_turned_in, Colors.green),
          _buildStatCard('Điểm TB', '${(averageScore * 100).toInt()}%', Icons.score, Colors.blue),
          _buildStatCard('Mức độ Rủi ro', riskLevel, Icons.security,
            riskLevel == 'Thấp' ? Colors.green : riskLevel == 'Vừa' ? Colors.orange : Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hành động Nhanh',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Kiểm tra Đầy đủ',
                  subtitle: 'Đánh giá toàn diện',
                  icon: Icons.visibility,
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SnellenTestScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionCard(
                  title: 'Kiểm tra Nhanh',
                  subtitle: 'Chỉ Snellen',
                  icon: Icons.text_fields,
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SnellenTestScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentActivity = _testDataService.getRecentActivity(limit: 3);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hoạt động Gần đây',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to history screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HistoryScreen()),
                  );
                },
                child: const Text('Xem Tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...recentActivity.map((session) {
            final score = ((session.visionScore ?? 0.0) * 100).toInt();
            final riskLevel = _testDataService.getRiskLevel(session.visionScore ?? 0.0);
            final color = riskLevel == 'Low' ? Colors.green : riskLevel == 'Medium' ? Colors.orange : Colors.red;

            return _buildActivityItem(
              session.testType,
              _formatTimeAgo(session.startTime),
              'Score: $score%',
              Icons.check_circle,
              color,
            );
          }),
          if (recentActivity.isEmpty)
            const Center(
              child: Text(
                'Không có hoạt động gần đây',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String date,
    String score,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(date),
        trailing: Text(
          score,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTestReminder() {
    final totalTests = _stats?.totalTest ?? 0;
    final lastTestDate = _stats?.lastTestDate;

    String reminderText;
    String actionText;

    if (totalTests == 0) {
      reminderText = 'Chào mừng đến với Ứng dụng Kiểm tra Thị lực! Thực hiện kiểm tra thị lực toàn diện đầu tiên để theo dõi sức khỏe mắt của bạn.';
      actionText = 'Bắt đầu Kiểm tra Đầu tiên';
    } else {
      final daysSinceLastTest = lastTestDate != null
          ? DateTime.now().difference(lastTestDate).inDays
          : 0;

      if (daysSinceLastTest > 180) {
        reminderText = 'Đã hơn 6 tháng kể từ lần kiểm tra thị lực cuối cùng. Nên theo dõi định kỳ.';
        actionText = 'Kiểm tra Ngay';
      } else if (daysSinceLastTest > 90) {
        reminderText = 'Nên cân nhắc thực hiện kiểm tra thị lực sớm. Theo dõi định kỳ giúp theo dõi các thay đổi.';
        actionText = 'Kiểm tra Ngay';
      } else {
        reminderText = 'Sức khỏe thị lực của bạn đang được giám sát tốt. Hãy tiếp tục kiểm tra định kỳ!';
        actionText = 'Kiểm tra Lại';
      }
    }

    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Text(
                    totalTests == 0 ? 'Chào mừng' : 'Nhắc nhở Kiểm tra',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reminderText,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (totalTests > 0)
                    TextButton(
                      onPressed: () {},
                      child: const Text('Nhắc sau'),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SnellenTestScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(actionText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}