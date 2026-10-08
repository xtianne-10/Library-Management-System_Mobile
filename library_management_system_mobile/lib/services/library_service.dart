import 'package:flutter/foundation.dart';

import 'package:library_management_system_mobile/models/book.dart';

class BookTransaction {
  const BookTransaction({
    required this.id,
    required this.title,
    required this.borrower,
    required this.borrowedOn,
    required this.due,
    this.returnedOn,
  });

  final int id;
  final String title;
  final String borrower;
  final DateTime borrowedOn;
  final DateTime due;
  final DateTime? returnedOn;

  bool get returned => returnedOn != null;
  bool get overdue => !returned && due.isBefore(DateTime.now());
  String get status => returned ? 'Returned' : 'Not Returned';
}

/// Shared in-memory catalog. Librarian edits show up for students too.
class LibraryService extends ChangeNotifier {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  final List<Book> _books = [];
  final List<BookTransaction> _transactions = []; // empty, like the web version
  bool _loaded = false;

  List<Book> get books => List.unmodifiable(_books);
  List<BookTransaction> get transactions => List.unmodifiable(_transactions);

  Future<List<Book>> ensureLoaded() async {
    if (!_loaded) {
      _books
        ..clear()
        ..addAll(await BookRepository.loadBooks());
      _loaded = true;
      notifyListeners();
    }
    return books;
  }

  void add(Book b) {
    final nextId =
        _books.fold<int>(0, (m, x) => x.id > m ? x.id : m) + 1;
    _books.add(b.copyWith(id: nextId));
    notifyListeners();
  }

  void update(Book b) {
    final i = _books.indexWhere((x) => x.id == b.id);
    if (i == -1) return;
    _books[i] = b;
    notifyListeners();
  }

  void remove(int id) {
    _books.removeWhere((x) => x.id == id);
    notifyListeners();
  }
}