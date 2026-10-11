import 'package:flutter/foundation.dart';

import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Read-only view of one transaction, for the student screens.
class BorrowedBook {
  const BorrowedBook({
    required this.txId,
    required this.book,
    required this.borrowedOn,
    required this.dueOn,
    this.returnedOn,
  });

  final int txId;
  final Book book;
  final DateTime borrowedOn;
  final DateTime dueOn;
  final DateTime? returnedOn;

  bool get isReturned => returnedOn != null;

  // Negative when past the due date.
  int get daysLeft => dueOn.difference(_dateOnly(DateTime.now())).inDays;

  bool get isOverdue => !isReturned && daysLeft < 0;
  int get daysOverdue => isOverdue ? -daysLeft : 0;
  double get fine => daysOverdue * BorrowStore.finePerDay;
}

/// The signed-in student's loans. Data lives in LibraryService.
class BorrowStore extends ChangeNotifier {
  BorrowStore._() {
    LibraryService.instance.addListener(notifyListeners);
    AuthService.instance.addListener(notifyListeners);
  }
  static final BorrowStore instance = BorrowStore._();

  static const loanDays = LibraryService.loanDays;
  static const finePerDay = LibraryService.finePerDay;

  List<BorrowedBook> get _all {
    final user = AuthService.instance.currentUser;
    if (user == null) return const [];
    final lib = LibraryService.instance;
    return [
      for (final t in lib.recordsOf(user.email))
        BorrowedBook(
          txId: t.id,
          book: t.book,
          borrowedOn: t.borrowedOn,
          dueOn: _dateOnly(t.due),
          returnedOn: t.returnedOn,
        ),
    ];
  }

  // Every book not yet returned (current + overdue).
  List<BorrowedBook> get items => _all.where((e) => !e.isReturned).toList();

  List<BorrowedBook> get current =>
      _all.where((e) => !e.isReturned && !e.isOverdue).toList();

  List<BorrowedBook> get overdue => _all.where((e) => e.isOverdue).toList();

  List<BorrowedBook> get history {
    final list = _all.where((e) => e.isReturned).toList();
    list.sort((a, b) => b.returnedOn!.compareTo(a.returnedOn!));
    return list;
  }

  bool isBorrowed(Book b) => _all.any((e) => !e.isReturned && e.book.id == b.id);

  /// Returns false if blocked (already borrowed, limit, overdue, no copies).
  bool borrow(Book b, {DateTime? borrowedOn}) {
    final user = AuthService.instance.currentUser;
    if (user == null) return false;
    return LibraryService.instance.checkOut(b, user, borrowedOn: borrowedOn) ==
        null;
  }

  int copiesLeft(Book b) => LibraryService.instance.copiesLeft(b);

  bool isAvailable(Book b) => copiesLeft(b) > 0;

  void giveBack(Book b) {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    LibraryService.instance.returnLatest(b, user.email);
  }
}