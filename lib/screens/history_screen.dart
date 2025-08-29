import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AnalysisResultLog {
  final DateTime timestamp;
  final int durations;
  final double visionScore;
  final String riskLevel;
  final String diagnosis;
  final List<String> recommendations;

  AnalysisResultLog({
    required this.timestamp,
    required this.durations,
    required this.visionScore,
    required this.riskLevel,
    required this.diagnosis,
    required this.recommendations,
  });

  factory AnalysisResultLog.fromJson(Map<String, dynamic> json) {
    return AnalysisResultLog(
      timestamp: DateTime.parse(json['timestamp']),
      durations: (json['durations'] as num?)?.toInt() ?? 0,
      visionScore: (json['visionScore'] as num?)?.toDouble() ?? 0.0,
      riskLevel: json['riskLevel'] ?? "Unknown",
      diagnosis: json['diagnosis'] ?? "No diagnosis",
      recommendations: json['recommendations'] is List
          ? List<String>.from(json['recommendations'])
          : [],
    );
  }
}

class AnalysisResultStorage {
  static Future<Directory> _getHistoryDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final historyDir = Directory("${dir.path}/run_history");
    if (!await historyDir.exists()) {
      await historyDir.create(recursive: true);
    }
    return historyDir;
  }

  static Future<List<AnalysisResultLog>> loadAllRuns() async {
    final dir = await _getHistoryDir();
    final files = dir.listSync().whereType<File>().toList();

    List<AnalysisResultLog> results = [];
    for (var file in files) {
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content);
        results.add(AnalysisResultLog.fromJson(data));
        print("File $file loaded!");
      } catch (e, stack) {
        print("ERROR: File $file cannot load → $e");
        print(stack);
      }
    }

    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  static Future<void> clearAllRuns() async {
    final dir = await _getHistoryDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      await dir.create(); // recreate empty folder
    }
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AnalysisResultLog> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final runs = await AnalysisResultStorage.loadAllRuns();
    setState(() {
      _history = runs;
    });
  }

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _clearHistory() async {
    await AnalysisResultStorage.clearAllRuns();
    setState(() {
      _history.clear();
    });
  }

  void _confirmClearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận"),
        content: const Text(
            "Bạn có muốn xóa lịch sử? Lịch sử đã xóa không thể khôi phục!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Hủy"),
          ),
          TextButton(
            onPressed: () async {
              await _clearHistory();
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Đã xóa thành công")),
              );
            },
            child: const Text(
              "Xóa",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _history.length;
    final avgScore = total > 0
        ? _history.map((e) => e.visionScore).reduce((a, b) => a + b) / total
        : 0.0;
    final lowRisk = _history.where((e) => e.riskLevel == "Low").length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 10,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(1),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: const [
            Icon(Icons.remove_red_eye, color: Colors.white),
            SizedBox(width: 8),
            Text("Lịch sử Kiểm tra", style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt, color: Colors.white),
            onPressed: () {
              // filter/sort feature can be added later
            },
          )
        ],
      ),
      body: Column(
        children: [
          // === Blue Stats Bar ===
          Container(
            color: Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat("Tổng số Kiểm tra", "$total"),
                _buildStat("Điểm TB", "${(avgScore * 100).toStringAsFixed(0)}%"),
                _buildStat("Rủi ro Thấp", "$lowRisk/$total"),
              ],
            ),
          ),

          // === History List ===
          Expanded(
            child: _history.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text("Không có lịch sử kiểm tra",
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                      "Hoàn thành kiểm tra thị lực đầu tiên để xem kết quả tại đây",
                      textAlign: TextAlign.center,
                      style:
                      TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final run = _history[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading:
                    const Icon(Icons.visibility, color: Colors.blue),
                    title: Text("Run: ${_formatDate(run.timestamp)}"),
                    subtitle: Text(
                      "Điểm: ${(run.visionScore * 100).toStringAsFixed(1)}% | Rủi ro: ${run.riskLevel}",
                    ),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Chi tiết"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Ngày: ${_formatDate(run.timestamp)}"),
                              Text(
                                  "Điểm: ${(run.visionScore * 100).toStringAsFixed(1)}%"),
                              Text("Rủi ro: ${run.riskLevel}"),
                              Text("Chẩn đoán: ${run.diagnosis}"),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Đóng"),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // === Footer Clear Button ===
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ElevatedButton(
                  onPressed: _confirmClearHistory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    elevation: 3,
                  ),
                  child: const Text(
                    "Xóa lịch sử",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}