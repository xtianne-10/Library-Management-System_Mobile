import 'package:flutter/foundation.dart';

import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/book_api.dart';
import 'package:library_management_system_mobile/services/borrow_api.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class BookTransaction {
  const BookTransaction({
    required this.id,
    this.remoteId = '',
    required this.bookId,
    required this.book,
    required this.title,
    required this.borrower,
    required this.borrowerEmail,
    required this.borrowedOn,
    required this.due,
    this.returnedOn,
    this.finePaid = false,
  });

  final int id;
  final String remoteId; // server id
  final int bookId;
  final Book book;
  final String title;
  final String borrower;
  final String borrowerEmail;
  final DateTime borrowedOn;
  final DateTime due;
  final DateTime? returnedOn;
  final bool finePaid;

  bool get returned => returnedOn != null;

  // Days late. For returned books it is measured at the return date.
  int get daysOverdue {
    final end = _dateOnly(returnedOn ?? DateTime.now());
    final d = end.difference(_dateOnly(due)).inDays;
    return d > 0 ? d : 0;
  }

  bool get overdue => !returned && daysOverdue > 0;
  double get fine => daysOverdue * LibraryService.finePerDay;
  double get fineOwed => finePaid ? 0 : fine;
  String get status => returned ? 'Returned' : 'Not Returned';

  BookTransaction _copy({
    Book? book,
    String? title,
    DateTime? returnedOn,
    bool? finePaid,
  }) =>
      BookTransaction(
        id: id,
        remoteId: remoteId,
        bookId: bookId,
        book: book ?? this.book,
        title: title ?? this.title,
        borrower: borrower,
        borrowerEmail: borrowerEmail,
        borrowedOn: borrowedOn,
        due: due,
        returnedOn: returnedOn ?? this.returnedOn,
        finePaid: finePaid ?? this.finePaid,
      );

  BookTransaction markReturned(DateTime when) => _copy(returnedOn: when);
  BookTransaction withBook(Book b) => _copy(book: b, title: b.title);
  BookTransaction markFinePaid() => _copy(finePaid: true);
}

/// Shared in-memory catalog + transactions (single source of truth).
class LibraryService extends ChangeNotifier {
  LibraryService._();
  static final LibraryService instance = LibraryService._();

  static const loanDays = 14;
  static const finePerDay = 5.0;
  static const maxActiveLoans = 3;

  final List<Book> _books = [];
  final List<BookTransaction> _transactions = []; // newest first
  int _nextTxId = 1;
  bool _loaded = false;

  List<Book> get books => List.unmodifiable(_books);
  List<BookTransaction> get transactions => List.unmodifiable(_transactions);

  final Map<String, int> _idMap = {}; // server id -> stable local int id
  int _nextLocalId = 1;
  String? loadError;

  int _idFor(String remoteId) =>
      _idMap.putIfAbsent(remoteId, () => _nextLocalId++);

  Book _fromServer(Map<String, dynamic> j) =>
      Book.fromServer(j, localId: _idFor((j['id'] ?? '').toString()));

  Future<List<Book>> ensureLoaded() async {
    if (!_loaded) await reload();
    return books;
  }

  final Map<String, int> _txIdMap = {};
  int _txIdFor(String remoteId) =>
      _txIdMap.putIfAbsent(remoteId, () => _nextTxId++);

  /// Re-reads the catalog and transactions so web changes show up here.
  Future<void> reload() async {
    try {
      final list = await BookApi.list();
      _books
        ..clear()
        ..addAll(list.map(_fromServer));
      _loaded = true;
      loadError = null;
    } catch (e) {
      loadError = e.toString().replaceFirst('Exception: ', '');
    }
    await _loadTransactions();
    notifyListeners();
  }

  Future<void> _loadTransactions() async {
    try {
      final rows = await BorrowApi.list();
      final byRemote = {for (final b in _books) b.remoteId: b};
      final out = <BookTransaction>[];
      for (final r in rows) {
        final book = byRemote[(r['bookId'] ?? '').toString()];
        if (book == null) continue;
        final rid = (r['id'] ?? '').toString();
        out.add(BookTransaction(
          id: _txIdFor(rid),
          remoteId: rid,
          bookId: book.id,
          book: book,
          title: book.title,
          borrower: (r['borrower'] ?? '') as String,
          borrowerEmail: ((r['borrowerEmail'] ?? '') as String).toLowerCase(),
          borrowedOn: DateTime.parse(r['borrowedOn'] as String),
          due: DateTime.parse(r['due'] as String),
          returnedOn: r['returned'] == null
              ? null
              : DateTime.parse(r['returned'] as String),
          finePaid: r['finePaid'] == true,
        ));
      }
      _transactions
        ..clear()
        ..addAll(out);
      if (AuthService.instance.currentUser?.role == UserRole.librarian) {
        await AuthService.instance.loadBorrowers();
      }
    } catch (_) {}
  }

  // ---- Catalog ----

