import 'package:flutter/foundation.dart';
import 'package:library_management_system_mobile/models/book.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

class BorrowedBook {
  BorrowedBook({
    required this.book,
    required this.borrowedOn,
    required this.dueOn,
    this.returnedOn,
  });

  final Book book;
  final DateTime borrowedOn;
  final DateTime dueOn;
  DateTime? returnedOn;

  bool get isReturned => returnedOn != null;

  // Negative when past the due date.
  int get daysLeft => dueOn.difference(_dateOnly(DateTime.now())).inDays;

  bool get isOverdue => !isReturned && daysLeft < 0;
  int get daysOverdue => isOverdue ? -daysLeft : 0;
  double get fine => daysOverdue * BorrowStore.finePerDay;
}

class BorrowStore extends ChangeNotifier {
  BorrowStore._();
  static final BorrowStore instance = BorrowStore._();

  static const loanDays = 14;
  static const finePerDay = 5.0;

  final List<BorrowedBook> _all = [];

  // Every book not yet returned (current + overdue).
  List<BorrowedBook> get items =>
      List.unmodifiable(_all.where((e) => !e.isReturned));

  List<BorrowedBook> get current =>
      _all.where((e) => !e.isReturned && !e.isOverdue).toList();

  List<BorrowedBook> get overdue =>
      _all.where((e) => e.isOverdue).toList();

  List<BorrowedBook> get history {
    final list = _all.where((e) => e.isReturned).toList();
    list.sort((a, b) => b.returnedOn!.compareTo(a.returnedOn!));
    return list;
  }

  String _key(Book b) => '${b.title}|${b.author}';

  bool isBorrowed(Book b) =>
      _all.any((e) => !e.isReturned && _key(e.book) == _key(b));

  // Returns false if the book already borrowed
  // [borrowedOn] for testing overdue books.
  bool borrow(Book b, {DateTime? borrowedOn}) {
    if (isBorrowed(b)) return false;
    final start = _dateOnly(borrowedOn ?? DateTime.now());
    _all.add(BorrowedBook(
      book: b,
      borrowedOn: start,
      dueOn: start.add(const Duration(days: loanDays)),
    ));
    notifyListeners();
    return true;
  }

  // Copies still on the shelf after subtracting active loans
  int copiesLeft(Book b) {
    final taken =
        _all.where((e) => !e.isReturned && _key(e.book) == _key(b)).length;
    final left = b.copiesAvailable - taken;
    return left < 0 ? 0 : left;
  }

  bool isAvailable(Book b) => copiesLeft(b) > 0;

  void giveBack(Book b) {
    for (final e in _all) {
      if (!e.isReturned && _key(e.book) == _key(b)) {
        e.returnedOn = DateTime.now();
        break;
      }
    }
    notifyListeners();
  }
}