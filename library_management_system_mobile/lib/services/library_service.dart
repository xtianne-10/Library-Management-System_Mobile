import 'package:flutter/foundation.dart';

import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class BookTransaction {
  const BookTransaction({
    required this.id,
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

  BookTransaction markReturned(DateTime when) => BookTransaction(
        id: id,
        bookId: bookId,
        book: book,
        title: title,
        borrower: borrower,
        borrowerEmail: borrowerEmail,
        borrowedOn: borrowedOn,
        due: due,
        returnedOn: when,
        finePaid: finePaid,
      );

  BookTransaction markFinePaid() => BookTransaction(
        id: id,
        bookId: bookId,
        book: book,
        title: title,
        borrower: borrower,
        borrowerEmail: borrowerEmail,
        borrowedOn: borrowedOn,
        due: due,
        returnedOn: returnedOn,
        finePaid: true,
      );
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

  // ---- Catalog ----

  void add(Book b) {
    final nextId = _books.fold<int>(0, (m, x) => x.id > m ? x.id : m) + 1;
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
    for (final s in AuthService.instance.students) {
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
      return 'Student has overdue books. Return them first.';
    }
    final owed = finesOutstanding(s.email);
    if (owed > 0) {
      return 'Student has unpaid fines (₱${owed.toStringAsFixed(2)}).';
    }
    if (active.length >= maxActiveLoans) {
      return 'Borrowing limit reached ($maxActiveLoans books).';
    }
    if (b != null) {
      if (active.any((t) => t.bookId == b.id)) {
        return 'Student already has this book.';
      }
      if (!isAvailable(b)) return 'No copies available.';
    }
    return null;
  }

  // ---- Transactions ----

  /// Returns an error message, or null on success. Due date is automatic.
  String? checkOut(Book b, AppUser s, {DateTime? borrowedOn}) {
    final err = eligibility(s, b);
    if (err != null) return err;
    final start = _dateOnly(borrowedOn ?? DateTime.now());
    _transactions.insert(
      0,
      BookTransaction(
        id: _nextTxId++,
        bookId: b.id,
        book: b,
        title: b.title,
        borrower: s.fullName,
        borrowerEmail: s.email.trim().toLowerCase(),
        borrowedOn: start,
        due: start.add(const Duration(days: loanDays)),
      ),
    );
    notifyListeners();
    return null;
  }

  String? returnBook(int id) {
    final i = _transactions.indexWhere((t) => t.id == id);
    if (i == -1) return 'Transaction not found.';
    if (_transactions[i].returned) return 'Already returned.';
    _transactions[i] = _transactions[i].markReturned(DateTime.now());
    notifyListeners();
    return null;
  }

  String? payFine(int id) {
    final i = _transactions.indexWhere((t) => t.id == id);
    if (i == -1) return 'Transaction not found.';
    final t = _transactions[i];
    if (!t.returned) return 'Return the book before paying the fine.';
    if (t.fine <= 0) return 'No fine on this record.';
    if (t.finePaid) return 'Fine already paid.';
    _transactions[i] = t.markFinePaid();
    notifyListeners();
    return null;
  }

  /// Used by the student side so both apps share one record.
  void returnLatest(Book b, String email) {
    final e = email.trim().toLowerCase();
    final i = _transactions
        .indexWhere((t) => !t.returned && t.bookId == b.id && t.borrowerEmail == e);
    if (i == -1) return;
    _transactions[i] = _transactions[i].markReturned(DateTime.now());
    notifyListeners();
  }
}