  /// Throws if the server rejects the book.
  Future<void> add(Book b) async {
    final saved = _fromServer(await BookApi.create(b.toServer()));
    _books.add(saved);
    notifyListeners();
  }

  /// Adds many books at once. Returns how many the server accepted.
  Future<int> addAll(List<Book> list) async {
    var n = 0;
    for (final b in list) {
      try {
        _books.add(_fromServer(await BookApi.create(b.toServer())));
        n++;
      } catch (_) {}
    }
    if (n > 0) notifyListeners();
    return n;
  }

  Future<void> update(Book b) async {
    final i = _books.indexWhere((x) => x.id == b.id);
    if (i == -1 || b.remoteId.isEmpty) return;
    final saved = _fromServer(await BookApi.update(b.remoteId, b.toServer()));
    _books[i] = saved;
    for (var k = 0; k < _transactions.length; k++) {
      if (_transactions[k].bookId == saved.id) {
        _transactions[k] = _transactions[k].withBook(saved);
      }
    }
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> remove(int id) async {
    if (_transactions.any((t) => !t.returned && t.bookId == id)) {
      return 'This book is currently borrowed and can\'t be deleted.';
    }
    final i = _books.indexWhere((x) => x.id == id);
    if (i == -1) return 'Book not found.';
    try {
      await BookApi.remove(_books[i].remoteId);
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    _books.removeAt(i);
    notifyListeners();
    return null;
  }

  // ---- Availability ----

  int activeFor(Book b) =>
      _transactions.where((t) => !t.returned && t.bookId == b.id).length;

  int copiesLeft(Book b) {
    final left = b.copiesAvailable - activeFor(b);
    return left < 0 ? 0 : left;
  }

  bool isAvailable(Book b) => copiesLeft(b) > 0;

  // ---- Students ----

  AppUser? studentByEmail(String email) {
    final e = email.trim().toLowerCase();
    for (final s in AuthService.instance.borrowers) {
      if (s.email.trim().toLowerCase() == e) return s;
    }
    return null;
  }

  List<BookTransaction> recordsOf(String email) {
    final e = email.trim().toLowerCase();
    return _transactions.where((t) => t.borrowerEmail == e).toList();
  }

  List<BookTransaction> activeLoansOf(String email) =>
      recordsOf(email).where((t) => !t.returned).toList();

  // Unpaid fines: active overdue loans plus returned-late loans not yet paid.
  double finesOutstanding(String email) =>
      recordsOf(email).fold<double>(0, (sum, t) => sum + t.fineOwed);

  double get outstandingFines =>
      _transactions.fold<double>(0, (sum, t) => sum + t.fineOwed);

  /// Returns a reason the student can't borrow, or null if eligible.
  String? eligibility(AppUser s, [Book? b]) {
    final active = activeLoansOf(s.email);
    if (active.any((t) => t.overdue)) {
      return 'Borrower has overdue books. Return them first.';
    }
    final owed = finesOutstanding(s.email);
    if (owed > 0) {
      return 'Borrower has unpaid fines (₱${owed.toStringAsFixed(2)}).';
    }
    if (active.length >= maxActiveLoans) {
      return 'Borrowing limit reached ($maxActiveLoans books).';
    }
    if (b != null) {
      if (active.any((t) => t.bookId == b.id)) {
        return 'Borrower already has this book.';
      }
      if (!isAvailable(b)) return 'No copies available.';
    }
    return null;
  }

  // ---- Transactions ----

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  /// Returns an error message, or null on success. Due date is set by the server.
  Future<String?> checkOut(Book b, AppUser s) async {
    final err = eligibility(s, b);
    if (err != null) return err;
    try {
      await BorrowApi.issue(b.remoteId, s.email);
    } catch (e) {
      return _msg(e);
    }
    await reload();
    return null;
  }

  Future<String?> returnBook(int id) async {
    final i = _transactions.indexWhere((t) => t.id == id);
    if (i == -1) return 'Transaction not found.';
    if (_transactions[i].returned) return 'Already returned.';
    try {
      await BorrowApi.returnBook(_transactions[i].remoteId);
    } catch (e) {
      return _msg(e);
    }
    await reload();
    return null;
  }

  Future<String?> payFine(int id) async {
    final i = _transactions.indexWhere((t) => t.id == id);
    if (i == -1) return 'Transaction not found.';
    final t = _transactions[i];
    if (!t.returned) return 'Return the book before paying the fine.';
    if (t.fine <= 0) return 'No fine on this record.';
    if (t.finePaid) return 'Fine already paid.';
    try {
      await BorrowApi.payFine(t.remoteId);
    } catch (e) {
      return _msg(e);
    }
    await reload();
    return null;
  }

  /// Used by the student side so both apps share one record.
  Future<void> returnLatest(Book b, String email) async {
    final e = email.trim().toLowerCase();
    final i = _transactions
        .indexWhere((t) => !t.returned && t.bookId == b.id && t.borrowerEmail == e);
    if (i == -1) return;
    await returnBook(_transactions[i].id);
  }
}