import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ======================
//  OFFLINE-SAFE UPLOADER
// ======================

class SessionUploader {
  final String apiUrl = "https://d80cf1f8c8b8.ngrok-free.app/api/sessions";  // CHANGE THIS

  Future<Directory> _getPendingFolder() async {
    final dir = await getApplicationDocumentsDirectory();
    final pendingDir = Directory("${dir.path}/pending_uploads");
    if (!pendingDir.existsSync()) {
      pendingDir.createSync(recursive: true);
    }
    return pendingDir;
  }

  /// Save to local pending uploads folder
  Future<File> _savePending(session) async {
    final dir = await _getPendingFolder();
    final file = File("${dir.path}/${session.sessionId}.json");
    print("📂 JSON saved to: ${file.path}");
    await file.writeAsString(jsonEncode(session.toJson()));
    return file;
  }

  /// Try to upload JSON file to API
  Future<bool> _uploadFile(File file) async {
    try {
      final jsonString = await file.readAsString();
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonString,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Uploaded: ${file.path}");
        await file.delete(); // remove after success
        return true;
      } else {
        print("❌ Server rejected upload: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("⚠ Upload failed: $e");
      return false;
    }
  }

  /// Save locally and try immediate upload
  Future<void> saveAndUpload(session) async {
    final file = await _savePending(session);
    bool success = await _uploadFile(file);
    if (!success) {
      print("📌 Saved for later upload: ${file.path}");
    }
  }

  /// Retry all pending uploads
  Future<void> retryPendingUploads() async {
    final dir = await _getPendingFolder();
    final files = dir.listSync().whereType<File>();
    for (final file in files) {
      await _uploadFile(file);
    }
  }
}
