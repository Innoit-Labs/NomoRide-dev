import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:nomoride/core/config/api_config.dart';
import 'package:nomoride/core/network/api_exception.dart';
import 'package:nomoride/core/services/auth_session.dart';

class FileUploadRepository {
  FileUploadRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<String> uploadImage({
    required String filePath,
    String fieldName = 'file',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const ApiException('Selected image file was not found.');
    }

    final fileName = filePath.split(Platform.pathSeparator).last;
    final request = http.MultipartRequest('POST', ApiConfig.uploadUri);

    request.headers['Accept'] = 'application/json';
    request.headers.addAll(AuthSession.authHeaders);

    request.files.add(
      await http.MultipartFile.fromPath(
        fieldName,
        filePath,
        filename: fileName,
        contentType: MediaType.parse(_mimeTypeFor(fileName)),
      ),
    );

    _logRequest(fieldName, fileName);

    try {
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      _logResponse(response.statusCode, response.body);

      final json = _tryParseJson(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final url = _extractUrl(json, response.body);
        if (url != null && url.isNotEmpty) return url;
      }

      final message = json?['message'] as String? ??
          'Image upload failed (${response.statusCode})';
      throw ApiException(message, statusCode: response.statusCode);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('No internet connection. Please try again.');
    } catch (_) {
      throw const ApiException('Failed to upload image. Please try again.');
    }
  }

  static String? _extractUrl(Map<String, dynamic>? json, String rawBody) {
    if (json == null) {
      final trimmed = rawBody.trim();
      if (trimmed.startsWith('http')) return trimmed;
      return null;
    }

    final direct = _readString(
      json['url'] ??
          json['fileUrl'] ??
          json['file_url'] ??
          json['imageUrl'] ??
          json['image_url'] ??
          json['location'] ??
          json['path'],
    );
    if (direct != null) return direct;

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final nested = _readString(
        data['url'] ??
            data['fileUrl'] ??
            data['file_url'] ??
            data['imageUrl'] ??
            data['image_url'] ??
            data['location'] ??
            data['path'],
      );
      if (nested != null) return nested;
    }

    if (data is String && data.startsWith('http')) return data;

    final files = json['files'];
    if (files is List && files.isNotEmpty) {
      final first = files.first;
      if (first is Map<String, dynamic>) {
        return _readString(
          first['url'] ??
              first['fileUrl'] ??
              first['file_url'] ??
              first['location'] ??
              first['path'],
        );
      }
      if (first is String && first.startsWith('http')) return first;
    }

    return null;
  }

  static String? _readString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static String _mimeTypeFor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static Map<String, dynamic>? _tryParseJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  void _logRequest(String fieldName, String fileName) {
    debugPrint('========== UPLOAD API REQUEST ==========');
    debugPrint('URL: ${ApiConfig.uploadUri}');
    debugPrint('Field: $fieldName | File: $fileName');
    debugPrint('========================================');
  }

  void _logResponse(int statusCode, String body) {
    debugPrint('========== UPLOAD API RESPONSE ==========');
    debugPrint('Status: $statusCode');
    debugPrint('Body: $body');
    debugPrint('=========================================');
  }
}
