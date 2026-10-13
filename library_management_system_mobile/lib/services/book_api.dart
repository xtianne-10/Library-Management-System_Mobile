import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

/// Talks to the same /books routes the web dashboard uses.
class BookApi {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AuthService.instance.token}',
      };

  static Uri _uri([String path = '']) =>
      Uri.parse('${ApiConfig.baseUrl}/books$path');

  static dynamic _decode(http.Response res) {
    dynamic data;
    try {
      data = jsonDecode(res.body);
    } catch (_) {}
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
          (data is Map ? data['error'] : null) ?? 'Request failed (${res.statusCode})');
    }
    return data;
  }

  static Future<List<Map<String, dynamic>>> list() async {
    final data = _decode(await http.get(_uri(), headers: _headers));
    return data is List ? data.cast<Map<String, dynamic>>() : [];
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      _decode(await http.post(_uri(), headers: _headers, body: jsonEncode(body)));

  static Future<Map<String, dynamic>> update(
          String id, Map<String, dynamic> body) async =>
      _decode(await http.put(_uri('/$id'), headers: _headers, body: jsonEncode(body)));

  static Future<void> remove(String id) async =>
      _decode(await http.delete(_uri('/$id'), headers: _headers));
}