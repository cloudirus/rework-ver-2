import 'package:flutter/material.dart';
import '../models/test_result.dart';
import '../widgets/app_header.dart';
import '../services/test_data_service.dart';
// import '../models/json_upload.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  List<VisionTestSession> _testSessions = [];
  final TestDataService _testDataService = TestDataService();

  // Future<void> _save(path) async {
  //   final SessionUploader jsonUploadService = SessionUploader();
  //   jsonUploadService.uploadFile(path);
  // }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTestHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTestHistory();
    }
  }

  void _loadTestHistory() {
    setState(() {
      _testSessions = _testDataService.getTestHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Lịch sử Kiểm tra',
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(),
          Expanded(
            child: _testSessions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _testSessions.length,
                    itemBuilder: (context, index) {
                      final session = _testSessions[index];
                      return _buildTestSessionCard(session);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final stats = _testDataService.getTestStatistics();
    final totalTests = stats['totalTests'] as int;
    final averageScore = stats['averageScore'] as double;
    final lowRiskCount = stats['lowRiskCount'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade500, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem('Tổng số Kiểm tra', totalTests.toString()),
          _buildStatItem('Điểm TB', totalTests > 0 ? '${(averageScore * 100).toInt()}%' : '0%'),
          _buildStatItem('Rủi ro Thấp', '$lowRiskCount/$totalTests'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Không có lịch sử kiểm tra',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Hoàn thành kiểm tra thị lực đầu tiên để xem kết quả tại đây',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSessionCard(VisionTestSession session) {
    final riskLevel = _testDataService.getRiskLevel(session.visionScore ?? 0.0);
    Color riskColor = riskLevel == 'Low'
        ? Colors.green
        : riskLevel == 'Medium'
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _viewTestDetails(session),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      session.testType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: riskColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      riskLevel,
                      style: TextStyle(
                        color: riskColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(session.startTime),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.score, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        'Điểm: ${((session.visionScore ?? 0.0) * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        '${session.endTime != null ? session.endTime!.difference(session.startTime).inMinutes : 0}ph',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewTestDetails(VisionTestSession session) {
    final riskLevel = _testDataService.getRiskLevel(session.visionScore ?? 0.0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(session.testType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ngày: ${_formatDate(session.startTime)}'),
            const SizedBox(height: 8),
            Text('Điểm: ${((session.visionScore ?? 0.0) * 100).toInt()}%'),
            const SizedBox(height: 8),
            Text('Mức độ Rủi ro: $riskLevel'),
            const SizedBox(height: 8),
            Text('Thời gian: ${session.endTime != null ? session.endTime!.difference(session.startTime).inMinutes : 0}ph'),
            const SizedBox(height: 8),
            Text('Kiểm tra Hoàn thành: ${session.testResults.length}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          TextButton(
            onPressed: () {
              // _save();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chi tiết kiểm tra đã xuất')),
              );
            },
            child: const Text('Xuất'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lọc Kiểm tra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Kiểm tra Thị lực Toàn diện'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Kiểm tra Snellen'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Kiểm tra Lưới Amsler'),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

