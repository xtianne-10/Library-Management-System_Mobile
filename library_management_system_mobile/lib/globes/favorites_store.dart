import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:library_management_system_mobile/config/api_config.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';

class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();

  static String get _base => '${ApiConfig.baseUrl}/books';

  final List<Book> _items = [];
  bool _loaded = false;
  bool _loading = false;

  List<Book> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AuthService.instance.token}',
      };

  bool isFavorite(Book book) =>
      _items.any((b) => b.remoteId == book.remoteId);

  Book? _toBook(Map<String, dynamic> json) {
    final id = '${json['id'] ?? json['_id']}';
    for (final b in LibraryService.instance.books) {
      if (b.remoteId == id) return b;
    }
    return null;
  }

  Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    await load();
  }

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      if (LibraryService.instance.books.isEmpty) {
        await LibraryService.instance.reload();
      }

      final res = await http.get(Uri.parse('$_base/favorites'),
          headers: _headers);
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final list = data is List ? data : const [];
      final mapped = <Book>[];
      for (final j in list) {
        if (j is! Map<String, dynamic>) continue;
        final b = _toBook(j);
        if (b != null) mapped.add(b);
      }

      _items
        ..clear()
        ..addAll(mapped);
      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[favorites] error: $e');
    } finally {
      _loading = false;
    }
  }

  Future<String?> toggle(Book book) async {
    final wasFav = isFavorite(book);
    final index = _items.indexWhere((b) => b.remoteId == book.remoteId);

    if (wasFav) {
      _items.removeAt(index);
    } else {
      _items.add(book);
    }
    notifyListeners();

    try {
      final uri = Uri.parse('$_base/favorites/${book.remoteId}');
      final res = wasFav
          ? await http.delete(uri, headers: _headers)
          : await http.put(uri, headers: _headers);
      debugPrint('[favorites] toggle ${res.statusCode} ${res.body}');
      if (res.statusCode >= 200 && res.statusCode < 300) return null;
      _revert(book, wasFav, index);
      return 'Favorites failed (${res.statusCode}): ${res.body}';

      String msg = 'Could not update favorites.';
      try {
        msg = jsonDecode(res.body)['error'] ?? msg;
      } catch (_) {}
      _revert(book, wasFav, index);
      return msg;
    } catch (_) {
      _revert(book, wasFav, index);
      return 'Cannot reach the server.';
    }
  }

  void _revert(Book book, bool wasFav, int index) {
    if (wasFav) {
      _items.insert(index.clamp(0, _items.length), book);
    } else {
      _items.removeWhere((b) => b.remoteId == book.remoteId);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _loaded = false;
    notifyListeners();
  }
}