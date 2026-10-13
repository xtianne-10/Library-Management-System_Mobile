import 'package:flutter/foundation.dart';

import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

// Read-only view of one transaction for the borrower screens
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

  // Negative when past the due date
  int get daysLeft => dueOn.difference(_dateOnly(DateTime.now())).inDays;

  bool get isOverdue => !isReturned && daysLeft < 0;
  int get daysOverdue => isOverdue ? -daysLeft : 0;
  double get fine => daysOverdue * BorrowStore.finePerDay;
}

enum RequestStatus { pending, declined }

// A borrower's request to borrow a book; waiting for approval
class BorrowRequest {
  BorrowRequest({
    required this.id,
    required this.book,
    required this.user,
    required this.email,
    required this.requestedOn,
  });

  final int id;
  final Book book;
  final dynamic user;
  final String email;
  final DateTime requestedOn;
  RequestStatus status = RequestStatus.pending;
}

// The signed-in borrower's loans; Data lives in LibraryService
// Borrow requests wait here until the librarian approves them
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

  // Every book not yet returned (current + overdue)
  List<BorrowedBook> get items => _all.where((e) => !e.isReturned).toList();

  List<BorrowedBook> get current =>
      _all.where((e) => !e.isReturned && !e.isOverdue).toList();

  List<BorrowedBook> get overdue => _all.where((e) => e.isOverdue).toList();

  List<BorrowedBook> get history {
    final list = _all.where((e) => e.isReturned).toList();
    list.sort((a, b) => b.returnedOn!.compareTo(a.returnedOn!));
    return list;
  }

    // Borrow requests (need librarian approval). The server keeps them and
  // LibraryService loads them.

  BorrowRequest _asRequest(LoanRequest r) => BorrowRequest(
        id: r.id,
        book: r.book,
        user: null,
        email: r.borrowerEmail,
        requestedOn: r.requestedOn,
      );

  String get _myEmail => AuthService.instance.currentUser?.email ?? '';

  bool isPending(Book b) =>
      LibraryService.instance.hasPendingFor(b, _myEmail);

  bool isDeclined(Book b) =>
      LibraryService.instance.wasDeclinedFor(b, _myEmail);

  // The borrower's active loan for this book, or null
  BorrowedBook? loanOf(Book b) {
    for (final e in items) {
      if (e.book.id == b.id) return e;
    }
    return null;
  }

  // Borrower: ask to borrow. Returns an error message, or null if sent
  Future<String?> requestBorrow(Book b) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return 'Please sign in first.';
    if (isBorrowed(b)) return 'You already borrowed this book.';
    return LibraryService.instance.requestBorrow(b, user);
  }

  // Borrower: this borrower's requests that are still waiting
  List<BorrowRequest> get myPendingRequests => LibraryService.instance
      .requestsOf(_myEmail)
      .where((r) => !r.declined)
      .map(_asRequest)
      .toList();

  // Borrower: withdraw a pending request. Returns an error message, or null
  Future<String?> cancelRequest(BorrowRequest r) =>
      LibraryService.instance.cancelRequest(r.id);

  bool isBorrowed(Book b) => _all.any((e) => !e.isReturned && e.book.id == b.id);

  // borrowedOn is ignored now; the server sets the date
  Future<bool> borrow(Book b, {DateTime? borrowedOn}) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return false;
    return await LibraryService.instance.checkOut(b, user) == null;
  }

  int copiesLeft(Book b) => LibraryService.instance.copiesLeft(b);

  bool isAvailable(Book b) => copiesLeft(b) > 0;

  Future<String?> giveBack(Book b) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return 'Please sign in first.';
    return LibraryService.instance.returnLatest(b, user.email);
  }

  // Returns exactly this loan. Returns an error message, or null on success
  Future<String?> giveBackLoan(BorrowedBook loan) =>
      LibraryService.instance.returnBook(loan.txId);
}