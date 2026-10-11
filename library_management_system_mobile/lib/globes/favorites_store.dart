import 'package:flutter/foundation.dart';
import 'package:library_management_system_mobile/models/book.dart';

class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();

  final Map<String, Book> _favorites = {};

  List<Book> get items => _favorites.values.toList().reversed.toList();

  bool isFavorite(Book book) => _favorites.containsKey(book.title);

  void toggle(Book book) {
    if (_favorites.remove(book.title) == null) {
      _favorites[book.title] = book;
    }
    notifyListeners();
  }
}