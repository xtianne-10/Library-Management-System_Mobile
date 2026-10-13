import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class BorrowApi {
  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AuthService.instance.token}',
      };

  static Uri _uri([String path = '']) =>
      Uri.parse('${ApiConfig.baseUrl}/borrowings$path');

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

  static Future<void> issue(String bookId, String email) async => _decode(
      await http.post(_uri(),
          headers: _headers,
          body: jsonEncode({'bookId': bookId, 'email': email})));

  static Future<void> returnBook(String id) async =>
      _decode(await http.put(_uri('/$id/return'), headers: _headers));

  static Future<void> payFine(String id) async =>
      _decode(await http.put(_uri('/$id/pay'), headers: _headers));

  // Borrow requests: librarians approve or decline, borrowers can cancel their own
  static Future<void> approve(String id) async =>
      _decode(await http.put(_uri('/$id/approve'), headers: _headers));

  static Future<void> decline(String id) async =>
      _decode(await http.put(_uri('/$id/decline'), headers: _headers));

  static Future<void> cancel(String id) async =>
      _decode(await http.put(_uri('/$id/cancel'), headers: _headers));
}