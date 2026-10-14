import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
import 'package:library_management_system_mobile/utils/csv_download.dart';

import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/screens/verify_return.dart';
import 'package:library_management_system_mobile/utils/validators.dart';
import 'package:library_management_system_mobile/utils/confirm_dialog.dart';

const _confirmDialog = confirmDialog;

const _categories = ['Fiction', 'Non-Fiction', 'Academic', 'Restricted'];

const _otherReason = 'Other';
const _declineReasons = [
  'You have an overdue book.',
  'You have an unpaid fine.',
  "You've reached the borrowing limit.",
  'This book is reserved for a class.',
  'No copies are available right now.',
  'This book is for restricted use only.',
  _otherReason,
];

String _cleanIsbn(String s) => s.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

// MM/DD/YYYY (or M/D/YYYY, also with dashes) -> DateTime, or null if invalid
DateTime? _parseUsDate(String s) {
  final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(s.trim());
  if (m == null) return null;
  final mo = int.parse(m.group(1)!);
  final d = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  final dt = DateTime(y, mo, d);
  return (dt.year == y && dt.month == mo && dt.day == d) ? dt : null;
}

String? _validateIsbn(String? v) {
  final s = _cleanIsbn(v ?? '');
  if (s.isEmpty) return 'ISBN is required.';
  if (!RegExp(r'^(\d{9}[\dX]|\d{13})$').hasMatch(s)) {
    return 'Enter a valid ISBN (10 or 13 digits).';
  }
  return null;
}

String? _validatePages(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Number of pages is required.';
  final n = int.tryParse(s);
  if (n == null || n < 1 || n > 10000) {
    return 'Enter a whole number from 1 to 10000.';
  }
  return null;
}

// Description is optional now
String? _validateDescription(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return null;
  if (s.length < 10) return 'Write at least 10 characters, or leave it empty.';
  if (s.length > 300) return 'Keep it under 300 characters.';
  return null;
}

// Change this one line if your enum is named differently (e.g. UserRole.faculty)
bool _isFaculty(AppUser u) => u.role == UserRole.professor;

// Same colors as loanTone() in HomeLibrarian.jsx
Color _loanTone(int count) {
  if (count >= LibraryService.maxActiveLoans) return const Color(0xFFC0121F);
  if (count > LibraryService.maxActiveLoans / 2) return const Color(0xFFEEA51C);
  return const Color(0xFF0C7A43);
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar(this.user, {this.radius = 20});
  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = user.avatar;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Palette.burgundy,
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null
          ? Text(user.initial,
              style: TextStyle(
                  color: Palette.creamLight,
                  fontWeight: FontWeight.w700,
                  fontSize: radius * 0.8))
          : null,
    );
  }
}

class _SolidPill extends StatelessWidget {
  const _SolidPill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(99)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

String _fmt(DateTime? d) =>
    d == null ? '-' : '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

const _cardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
  side: BorderSide(color: Color(0x2655161D)),
);

const _tableCardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  side: BorderSide(color: Color(0x334A1F1F)),
);

class _BookCover extends StatelessWidget {
  const _BookCover(this.bookId, this.title, {this.w = 34, this.h = 50});
  final int bookId;
  final String title;
  final double w, h;

  @override
  Widget build(BuildContext context) {
    Book? b;
    for (final x in LibraryService.instance.books) {
      if (x.id == bookId) {
        b = x;
        break;
      }
    }
    return _Cover(
      url: b?.imageUrl ?? '',
      bytes: b?.imageBytes,
      color: b?.color ?? Palette.burgundy,
      title: title,
      w: w,
      h: h,
    );
  }
}

const _statIcons = {
  'Total Book Copies': Icons.menu_book,
  'Available Copies': Icons.check_circle_outline,
  'Currently Borrowed': Icons.bookmark,
  'Overdue Books': Icons.warning_amber_rounded,
  'Pending Requests': Icons.how_to_reg,
  'Due Today': Icons.event_available,
};

OutlineInputBorder _border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

InputDecoration _fieldDec({String? label, String? hint, Widget? prefix}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _border(Palette.burgundy.withAlpha(50)),
      enabledBorder: _border(Palette.burgundy.withAlpha(50)),
      focusedBorder: _border(Palette.burgundy, 1.6),
    );

class _Section extends StatelessWidget {
  const _Section(this.title, this.icon, {this.actionLabel, this.onAction});
  final String title;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Palette.burgundy.withAlpha(18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Palette.burgundy, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Georgia',
                      color: Palette.burgundy,
                      letterSpacing: -0.2,
                    )),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0B4A8B),
                visualDensity: VisualDensity.compact,
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              child: Text(actionLabel!),
            ),
        ],
      );
}

class _LibNavBar extends StatelessWidget {
  const _LibNavBar({
    required this.index,
    required this.onChanged,
    this.overdue = 0,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final int overdue;

  @override
  Widget build(BuildContext context) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final on = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? Palette.amber : Palette.creamMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Palette.amber
                  : Palette.creamLight,
            )),
      ),
      child: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      backgroundColor: Palette.burgundy,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black26,
      elevation: 8,
      indicatorColor: Colors.white.withAlpha(30),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview'),
        const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Books'),
        NavigationDestination(
            icon: Badge(
              isLabelVisible: overdue > 0,
              label: Text('$overdue'),
              child: const Icon(Icons.groups_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: overdue > 0,
              label: Text('$overdue'),
              child: const Icon(Icons.groups),
            ),
            label: 'Borrower'),
        const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile'),
      ],
      ),
    );
  }
}

class LibrarianScreen extends StatefulWidget {
  const LibrarianScreen({super.key});

  @override
  State<LibrarianScreen> createState() => _LibrarianScreenState();
}

class _LibrarianScreenState extends State<LibrarianScreen> {
  final _lib = LibraryService.instance;
  int _tab = 0;
  String _query = '';
  String _categoryFilter = 'All';
  String _sortKey = 'title';
  bool _asc = true;
  String _txFilter = 'All Statuses';
  String _studentQuery = '';
  int _borrowerView = 0; // 0 = Lookup, 1 = Transactions

  final Set<String> _seenNotes = {};
  final Set<String> _clearedNotes = {};
  final Set<int> _returning = {};
  Timer? _poll;

  String _noteKey((IconData, String, String, Color) n) => '${n.$2}|${n.$3}';
  int get _unseenCount =>
      _notifications().where((n) => !_seenNotes.contains(_noteKey(n))).length;

  static const _pageSize = 5;
  int _catalogPage = 0;
  int _studentPage = 0;
  int _txPage = 0;

  int _clampPage(int page, int total) {
    final pages = (total / _pageSize).ceil();
    if (pages <= 1) return 0;
    return page.clamp(0, pages - 1);
  }

  // Returns just the items for the current page.
  List<T> _slice<T>(List<T> list, int page) {
    final p = _clampPage(page, list.length);
    final start = p * _pageSize;
    if (start >= list.length) return const [];
    final end = (start + _pageSize).clamp(0, list.length);
    return list.sublist(start, end);
  }

  static const _sortOptions = {
    'title': 'Title',
    'author': 'Author',
    'publisher': 'Publisher',
    'category': 'Category',
    'published': 'Published Date',
    'status': 'Status',
  };

  bool get _isLibrarian =>
      AuthService.instance.currentUser?.role == UserRole.librarian;

  @override
  void initState() {
    super.initState();
    if (!_isLibrarian) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      });
      return;
    }
    _lib.addListener(_refresh);
    _lib.ensureLoaded();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _lib.reload());
    AuthService.instance.refresh().then((_) => _refresh());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lib.removeListener(_refresh);
    _poll?.cancel();
    super.dispose();
  }

  String _val(Book b) => switch (_sortKey) {
        'author' => b.author,
        'publisher' => b.publisher,
        'category' => b.category,
        'published' => b.published?.toIso8601String() ?? '',
        'status' => _lib.isAvailable(b) ? 'Available' : 'Unavailable',
        _ => b.title,
      };

  List<Book> get _visibleBooks {
    final q = _query.trim().toLowerCase();
    final list = _lib.books
        .where((b) =>
            (_categoryFilter == 'All' || b.category == _categoryFilter) &&
            (q.isEmpty ||
                b.title.toLowerCase().contains(q) ||
                b.author.toLowerCase().contains(q)))
        .toList()
      ..sort((a, b) {
        final c = _val(a).toLowerCase().compareTo(_val(b).toLowerCase());
        return _asc ? c : -c;
      });
    return list;
  }

  Future<void> _openForm([Book? book]) async {
    final result = await Navigator.push<Book>(
      context,
      MaterialPageRoute(builder: (_) => _BookForm(book: book)),
    );
    if (result == null) return;
    final dup = _lib.books.any((b) =>
        (book == null || b.id != book.id) &&
        b.title.toLowerCase() == result.title.toLowerCase() &&
        b.author.toLowerCase() == result.author.toLowerCase());
    if (dup) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A book with this title and author already exists.')));
      }
      return;
    }
    try {
      book == null ? await _lib.add(result) : await _lib.update(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(book == null ? 'Book added.' : 'Book updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save the book: $e')));
      }
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: Palette.textMuted),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE00000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      AuthService.instance.logout();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future<void> _confirmDelete(Book b) async {
    if (_lib.activeFor(b) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This book is currently borrowed and can\'t be deleted.'),
      ));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text("Delete ${b.title} from the catalog? This can't be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC0121F)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final err = await _lib.remove(b.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err ?? 'Book deleted.')));
    }
  }

  Future<void> _openIssue({Book? book, AppUser? student}) async {
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _IssueSheet(book: book, student: student),
    );
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _openImport() async {
    final msg = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Palette.page,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ImportSheet(),
    );
    if (msg != null && mounted) {
      setState(() => _catalogPage = 0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  int _countFor(String f) => switch (f) {
        'Not Returned' => _lib.transactions.where((t) => !t.returned).length,
        'Overdue' => _lib.transactions.where((t) => t.overdue).length,
        'Pending Return' =>
          _lib.transactions.where((t) => t.pendingReturn).length,
        'Returned' => _lib.transactions.where((t) => t.returned).length,
        _ => _lib.transactions.length,
      };

  String _today() {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    final d = DateTime.now();
    return '${days[d.weekday - 1]}, ${_fmt(d)}';
  }

  List<Widget> _overview(List<(String, String, Color)> stats) {
    final pending = _lib.pendingRequests;
    final shownPending = pending.take(4).toList();
    final overdue = _lib.transactions.where((t) => t.overdue).toList()
      ..sort((a, b) => b.daysOverdue.compareTo(a.daysOverdue));
    final shownOverdue = overdue.take(4).toList();

    Widget listCard(List<Widget> rows) => Card(
          elevation: 0,
          color: Palette.card,
          shape: _cardShape,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: Color(0x2655161D)),
                rows[i],
              ],
            ],
          ),
        );

    return [
      Text(_today(),
          style: const TextStyle(
              color: Palette.textMuted, fontStyle: FontStyle.italic)),
      const SizedBox(height: 14),

      // Quick actions
      const _Section('Quick Actions', Icons.bolt),
      const SizedBox(height: 12),
            GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.3,
        children: [
          _QuickAction(
            icon: Icons.assignment_ind_outlined,
            label: 'Borrowing',
            sub: 'Issue a book',
            onTap: () => _openIssue(),
          ),
          _QuickAction(
            icon: Icons.assignment_return_outlined,
            label: 'Returns',
            sub: 'Verify returns',
            badge: _lib.transactions.where((t) => t.pendingReturn).length,
            onTap: _openVerifyReturn,
          ),
          _QuickAction(
            icon: Icons.menu_book_outlined,
            label: 'Catalog',
            sub: 'Add and manage',
            onTap: () => setState(() {
              _tab = 1;
              _sortKey = 'title';
              _asc = true;
              _catalogPage = 0;
            }),
          ),
          _QuickAction(
            icon: Icons.history,
            label: 'History',
            sub: 'All transactions',
            onTap: () => _goTransactions('All Statuses'),
          ),
        ],
      ),
      const SizedBox(height: 28),

      // Six KPI cards
      const _Section('Library at a Glance', Icons.auto_stories),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.7,
        children: [
          for (final s in stats)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _goStat(s.$1),
              child: _StatTile(
                label: s.$1,
                value: s.$2,
                color: s.$3,
                icon: _statIcons[s.$1] ?? Icons.circle,
              ),
            ),
        ],
      ),
      const SizedBox(height: 28),

      // Borrowing vs returns
      const _Section('Borrowing Activity', Icons.bar_chart),
      const SizedBox(height: 12),
      _BorrowChart(
          transactions: _lib.transactions, requests: _lib.pendingRequests),
      const SizedBox(height: 28),

      // Analytics (same charts as the web dashboard)
      const _Section('Analytics', Icons.insights),
      const SizedBox(height: 12),
      const _AnalyticsSection(),
      const SizedBox(height: 28),

      // Pending requests
      _Section('Pending Requests (${pending.length})', Icons.how_to_reg,
          actionLabel: pending.isEmpty ? null : 'View all',
          onAction: _openRequests),
      const SizedBox(height: 12),
      if (pending.isEmpty)
        const _EmptyNote(
            icon: Icons.verified_outlined,
            text: 'No requests waiting for approval.')
      else ...[
        listCard([
          for (final r in shownPending)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: Palette.amber.withAlpha(30),
                child: const Icon(Icons.how_to_reg,
                    size: 18, color: Palette.amber),
              ),
              title: Text(r.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${r.borrower} · ${_fmt(r.requestedOn)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: TextButton(
                onPressed: _openRequests,
                style: TextButton.styleFrom(foregroundColor: Palette.burgundy),
                child: const Text('Review'),
              ),
            ),
        ]),
      ],
      const SizedBox(height: 20),

      // Overdue books
      _Section('Overdue Books', Icons.warning_amber_rounded,
          actionLabel: overdue.isEmpty ? null : 'View all',
          onAction: () => _goTransactions('Overdue')),
      const SizedBox(height: 12),
      if (overdue.isEmpty)
        const _EmptyNote(
            icon: Icons.verified_outlined, text: 'Nothing is overdue.')
      else ...[
        listCard([
          for (final t in shownOverdue)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFC0121F).withAlpha(30),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 18, color: Color(0xFFC0121F)),
              ),
              title: Text(t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${t.borrower} · ${t.daysOverdue} ${t.daysOverdue == 1 ? 'day' : 'days'} late',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              trailing: Text('₱${t.fine.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Color(0xFFC0121F), fontWeight: FontWeight.w700)),
            ),
        ]),
      ],
    ];
  }

  void _goTransactions(String filter) => setState(() {
        _tab = 2;
        _borrowerView = 1;
        _txFilter = filter;
        _txPage = 0;
      });

  void _goStat(String label) {
    switch (label) {
      case 'Total Book Copies':
        setState(() => _tab = 1);
      case 'Available Copies':
        setState(() {
          _tab = 1;
          _sortKey = 'status';
          _asc = true;
          _catalogPage = 0;
        });
      case 'Pending Requests':
        _openRequests();
      case 'Overdue Books':
        _goTransactions('Overdue');
      default: // Currently Borrowed, Due Today
        _goTransactions('Not Returned');
    }
  }

  List<(IconData, String, String, Color)> _notifications() {
    const red = Color(0xFFC0121F);
    final now = DateTime.now();
    final out = <(IconData, String, String, Color)>[];
    for (final t in _lib.transactions) {
      final due = t.due;
      if (t.overdue) {
        out.add((
          Icons.warning_amber_rounded,
          'Overdue: ${t.title}',
          '${t.borrower} · ${t.daysOverdue} ${t.daysOverdue == 1 ? 'day' : 'days'} late',
          red
        ));
      } else if (!t.returned && due != null && due.difference(now).inDays < 2) {
        out.add((
          Icons.schedule,
          'Due soon: ${t.title}',
          '${t.borrower} · due ${_fmt(due)}',
          Palette.amber
        ));
      }
      if (t.returned && t.fine > 0 && !t.finePaid) {
        out.add((
          Icons.payments_outlined,
          'Unpaid fine: ₱${t.fine.toStringAsFixed(2)}',
          '${t.borrower} · ${t.title}',
          red
        ));
      }
    }
    for (final r in _lib.pendingRequests) {
      out.add((
        Icons.how_to_reg,
        'Borrow request: ${r.book.title}',
        '${r.borrower} is waiting for approval.',
        Palette.amber
      ));
    }
    for (final t in _lib.transactions) {
      if (t.pendingReturn) {
        out.add((
          Icons.assignment_return_outlined,
          'Return request: ${t.title}',
          '${t.borrower} is waiting for return verification.',
          Palette.amber
        ));
      }
    }
    for (final b in _lib.books) {
      if (_lib.copiesLeft(b) == 0) {
        out.add((
          Icons.inventory_2_outlined,
          'No copies left: ${b.title}',
          'All ${b.totalCopies} copies are borrowed.',
          Palette.burgundy
        ));
      }
    }
    return out.where((n) => !_clearedNotes.contains(_noteKey(n))).toList();
  }

  void _clearNotes() =>
      setState(() => _clearedNotes.addAll(_notifications().map(_noteKey)));

  // Swap for the real field once AppUser has employeeId.
  String _employeeId(AppUser? u) {
    if (u == null) return '-';
    if (u.idNumber.isNotEmpty) return u.idNumber;
    return u.employeeId.isNotEmpty ? u.employeeId : '-';
  }

  Widget _infoRow(IconData icon, String label, String value) => ListTile(
        dense: true,
        leading: Icon(icon, color: Palette.burgundy),
        title: Text(label,
            style: const TextStyle(fontSize: 12, color: Palette.textMuted)),
        subtitle: Text(value.isEmpty ? '-' : value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Palette.textDark)),
      );

  List<Widget> _profileTab() {
    final u = AuthService.instance.currentUser;
    return [
      Center(
        child: Column(
          children: [
            GestureDetector(
              onTap: _changePhoto,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Palette.burgundy),
                    child: CircleAvatar(
                      radius: 52,
                      backgroundColor: Palette.creamLight,
                      backgroundImage:
                          u?.avatar != null ? MemoryImage(u!.avatar!) : null,
                      child: u?.avatar == null
                          ? Text(u?.initial ?? '?',
                              style: const TextStyle(
                                  fontSize: 44,
                                  color: Palette.burgundy,
                                  fontWeight: FontWeight.w700))
                          : null,
                    ),
                  ),
                  const Positioned(
                    right: 2,
                    bottom: 2,
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: Palette.amber,
                      child: Icon(Icons.camera_alt,
                          size: 17, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(u?.fullName ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: Palette.burgundy)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: Palette.burgundy.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Librarian',
                  style: TextStyle(
                      color: Palette.burgundy, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Card(
        elevation: 0,
        color: Palette.card,
        shape: _cardShape,
        margin: EdgeInsets.zero,
        child: Column(
          children: [
            _infoRow(Icons.person_outline, 'Full name', u?.fullName ?? ''),
            _infoRow(Icons.numbers, 'Employee ID', _employeeId(u)),
            _infoRow(Icons.email_outlined, 'Faculty email', u?.email ?? ''),
            _infoRow(Icons.phone_outlined, 'Phone number', u?.phone ?? ''),
            _infoRow(Icons.shield_outlined, 'Assigned role',
                (u?.assignedRole.isNotEmpty ?? false) ? u!.assignedRole : 'Librarian'),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit profile'),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.burgundy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _changePassword,
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('Password'),
            ),
          ),
        ],
      ),
      if (u?.isHead ?? false) ...[
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addLibrarian,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('Add librarian'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Palette.burgundy,
            side: const BorderSide(color: Palette.burgundy),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout, size: 18),
        label: const Text('Log out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE00000),
          side: const BorderSide(color: Color(0xFFE00000)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ];
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final ok = await _confirmDialog(context, 'Change Photo',
          'Use this photo as your profile picture?', 'Yes, use it');
      if (!ok || !mounted) return;
      AuthService.instance.updateAvatar(bytes);
      setState(() {});
      _snack('Profile picture updated.');
    } catch (_) {
      if (!mounted) return;
      _snack('Could not open the camera or gallery.');
    }
  }

  void _changePhoto() {
    final hasPhoto = AuthService.instance.currentUser?.avatar != null;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                title: Text('Remove photo',
                    style: TextStyle(color: Colors.red.shade700)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final ok = await _confirmDialog(context, 'Remove Photo',
                      'Remove your profile picture?', 'Yes, remove',
                      danger: true);
                  if (!ok || !mounted) return;
                  AuthService.instance.updateAvatar(null);
                  setState(() {});
                  _snack('Profile picture removed.');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final u = AuthService.instance.currentUser;
    if (u == null) return;
    final first = TextEditingController(text: u.firstName);
    final last = TextEditingController(text: u.lastName);
    final phone = TextEditingController(text: u.phone);
    final key = GlobalKey<FormState>();
    String? req(String? v) =>
        (v == null || v.trim().isEmpty) ? 'Required' : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                    controller: first,
                    decoration: _fieldDec(label: 'First name'),
                    validator: req),
                const SizedBox(height: 12),
                TextFormField(
                    controller: last,
                    decoration: _fieldDec(label: 'Last name'),
                    validator: req),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDec(label: 'Phone'),
                  validator: Validators.phone,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              final yes = await _confirmDialog(
                  c, 'Save Profile', 'Save your changes?', 'Yes, save');
              if (yes && c.mounted) Navigator.pop(c, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final err = await AuthService.instance.updateProfile(
        firstName: first.text.trim(),
        lastName: last.text.trim(),
        phone: phone.text.replaceAll(RegExp(r'[\s-]'), ''),
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Profile updated.')));
    }
    first.dispose();
    last.dispose();
    phone.dispose();
  }

  Future<void> _changePassword() async {
    final cur = TextEditingController();
    final next = TextEditingController();
    final conf = TextEditingController();
    final key = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: cur,
                  obscureText: true,
                  decoration: _fieldDec(label: 'Current password'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: _fieldDec(label: 'New password'),
                  validator: (v) {
                    final s = v ?? '';
                    if (s.length < 8) return 'At least 8 characters';
                    if (!RegExp(r'[A-Za-z]').hasMatch(s) ||
                        !RegExp(r'[0-9]').hasMatch(s)) {
                      return 'Use letters and numbers';
                    }
                    if (s == cur.text) return 'Must differ from current';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: conf,
                  obscureText: true,
                  decoration: _fieldDec(label: 'Confirm new password'),
                  validator: (v) =>
                      v == next.text ? null : 'Passwords don\'t match',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              final yes = await _confirmDialog(c, 'Change Password',
                  'Change your password?', 'Yes, change');
              if (yes && c.mounted) Navigator.pop(c, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final err = await AuthService.instance.changePassword(cur.text, next.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err ?? 'Password changed.')));
    }
    cur.dispose();
    next.dispose();
    conf.dispose();
  }

  Future<void> _addLibrarian() async {
    final first = TextEditingController();
    final last = TextEditingController();
    final id = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final pass = TextEditingController();
    final key = GlobalKey<FormState>();
    const auto = AutovalidateMode.onUserInteraction;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add Librarian'),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'They will be asked to change this temporary password on first login.',
                  style: TextStyle(fontSize: 12, color: Palette.textMuted),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: first,
                  decoration: _fieldDec(label: 'First name'),
                  validator: (v) => Validators.name(v, 'First name'),
                  autovalidateMode: auto,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: last,
                  decoration: _fieldDec(label: 'Last name'),
                  validator: (v) => Validators.name(v, 'Last name'),
                  autovalidateMode: auto,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: id,
                  decoration: _fieldDec(label: 'Employee ID'),
                  validator: (v) => Validators.idNumber(v, 'Employee ID'),
                  autovalidateMode: auto,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDec(label: 'Faculty email'),
                  validator: Validators.email,
                  autovalidateMode: auto,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDec(label: 'Phone number (optional)'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? null
                      : Validators.phone(v),
                  autovalidateMode: auto,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: pass,
                  obscureText: true,
                  decoration: _fieldDec(label: 'Temporary password'),
                  validator: Validators.password,
                  autovalidateMode: auto,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              final yes = await _confirmDialog(c, 'Add Librarian',
                  'Create a librarian account for ${first.text.trim()} ${last.text.trim()}?', 'Yes, create');
              if (yes && c.mounted) Navigator.pop(c, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final err = await AuthService.instance.addLibrarian(
        firstName: first.text,
        lastName: last.text,
        idNumber: id.text,
        email: email.text,
        phone: phone.text.replaceAll(RegExp(r'[\s-]'), ''),
        password: pass.text,
      );
      if (!mounted) return;
      _snack(err ?? 'Librarian account created.');
    }
    first.dispose();
    last.dispose();
    id.dispose();
    email.dispose();
    phone.dispose();
    pass.dispose();
  }

  Widget _header() {
    final user = AuthService.instance.currentUser;
    final name = (user?.firstName.trim().isNotEmpty ?? false)
        ? user!.firstName.trim()
        : 'Librarian';
    final text = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 10, 20, 16),
        decoration: const BoxDecoration(
          color: Palette.burgundy,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Palette.amber),
              child: CircleAvatar(
                radius: 21,
                backgroundColor: Palette.creamLight,
                backgroundImage:
                    user?.avatar != null ? MemoryImage(user!.avatar!) : null,
                child: user?.avatar == null
                    ? Text(user?.initial ?? '?',
                        style: const TextStyle(
                            color: Palette.burgundy,
                            fontWeight: FontWeight.w800))
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_greeting()}, $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Palette.creamLight)),
                  const SizedBox(height: 2),
                  Text('Keeper of the Hogwarts Library',
                      style: text.bodyMedium
                          ?.copyWith(color: Palette.creamMuted)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Borrow requests',
              onPressed: _openRequests,
              icon: Badge(
                isLabelVisible: _lib.pendingRequests.isNotEmpty,
                label: Text('${_lib.pendingRequests.length}'),
                child: const Icon(Icons.how_to_reg,
                    color: Palette.creamLight, size: 28),
              ),
            ),
            IconButton(
              tooltip: 'Notifications',
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(25)),
              onPressed: () {
                setState(
                    () => _seenNotes.addAll(_notifications().map(_noteKey)));
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _NotificationsScreen(
                        source: _notifications, onClear: _clearNotes),
                  ),
                );
              },
              icon: Badge(
                isLabelVisible: _unseenCount > 0,
                label: Text('$_unseenCount'),
                child: const Icon(Icons.notifications_outlined,
                    color: Palette.creamLight, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVerifyReturn() async {
    final msg = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const VerifyReturnScreen()),
    );
    if (msg != null && mounted) _snack(msg);
  }

  void _openRequests() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const _RequestsScreen()),
      );

  Future<void> _returnTx(BookTransaction t) async {
    if (_returning.contains(t.id)) return; // ignore double taps
    final late = t.overdue
        ? '\n\nThis book is ${t.daysOverdue} ${t.daysOverdue == 1 ? 'day' : 'days'} late. '
            'A fine of ₱${t.fine.toStringAsFixed(2)} will be recorded.'
        : '';
    final ok = await _confirmDialog(context, 'Mark as Returned',
        'Mark "${t.title}" as returned by ${t.borrower}?$late', 'Yes, return');
    if (!ok || !mounted) return;
    _returning.add(t.id);
    final fine = t.fine;
    final err = await _lib.returnBook(t.id);
    _returning.remove(t.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ??
          (fine > 0
              ? 'Returned "${t.title}". Fine due: ₱${fine.toStringAsFixed(2)}.'
              : 'Returned "${t.title}".')),
    ));
  }

  Future<void> _openStudent(AppUser s) => showDialog<void>(
        context: context,
        builder: (_) => _StudentDialog(
          email: s.email,
          onReturn: _returnTx,
          onIssue: (st) => _openIssue(student: st),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (!_isLibrarian) return const Scaffold();

    final books = _visibleBooks;
    final tx = _lib.transactions
        .where((t) => switch (_txFilter) {
              'All Statuses' => true,
              'Overdue' => t.overdue,
              'Not Returned' => !t.returned,
              'Pending Return' => t.pendingReturn,
              _ => t.returned,
            })
        .toList();
    final all = _lib.books;
    final allStudents = AuthService.instance.borrowers;
    final sq = _studentQuery.trim().toLowerCase();
    final foundStudents = allStudents
        .where((s) =>
            sq.isEmpty ||
            s.fullName.toLowerCase().contains(sq) ||
            s.email.toLowerCase().contains(sq) ||
            s.phone.contains(sq))
        .toList();
    final now = DateTime.now();
    final dueToday = _lib.transactions
        .where((t) =>
            !t.returned &&
            t.due.year == now.year &&
            t.due.month == now.month &&
            t.due.day == now.day)
        .length;
    final stats = [
      ('Total Book Copies',
          '${all.fold<int>(0, (s, b) => s + b.totalCopies)}',
          const Color(0xFFE4F1EE)),
      ('Available Copies',
          '${all.fold<int>(0, (s, b) => s + _lib.copiesLeft(b))}',
          const Color(0xFFFFD6A5)),
      ('Currently Borrowed',
          '${_lib.transactions.where((t) => !t.returned).length}',
          const Color(0xFFDEDAF4)),
      ('Overdue Books',
          '${_lib.transactions.where((t) => t.overdue).length}',
          const Color(0xFFFFADAD)),
      ('Pending Requests', '${_lib.pendingRequests.length}',
          const Color(0xFFFFF1C2)),
      ('Due Today', '$dueToday', const Color(0xFFD7ECFF)),
    ];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Palette.page,
      appBar: PreferredSize(
        preferredSize:
            Size.fromHeight(82 + MediaQuery.of(context).padding.top),
        child: _header(),
      ),
      bottomNavigationBar: _LibNavBar(
        index: _tab,
        onChanged: (i) {
          setState(() => _tab = i);
          if (i == 3) AuthService.instance.refresh().then((_) => _refresh());
          if (i != 3) _lib.reload();
        },
        overdue: _lib.transactions.where((t) => t.overdue).length,
      ),
      floatingActionButton: _tab != 1 ? null : FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: Palette.amber,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Book'),
      ),
      body: ListView(
        key: ValueKey(_tab),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
        children: [
          if (_tab == 0) ..._overview(stats),
          if (_tab == 1) ...[
          // ---- Catalog ----
          const _Section('Book Catalog', Icons.menu_book),
          const SizedBox(height: 10),
          if (_lib.loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_lib.loadError!,
                  style: const TextStyle(
                      color: Color(0xFFC0121F), fontWeight: FontWeight.w600)),
            ),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${books.length} ${books.length == 1 ? 'title' : 'titles'} in the catalog',
                  style: const TextStyle(color: Palette.textMuted),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openImport,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Bulk Import'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.burgundy,
                  side: const BorderSide(color: Palette.amber, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() {
              _query = v;
              _catalogPage = 0;
            }),
            decoration: _fieldDec(
                hint: 'Search by title or author',
                prefix: const Icon(Icons.search)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortKey,
                  isExpanded: true,
                  decoration: _fieldDec(label: 'Sort by'),
                  items: [
                    for (final e in _sortOptions.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() {
                    _sortKey = v ?? 'title';
                    _catalogPage = 0;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: _asc ? 'A to Z' : 'Z to A',
                icon: Icon(_asc ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () => setState(() {
                  _asc = !_asc;
                  _catalogPage = 0;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in const ['All', ..._categories])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _categoryFilter == c,
                      showCheckmark: false,
                      backgroundColor: Colors.white,
                      selectedColor: Palette.burgundy,
                      side: BorderSide(
                          color: Palette.burgundy
                              .withAlpha(_categoryFilter == c ? 255 : 70)),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _categoryFilter == c
                            ? Colors.white
                            : Palette.burgundy,
                      ),
                      onSelected: (_) => setState(() {
                        _categoryFilter = c;
                        _catalogPage = 0;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (books.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  all.isEmpty
                      ? 'No books yet. Tap + Add Book to add one.'
                      : 'No results match your search.',
                  style: const TextStyle(color: Palette.textMuted),
                ),
              ),
            )
          else
            ...[
              for (final b in _slice(books, _catalogPage))
                _CatalogCard(
                  book: b,
                  left: _lib.copiesLeft(b),
                  onIssue: () => _openIssue(book: b),
                  onEdit: () => _openForm(b),
                  onDelete: () => _confirmDelete(b),
                ),
              _Pager(
                page: _clampPage(_catalogPage, books.length),
                total: books.length,
                pageSize: _pageSize,
                onChanged: (p) => setState(() => _catalogPage = p),
              ),
            ],
          const SizedBox(height: 28),

          ],
          if (_tab == 2) ...[
          const _Section('Borrowers', Icons.groups),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 0, icon: Icon(Icons.school), label: Text('Lookup')),
                ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.history_edu),
                    label: Text('Transactions')),
              ],
              selected: {_borrowerView},
              onSelectionChanged: (s) =>
                  setState(() => _borrowerView = s.first),
            ),
          ),
          const SizedBox(height: 16),
          ],
          if (_tab == 2 && _borrowerView == 0) ...[
          // ---- Student lookup ----
          TextField(
            onChanged: (v) => setState(() {
              _studentQuery = v;
              _studentPage = 0;
            }),
            decoration: _fieldDec(
                hint: 'Search by name, email, or phone',
                prefix: const Icon(Icons.person_search)),
          ),
          const SizedBox(height: 12),
          if (foundStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No students found.',
                    style: TextStyle(color: Palette.textMuted)),
              ),
            )
          else
            ...[
              for (final s in _slice(foundStudents, _studentPage))
                _StudentCard(student: s, onTap: () => _openStudent(s)),
              _Pager(
                page: _clampPage(_studentPage, foundStudents.length),
                total: foundStudents.length,
                pageSize: _pageSize,
                onChanged: (p) => setState(() => _studentPage = p),
              ),
            ],
          const SizedBox(height: 28),

          ],
          if (_tab == 2 && _borrowerView == 1) ...[
          // ---- Transactions ----
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openVerifyReturn,
              icon: const Icon(Icons.qr_code_scanner),
              label: Badge(
                isLabelVisible: _lib.transactions.any((t) => t.pendingReturn),
                label: Text(
                    '${_lib.transactions.where((t) => t.pendingReturn).length}'),
                offset: const Offset(16, -8),
                child: const Text('Verify Return'),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.burgundy,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in const [
                  'All Statuses', 'Not Returned', 'Pending Return', 'Overdue', 'Returned',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                          '${f == 'All Statuses' ? 'All' : f} (${_countFor(f)})'),
                      selected: _txFilter == f,
                      showCheckmark: false,
                      backgroundColor: Palette.page,
                      selectedColor: f == 'Overdue'
                          ? const Color(0xFFC0121F)
                          : Palette.burgundy,
                      side: BorderSide(
                          color: f == 'Overdue'
                              ? const Color(0xFFC0121F)
                              : Palette.burgundy,
                          width: 1.2),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _txFilter == f
                            ? Colors.white
                            : (f == 'Overdue'
                                ? const Color(0xFFC0121F)
                                : Palette.burgundy),
                      ),
                      onSelected: (_) => setState(() {
                        _txFilter = f;
                        _txPage = 0;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (tx.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _lib.transactions.isEmpty
                      ? 'No transactions yet.'
                      : 'No results match your filters.',
                  style: const TextStyle(color: Palette.textMuted),
                ),
              ),
            )
          else
            ...[
              for (final t in _slice(tx, _txPage))
                _TxCard(tx: t, onReturn: () => _returnTx(t)),
              _Pager(
                page: _clampPage(_txPage, tx.length),
                total: tx.length,
                pageSize: _pageSize,
                onChanged: (p) => setState(() => _txPage = p),
              ),
            ],
          ],
          if (_tab == 3) ..._profileTab(),
        ],
      ),
    );
  }
}

// ---------- Notifications screen ----------

class _NotificationsScreen extends StatefulWidget {
  const _NotificationsScreen({required this.source, required this.onClear});
  final List<(IconData, String, String, Color)> Function() source;
  final VoidCallback onClear;

  @override
  State<_NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<_NotificationsScreen> {
  static const _size = 6;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.page,
      appBar: AppBar(
        backgroundColor: Palette.burgundy,
        foregroundColor: Palette.creamLight,
        title: const Text('Notifications',
            style: TextStyle(
                fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () {
              widget.onClear();
              setState(() {});
            },
            style: TextButton.styleFrom(foregroundColor: Palette.creamLight),
            child: const Text('Clear all'),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: LibraryService.instance,
        builder: (context, _) {
          final notes = widget.source();
          final pages = (notes.length / _size).ceil();
          final page = pages <= 1 ? 0 : _page.clamp(0, pages - 1);
          final start = page * _size;
          final end = (start + _size).clamp(0, notes.length);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                notes.isEmpty
                    ? 'Nothing needs your attention.'
                    : '${notes.length} ${notes.length == 1 ? 'notification' : 'notifications'}',
                style: const TextStyle(color: Palette.textMuted),
              ),
              const SizedBox(height: 14),
              if (notes.isEmpty)
                const _EmptyNote(
                    icon: Icons.verified_outlined,
                    text: 'You\'re all caught up.')
              else ...[
                for (final n in notes.sublist(start, end))
                  Card(
                    elevation: 0,
                    color: Palette.card,
                    shape: _cardShape,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: n.$4.withAlpha(30),
                        child: Icon(n.$1, color: n.$4, size: 20),
                      ),
                      title: Text(n.$2,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(n.$3),
                    ),
                  ),
                _Pager(
                  page: page,
                  total: notes.length,
                  pageSize: _size,
                  onChanged: (p) => setState(() => _page = p),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------- Small widgets ----------

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Amber text is hard to read on a light tint, so use the darker amber from the web.
    final fg = color == const Color(0xFFEEA51C) ? const Color(0xFF8A5A00) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({this.url = '', this.bytes, required this.color,
      this.w = 40, this.h = 58, this.title = ''});
  final String title;
  final String url;
  final Uint8List? bytes;
  final Color color;
  final double w, h;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        boxShadow: const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(width: w * 0.08, color: Colors.black.withAlpha(40)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                title,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Palette.gold,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.w700,
                  fontSize: w * 0.15,
                  height: 1.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Widget child = placeholder;
    if (bytes != null) {
      child = Image.memory(bytes!, width: w, height: h, fit: BoxFit.cover);
    } else if (url.trim().isNotEmpty) {
      child = Image.network(url.trim(),
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(3), child: child);
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.book,
    required this.left,
    required this.onIssue,
    required this.onEdit,
    required this.onDelete,
  });
  final Book book;
  final int left;
  final VoidCallback onIssue;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (book.publisher.isNotEmpty) book.publisher,
      if (book.published != null) '${book.published!.year}',
    ].join(' · ');

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: _cardShape,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(
                url: book.imageUrl,
                bytes: book.imageBytes,
                color: book.color,
                title: book.title,
                w: 60,
                h: 88),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.2,
                          color: Palette.textDark)),
                  const SizedBox(height: 2),
                  Text('by ${book.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Palette.textMuted, fontSize: 12.5)),
                  if (meta.isNotEmpty)
                    Text(meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Palette.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Badge(book.category, Palette.burgundy),
                      left > 0
                          ? const _Badge('Available', Color(0xFF0C7A43))
                          : const _Badge('Unavailable', Color(0xFFEEA51C)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 14, color: Palette.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text('$left of ${book.totalCopies} available',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      FilledButton(
                        onPressed: left > 0 ? onIssue : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Palette.amber,
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Issue'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More options for ${book.title}',
              icon: const Icon(Icons.more_vert, size: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFFC0121F)),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: Color(0xFFC0121F))),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  const _TxCard({required this.tx, required this.onReturn});
  final BookTransaction tx;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final t = tx;
    const red = Color(0xFFC0121F);
    final color = t.overdue
        ? red
        : t.returned
            ? const Color(0xFF0C7A43)
            : const Color(0xFFEEA51C);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: t.overdue ? red.withAlpha(150) : const Color(0x334A1F1F)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _BookCover(t.bookId, t.title),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(t.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                _Badge(t.overdue ? 'Overdue' : t.status, color),
              ],
            ),
            const SizedBox(height: 6),
            Text('${t.borrower} (${t.borrowerEmail})',
                style: const TextStyle(fontSize: 13)),
            Text('Borrowed ${_fmt(t.borrowedOn)} · Due ${_fmt(t.due)}',
                style:
                    const TextStyle(fontSize: 12, color: Palette.textMuted)),
            if (t.returned)
              Text('Returned ${_fmt(t.returnedOn)}',
                  style:
                      const TextStyle(fontSize: 12, color: Palette.textMuted)),
            if (t.fine > 0)
              Text(
                'Fine: ₱${t.fine.toStringAsFixed(2)} '
                '(${t.daysOverdue} ${t.daysOverdue == 1 ? 'day' : 'days'} late)'
                '${t.finePaid ? ' · PAID' : ''}',
                style: TextStyle(
                    fontSize: 13,
                    color: t.finePaid ? const Color(0xFF0C7A43) : red,
                    fontWeight: FontWeight.w700),
              ),
            if (t.returned && t.fine > 0 && !t.finePaid)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () async {
                    final ok = await _confirmDialog(
                        context,
                        'Mark Fine as Paid',
                        'Mark the fine of ₱${t.fine.toStringAsFixed(2)} for "${t.title}" (${t.borrower}) as paid?',
                        'Yes, mark paid');
                    if (!ok || !context.mounted) return;
                    final err = await LibraryService.instance.payFine(t.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(err ??
                          'Fine of ₱${t.fine.toStringAsFixed(2)} marked as paid.'),
                    ));
                  },
                  child: const Text('Mark fine paid'),
                ),
              ),
            if (!t.returned)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: onReturn,
                  child: const Text('Mark returned'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Prev / Next control. Hides itself when everything fits on one page.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.total,
    required this.pageSize,
    required this.onChanged,
  });

  final int page; // zero-based
  final int total;
  final int pageSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final pages = (total / pageSize).ceil();
    if (pages <= 1) return const SizedBox.shrink();

    final first = page * pageSize + 1;
    final last = ((page + 1) * pageSize).clamp(0, total);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: page > 0 ? () => onChanged(page - 1) : null,
                icon: const Icon(Icons.chevron_left),
                color: Palette.burgundy,
              ),
              Text('Page ${page + 1} of $pages',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              IconButton(
                tooltip: 'Next page',
                onPressed: page < pages - 1 ? () => onChanged(page + 1) : null,
                icon: const Icon(Icons.chevron_right),
                color: Palette.burgundy,
              ),
            ],
          ),
          Text('Showing $first–$last of $total',
              style: const TextStyle(fontSize: 12, color: Palette.textMuted)),
        ],
      ),
    );
  }
}

/// Paged list of transactions (used inside the student sheet).
class _PagedTxList extends StatefulWidget {
  const _PagedTxList({required this.records, required this.onReturn});
  final List<BookTransaction> records;
  final void Function(BookTransaction) onReturn;

  @override
  State<_PagedTxList> createState() => _PagedTxListState();
}

class _PagedTxListState extends State<_PagedTxList> {
  static const _size = 5;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final all = widget.records;
    final pages = (all.length / _size).ceil();
    final page = pages <= 1 ? 0 : _page.clamp(0, pages - 1);
    final start = page * _size;
    final end = (start + _size).clamp(0, all.length);

    return Column(
      children: [
        for (final t in all.sublist(start, end))
          _RecordCard(tx: t, onReturn: () => widget.onReturn(t)),
        _Pager(
          page: page,
          total: all.length,
          pageSize: _size,
          onChanged: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}

class _RecordCard extends StatefulWidget {
  const _RecordCard({required this.tx, required this.onReturn});
  final BookTransaction tx;
  final VoidCallback onReturn;

  @override
  State<_RecordCard> createState() => _RecordCardState();
}

class _RecordCardState extends State<_RecordCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tx;
    const red = Color(0xFFC0121F);
    const green = Color(0xFF0C7A43);
    final color = t.overdue
        ? red
        : t.returned
            ? green
            : const Color(0xFFEEA51C);

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: Palette.textMuted)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: t.overdue ? red.withAlpha(150) : const Color(0x4D2B2B2B)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _BookCover(t.bookId, t.title),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Borrowed ${_fmt(t.borrowedOn)}',
                            style: const TextStyle(
                                fontSize: 12, color: Palette.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Badge(t.overdue ? 'Overdue' : t.status, color),
                  Icon(_open ? Icons.expand_less : Icons.expand_more,
                      size: 20, color: Palette.burgundy),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0x1A4A1F1F))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row('Borrowed', _fmt(t.borrowedOn)),
                  row('Due', _fmt(t.due)),
                  if (t.returned) row('Returned', _fmt(t.returnedOn)),
                  if (t.fine > 0)
                    Text(
                      'Fine: ₱${t.fine.toStringAsFixed(2)} '
                      '(${t.daysOverdue} ${t.daysOverdue == 1 ? 'day' : 'days'} late)'
                      '${t.finePaid ? ' · PAID' : ''}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.finePaid ? green : red),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: !t.returned
                        ? FilledButton(
                            onPressed: widget.onReturn,
                            style: FilledButton.styleFrom(
                              backgroundColor: green,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Mark returned'),
                          )
                        : (t.fine > 0 && !t.finePaid)
                            ? FilledButton.tonal(
                                onPressed: () async {
                                  final ok = await _confirmDialog(
                                      context,
                                      'Mark Fine as Paid',
                                      'Mark the fine of ₱${t.fine.toStringAsFixed(2)} for "${t.title}" (${t.borrower}) as paid?',
                                      'Yes, mark paid');
                                  if (!ok || !context.mounted) return;
                                  final err = await LibraryService.instance
                                      .payFine(t.id);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(err ??
                                        'Fine of ₱${t.fine.toStringAsFixed(2)} marked as paid.'),
                                  ));
                                },
                                child: const Text('Mark fine paid'),
                              )
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onTap});
  final AppUser student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lib = LibraryService.instance;
    final active = lib.activeLoansOf(student.email);
    final overdue = active.where((t) => t.overdue).length;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: _tableCardShape,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        hoverColor: const Color(0xFFFAF6F0),
        onTap: onTap,
        leading: _UserAvatar(student, radius: 20),
        title: Text(student.fullName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${student.email}\n${student.phone}'),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SolidPill('${active.length}/${LibraryService.maxActiveLoans} books',
                _loanTone(active.length)),
            if (overdue > 0) ...[
              const SizedBox(height: 4),
              _SolidPill('$overdue overdue', const Color(0xFFC0121F)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentDialog extends StatelessWidget {
  const _StudentDialog({
    required this.email,
    required this.onReturn,
    required this.onIssue,
  });
  final String email;
  final void Function(BookTransaction) onReturn;
  final void Function(AppUser) onIssue;

  @override
  Widget build(BuildContext context) {
    final lib = LibraryService.instance;
    return ListenableBuilder(
      listenable: lib,
      builder: (context, _) {
        final s = lib.studentByEmail(email);
        if (s == null) return const SizedBox.shrink();
        final records = lib.recordsOf(email);
        final activeCount = lib.activeLoansOf(email).length;
        final problem = lib.eligibility(s);
        final fines = lib.finesOutstanding(email);
        final faculty = _isFaculty(s);
        const red = Color(0xFFC0121F);
        const green = Color(0xFF0C7A43);

        final info = <(String, String)>[
          ('ID number', s.idNumber),
          ('Phone number', s.phone),
          if (faculty)
            ('Department', s.department)
          else ...[
            ('Course', s.course),
            ('Year level', s.yearLevel),
          ],
        ];

        return Dialog(
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: photo, name, role, email
                      Padding(
                        padding: const EdgeInsets.only(right: 36),
                        child: Row(
                          children: [
                            _UserAvatar(s, radius: 36),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.fullName,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Palette.burgundy,
                                          height: 1.2)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Palette.burgundy.withAlpha(25),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                        faculty ? 'Professor' : 'Student',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Palette.burgundy)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(s.email,
                                      style: const TextStyle(
                                          color: Palette.textMuted,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ID / phone / department or course + year
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Palette.burgundy.withAlpha(50)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < info.length; i++)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  border: i == info.length - 1
                                      ? null
                                      : Border(
                                          bottom: BorderSide(
                                              color: Palette.burgundy
                                                  .withAlpha(25))),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(info[i].$1,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Palette.textMuted)),
                                    Text(
                                        info[i].$2.isEmpty ? '-' : info[i].$2,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Eligibility
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (problem == null ? green : red).withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(problem ?? 'Eligible to borrow',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: problem == null ? green : red)),
                      ),
                      const SizedBox(height: 12),

                      // Borrowing limit pill
                      Row(
                        children: [
                          const Text('Borrowing limit: ',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          _SolidPill(
                              '$activeCount/${LibraryService.maxActiveLoans} books',
                              _loanTone(activeCount)),
                        ],
                      ),
                      if (fines > 0) ...[
                        const SizedBox(height: 8),
                        Text('Outstanding fines: ₱${fines.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: red, fontWeight: FontWeight.w700)),
                      ],
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => onIssue(s),
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.amber,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('+ Issue a book'),
                        ),
                      ),

                      // Records (paged, 3 per page)
                      const SizedBox(height: 20),
                      const Text('Borrowing records',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      if (records.isEmpty)
                        const Text('No borrowing records yet.',
                            style: TextStyle(color: Palette.textMuted))
                      else
                        _PagedTxList(records: records, onReturn: onReturn),
                    ],
                  ),
                ),

                // Close button
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withAlpha(13)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IssueSheet extends StatefulWidget {
  const _IssueSheet({this.book, this.student});
  final Book? book;
  final AppUser? student;

  @override
  State<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends State<_IssueSheet> {
  final _lib = LibraryService.instance;
  String? _email;
  int? _bookId;

  @override
  void initState() {
    super.initState();
    _email = widget.student?.email;
    _bookId = widget.book?.id;
  }

  Book? get _book {
    for (final b in _lib.books) {
      if (b.id == _bookId) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final students = AuthService.instance.borrowers;
    final student = _email == null ? null : _lib.studentByEmail(_email!);
    final book = _book;
    final problem =
        (student != null && book != null) ? _lib.eligibility(student, book) : null;
    final ready = student != null && book != null && problem == null;
    final due = DateTime.now().add(const Duration(days: LibraryService.loanDays));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Issue Book',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _email,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Student',
                  isDense: true,
                  border: OutlineInputBorder()),
              items: [
                for (final s in students)
                  DropdownMenuItem(
                    value: s.email,
                    child: Text('${s.fullName} · ${s.email}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _email = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              value: _bookId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Book',
                  isDense: true,
                  border: OutlineInputBorder()),
              items: [
                for (final b in _lib.books)
                  DropdownMenuItem(
                    value: b.id,
                    child: Text('${b.title} (${_lib.copiesLeft(b)} left)',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _bookId = v),
            ),
            const SizedBox(height: 14),
            if (student != null) ...[
              Text(
                  'Borrowing limit: ${_lib.activeLoansOf(student.email).length}/${LibraryService.maxActiveLoans} books',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
            ],
            if (problem != null)
              Text(problem,
                  style: const TextStyle(
                      color: Color(0xFFC0121F), fontWeight: FontWeight.w600))
            else if (ready)
              Text(
                'Eligible. Due date will be ${_fmt(due)} '
                '(${LibraryService.loanDays} days). '
                'Late fine: ₱${LibraryService.finePerDay.toStringAsFixed(0)}/day.',
                style: const TextStyle(
                    color: Color(0xFF0C7A43), fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: ready
                    ? () async {
                        final err = await _lib.checkOut(book, student);
                        if (!context.mounted) return;
                        Navigator.pop(
                          context,
                          err ??
                              'Issued "${book.title}" to ${student.fullName}. '
                                  'Due ${_fmt(due)}.',
                        );
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.amber,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm borrow'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Add / Edit form ----------

class _BookForm extends StatefulWidget {
  const _BookForm({this.book});
  final Book? book;

  @override
  State<_BookForm> createState() => _BookFormState();
}

class _BookFormState extends State<_BookForm> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final _title = TextEditingController(text: widget.book?.title);
  late final _author = TextEditingController(text: widget.book?.author);
  late final _publisher = TextEditingController(text: widget.book?.publisher);
  late final _desc = TextEditingController(text: widget.book?.description);
  late final _image = TextEditingController(text: widget.book?.imageUrl);
  late final _copies =
      TextEditingController(text: '${widget.book?.totalCopies ?? 1}');
  late final _isbn = TextEditingController(text: widget.book?.isbn);
  late final _pages = TextEditingController(
      text: widget.book?.pages == null ? '' : '${widget.book!.pages}');
  late final _shelf = TextEditingController(text: widget.book?.shelf);
  late final _dateCtl = TextEditingController(
      text: widget.book?.published == null ? '' : _fmt(widget.book!.published));

  String? _category;
  DateTime? _published;
  Uint8List? _bytes;
  String? _fileError;

  bool get _editing => widget.book != null;

  @override
  void initState() {
    super.initState();
    _category = _categories.contains(widget.book?.category)
        ? widget.book!.category
        : null;
    _published = widget.book?.published;
    _bytes = widget.book?.imageBytes;
  }

  @override
  void dispose() {
    for (final c in [
      _title, _author, _publisher, _desc, _image, _dateCtl, _copies,
      _isbn, _pages, _shelf,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _published ?? now,
      firstDate: DateTime(1000),
      lastDate: now,
    );
    if (d == null) return;
    setState(() => _published = d);
    _dateCtl.text = _fmt(d);
    _formKey.currentState?.validate();
  }

  Future<void> _browse() async {
    final f = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 240, imageQuality: 70);
    if (f == null) return;
    final data = await f.readAsBytes();
    if (data.length > 2 * 1024 * 1024) {
      setState(() => _fileError = 'Image must be 2 MB or smaller.');
      return;
    }
    setState(() {
      _bytes = data;
      _fileError = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final total = int.parse(_copies.text.trim());
    final borrowed =
        _editing ? LibraryService.instance.activeFor(widget.book!) : 0;
    if (total < borrowed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '$borrowed copies are currently borrowed. Total copies can\'t be lower than that.'),
      ));
      return;
    }
    final ok = await _confirmDialog(
        context,
        _editing ? 'Save Changes' : 'Add Book',
        _editing
            ? 'Save changes to "${_title.text.trim()}"?'
            : 'Add "${_title.text.trim()}" to the catalog?',
        _editing ? 'Yes, save' : 'Yes, add');
    if (!ok || !mounted) return;
    final base = widget.book ??
        Book(title: '', author: '', category: '', color: Palette.burgundy);
    Navigator.pop(
      context,
      base.copyWith(
        title: _title.text.trim(),
        author: _author.text.trim(),
        publisher: _publisher.text.trim(),
        category: _category,
        published: _published,
        totalCopies: total,
        copiesAvailable: total,
        isbn: _cleanIsbn(_isbn.text),
        pages: int.parse(_pages.text.trim()),
        shelf: _shelf.text.trim(),
        description: _desc.text.trim(),
        imageUrl: _bytes != null ? '' : _image.text.trim(),
        imageBytes: _bytes,
        clearImageBytes: _bytes == null,
      ),
    );
  }

  InputDecoration _dec(String label, {String? hint}) =>
      _fieldDec(label: label, hint: hint);

  @override
  Widget build(BuildContext context) {
    const auto = AutovalidateMode.onUserInteraction;
    final previewUrl =
        Validators.imageUrl(_image.text) == null ? _image.text.trim() : '';

    return Scaffold(
      backgroundColor: Palette.page,
      appBar: AppBar(
        backgroundColor: Palette.burgundy,
        foregroundColor: Palette.creamLight,
        title: Text(_editing ? 'Edit Book' : 'Add Book',
            style: const TextStyle(
                fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Section('Details', Icons.edit_note),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                decoration: _dec('Book Title', hint: 'Enter a Book Title'),
                validator: Validators.bookTitle,
                autovalidateMode: auto,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _author,
                decoration: _dec('Author Name', hint: 'Enter an Author Name'),
                validator: Validators.bookAuthor,
                autovalidateMode: auto,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _publisher,
                decoration: _dec('Publisher', hint: 'Enter a Publisher Name'),
                validator: Validators.publisher,
                autovalidateMode: auto,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _isbn,
                decoration: _dec('ISBN', hint: 'e.g. 978-0-547-92822-7'),
                validator: _validateIsbn,
                autovalidateMode: auto,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pages,
                keyboardType: TextInputType.number,
                decoration: _dec('Number of Pages', hint: 'e.g. 310'),
                validator: _validatePages,
                autovalidateMode: auto,
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 10),
              const _Section('Publication', Icons.event),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                isExpanded: true,
                decoration: _dec('Category', hint: 'Choose a Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                validator: Validators.category,
                autovalidateMode: auto,
                onChanged: (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _dateCtl,
                readOnly: true,
                onTap: _pickDate,
                decoration: _dec('Date Published').copyWith(
                    suffixIcon: const Icon(Icons.calendar_today, size: 18)),
                validator: (_) => Validators.publishedDate(_published),
                autovalidateMode: auto,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _copies,
                keyboardType: TextInputType.number,
                decoration: _dec('Total Copies', hint: 'e.g. 3'),
                validator: Validators.copies,
                autovalidateMode: auto,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _shelf,
                maxLength: 40,
                decoration: _dec('Shelf / Location (optional)',
                    hint: 'e.g. Aisle 3, Shelf B'),
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 10),
              const _Section('Description', Icons.notes),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                maxLines: 4,
                maxLength: 300,
                decoration: _dec('Description (optional)',
                    hint: 'Enter a short description...'),
                validator: _validateDescription,
                autovalidateMode: auto,
              ),
              const SizedBox(height: 10),
              const _Section('Cover', Icons.image_outlined),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _image,
                      enabled: _bytes == null,
                      decoration: _dec('Image Upload',
                              hint: _bytes != null ? 'Uploaded image' : 'Image Link')
                          .copyWith(errorText: _fileError),
                      validator: (v) =>
                          _bytes == null ? Validators.imageUrl(v) : null,
                      autovalidateMode: auto,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _bytes != null
                        ? () => setState(() {
                              _bytes = null;
                              _fileError = null;
                            })
                        : _browse,
                    child: Text(_bytes != null ? 'Remove' : 'Browse'),
                  ),
                ],
              ),
              if (_bytes != null || previewUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                _Cover(
                    url: previewUrl,
                    bytes: _bytes,
                    color: Colors.grey.shade300,
                    w: 40,
                    h: 58),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                          backgroundColor: Palette.amber,
                          foregroundColor: Colors.white),
                      child: Text(_editing ? 'Edit Book' : 'Add Book'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ---------- Bulk import ----------

const _csvTemplate = '''title,author,isbn,publisher,category,published,copies,pages,description,image,subcategory,shelf
The Hobbit,J.R.R. Tolkien,9780547928227,Allen & Unwin,Fiction,09/21/1937,3,310,A hobbit goes on an unexpected adventure.,,Fantasy,Aisle 1
A Brief History of Time,Stephen Hawking,9780553380163,Bantam Books,Non-Fiction,04/01/1988,2,212,An introduction to cosmology for general readers.,https://example.com/cover.jpg,Cosmology,Aisle 4
''';

/// Minimal CSV parser: handles quotes, commas and line breaks inside quotes.
List<List<String>> _parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  void endRow() {
    row.add(cell.toString());
    cell.clear();
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(c);
    }
  }
  endRow();
  return rows;
}

enum _RowStatus { newBook, update, duplicate, invalid }

(String, Color, IconData) _statusMeta(_RowStatus s) => switch (s) {
      _RowStatus.newBook =>
        ('New', const Color(0xFF0C7A43), Icons.add_circle_outline),
      _RowStatus.update => ('Update', const Color(0xFF0B4A8B), Icons.sync),
      _RowStatus.duplicate =>
        ('Duplicate', const Color(0xFF8A5A00), Icons.content_copy),
      _RowStatus.invalid =>
        ('Invalid', const Color(0xFFC0121F), Icons.error_outline),
    };

class _ImportRow {
  _ImportRow(this.line, this.label);
  final int line; // row number in the file (header = 1)
  final String label;
  Book? book; // data to save (new book, or merged update)
  final errors = <String>[];
  final changes = <String>[];
  String note = '';
  _RowStatus status = _RowStatus.invalid;
  bool get ok =>
      status == _RowStatus.newBook || status == _RowStatus.update;
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  static const _maxRows = 500;
  static const _required = [
    'title', 'author', 'isbn', 'publisher', 'category', 'published', 'pages',
  ];

  String? _fileName;
  String? _fileError;
  List<_ImportRow> _rows = [];

  _RowStatus? _view; // null = show all rows

  int _count(_RowStatus s) => _rows.where((r) => r.status == s).length;

  Future<void> _pick() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (res == null) return; // cancelled
      final file = res.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _fileError = 'Could not read that file.');
        return;
      }
      var text = utf8.decode(bytes, allowMalformed: true);
      if (text.startsWith('\uFEFF')) text = text.substring(1); // Excel BOM
      _process(file.name, text);
    } catch (_) {
      setState(() => _fileError = 'Could not open the file picker.');
    }
  }

  Future<void> _downloadTemplate() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // BOM so Excel reads the file as UTF-8.
      final bytes = Uint8List.fromList(
          [0xEF, 0xBB, 0xBF, ...utf8.encode(_csvTemplate)]);
      await downloadFile(bytes, 'books_import_template.csv', 'text/csv');
    } catch (e) {
      debugPrint('Template share failed: $e');
      messenger.showSnackBar(
          SnackBar(content: Text('Could not export the template: $e')));
    }
  }

  void _process(String name, String text) {
    final table = _parseCsv(text);
    if (table.length < 2) {
      setState(() {
        _fileName = name;
        _rows = [];
        _fileError = 'The file needs a header row and at least one book.';
      });
      return;
    }

    final head = <String, int>{};
    for (var i = 0; i < table.first.length; i++) {
      var h = table.first[i].trim().toLowerCase().replaceAll(' ', '');
      if (h == 'totalcopies' || h == 'numberofcopies') h = 'copies';
      if (h == 'imageurl' || h == 'imagelink') h = 'image';
      if (h == 'datepublished') h = 'published';
      if (h == 'numberofpages') h = 'pages';
      if (h == 'shelf/location' || h == 'location') h = 'shelf';
      head[h] = i;
    }
    final missing = _required.where((k) => !head.containsKey(k)).toList();
    if (missing.isNotEmpty) {
      setState(() {
        _fileName = name;
        _rows = [];
        _fileError = 'Missing column(s): ${missing.join(', ')}.';
      });
      return;
    }

    String cellOf(List<String> r, String key) {
      final i = head[key];
      return (i == null || i >= r.length) ? '' : r[i].trim();
    }

    String keyOf(String t, String a) => '${t.toLowerCase()}|${a.toLowerCase()}';
    String day(DateTime? d) =>
        d == null ? '' : d.toIso8601String().substring(0, 10);

    final lib = LibraryService.instance;
    final byIsbn = <String, Book>{};
    final byTitle = <String, Book>{};
    for (final b in lib.books) {
      final i = _cleanIsbn(b.isbn);
      if (i.isNotEmpty) byIsbn[i] = b;
      byTitle[keyOf(b.title, b.author)] = b;
    }
    final fileSeen = <String, int>{}; // key -> row number

    final out = <_ImportRow>[];
    final body = table.skip(1).take(_maxRows).toList();
    for (var i = 0; i < body.length; i++) {
      final r = body[i];
      final title = cellOf(r, 'title');
      final row = _ImportRow(i + 2, title.isEmpty ? '(no title)' : title);

      void check(String? e) {
        if (e != null) row.errors.add(e);
      }

      check(Validators.bookTitle(title));
      final author = cellOf(r, 'author');
      check(Validators.bookAuthor(author));
      final publisher = cellOf(r, 'publisher');
      check(Validators.publisher(publisher));

      final catRaw = cellOf(r, 'category');
      final category = _categories.firstWhere(
          (c) => c.toLowerCase() == catRaw.toLowerCase(),
          orElse: () => '');
      if (category.isEmpty) {
        row.errors.add('Category must be one of: ${_categories.join(', ')}.');
      }

      final pubRaw = cellOf(r, 'published');
      final published = _parseUsDate(pubRaw);
      check(Validators.publishedDate(published));
      if (published == null && pubRaw.isNotEmpty) {
        row.errors.add('Use the date format MM/DD/YYYY.');
      }

      final copiesRaw = cellOf(r, 'copies');
      final copies = copiesRaw.isEmpty ? '1' : copiesRaw;
      check(Validators.copies(copies));

      final desc = cellOf(r, 'description');
      check(_validateDescription(desc));
      final isbn = _cleanIsbn(cellOf(r, 'isbn'));
      check(_validateIsbn(isbn));
      final pagesRaw = cellOf(r, 'pages');
      check(_validatePages(pagesRaw));
      final shelf = cellOf(r, 'shelf');
      final image = cellOf(r, 'image');
      check(Validators.imageUrl(image));

      final sub = cellOf(r, 'subcategory');
      if (sub.length > 40) {
        row.errors.add('Subcategory must be 40 characters or fewer.');
      } else if (sub.isNotEmpty &&
          !RegExp(r"^[\p{L}\p{N}\s&'-]+$", unicode: true).hasMatch(sub)) {
        row.errors.add("Subcategory: use letters, numbers, spaces, & ' - only.");
      }

      // 1) Invalid
      if (row.errors.isNotEmpty) {
        row.status = _RowStatus.invalid;
        out.add(row);
        continue;
      }

      // 2) Repeated inside this file
      final tKey = keyOf(title, author);
      final prior = fileSeen[isbn] ?? fileSeen[tKey];
      if (prior != null) {
        row.status = _RowStatus.duplicate;
        row.note = 'Same book as row $prior in this file.';
        out.add(row);
        continue;
      }

      // 3) Match against the catalog (ISBN first, then title + author)
      final byI = byIsbn[isbn];
      final byT = byTitle[tKey];
      if (byI != null && byT != null && byI.id != byT.id) {
        row.errors.add(
            'The ISBN matches one catalog book but the title and author match another.');
        row.status = _RowStatus.invalid;
        out.add(row);
        continue;
      }
      final match = byI ?? byT;
      fileSeen[isbn] = row.line;
      fileSeen[tKey] = row.line;

      if (match == null) {
        final n = int.parse(copies);
        row.book = Book(
          title: title,
          author: author,
          publisher: publisher,
          category: category,
          subcategory: sub,
          color: Palette.burgundy,
          description: desc,
          published: published,
          totalCopies: n,
          copiesAvailable: n,
          imageUrl: image,
          isbn: isbn,
          pages: int.parse(pagesRaw),
          shelf: shelf,
        );
        row.status = _RowStatus.newBook;
        out.add(row);
        continue;
      }

      // 4) Existing book: update or identical (blank optional cells keep current values)
      final n = copiesRaw.isEmpty ? match.totalCopies : int.parse(copies);
      final borrowed = lib.activeFor(match);
      if (n < borrowed) {
        row.errors.add(
            '$borrowed copies are currently borrowed. Total copies can\'t be lower than that.');
        row.status = _RowStatus.invalid;
        out.add(row);
        continue;
      }
      final pages = int.parse(pagesRaw);
      final newSub = sub.isEmpty ? match.subcategory : sub;
      final newDesc = desc.isEmpty ? match.description : desc;
      final newShelf = shelf.isEmpty ? match.shelf : shelf;
      final imageChanged = image.isNotEmpty &&
          (image != match.imageUrl || match.imageBytes != null);

      row.changes.addAll([
        if (match.title != title) 'Title',
        if (match.author != author) 'Author',
        if (_cleanIsbn(match.isbn) != isbn) 'ISBN',
        if (match.publisher != publisher) 'Publisher',
        if (match.category != category) 'Category',
        if (match.subcategory != newSub) 'Subcategory',
        if (day(match.published) != day(published)) 'Published date',
        if (match.pages != pages) 'Pages',
        if (match.totalCopies != n) 'Copies',
        if (match.description != newDesc) 'Description',
        if (imageChanged) 'Image',
        if (match.shelf != newShelf) 'Shelf',
      ]);

      row.book = match.copyWith(
        title: title,
        author: author,
        publisher: publisher,
        category: category,
        subcategory: newSub,
        published: published,
        pages: pages,
        isbn: isbn,
        shelf: newShelf,
        description: newDesc,
        totalCopies: n,
        copiesAvailable: n,
        imageUrl: imageChanged ? image : null,
        clearImageBytes: imageChanged,
      );
      if (row.changes.isEmpty) {
        row.status = _RowStatus.duplicate;
        row.note = 'Already in the catalog with the same details.';
      } else {
        row.status = _RowStatus.update;
      }
      out.add(row);
    }

    setState(() {
      _fileName = name;
      _view = null;
      _fileError = table.length - 1 > _maxRows
          ? 'Only the first $_maxRows rows were read.'
          : null;
      _rows = out;
    });
  }

  Widget _rowTile(_ImportRow r) {
    final (label, color, _) = _statusMeta(r.status);
    final detail = switch (r.status) {
      _RowStatus.invalid => r.errors.join(' '),
      _RowStatus.update => 'Will change: ${r.changes.join(', ')}.',
      _RowStatus.duplicate => r.note,
      _RowStatus.newBook => 'Will be added to the catalog.',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(99)),
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Row ${r.line} · ${r.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(detail,
              style:
                  const TextStyle(fontSize: 12, color: Palette.textDark)),
        ],
      ),
    );
  }

  List<Widget> _resultsView() {
    final shown =
        (_view == null ? _rows : _rows.where((r) => r.status == _view))
            .toList();
    final add = _count(_RowStatus.newBook);
    final upd = _count(_RowStatus.update);
    final inv = _count(_RowStatus.invalid);
    final total = add + upd;

    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          for (final s in _RowStatus.values)
            GestureDetector(
              onTap: () => setState(() => _view = _view == s ? null : s),
              child: Opacity(
                opacity: _view == null || _view == s ? 1 : 0.45,
                child: _ResultTile(
                  label: _statusMeta(s).$1,
                  value: _count(s),
                  color: _statusMeta(s).$2,
                  icon: _statusMeta(s).$3,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      const Text('Tap a box to filter the list below.',
          style: TextStyle(fontSize: 12, color: Palette.textMuted)),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.burgundy.withAlpha(60)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final r in shown.take(50)) _rowTile(r),
            if (shown.length > 50)
              Text('...and ${shown.length - 50} more.',
                  style: const TextStyle(
                      fontSize: 12, color: Palette.textMuted)),
          ],
        ),
      ),
      if (inv > 0) ...[
        const SizedBox(height: 8),
        const Text('Fix the invalid rows and upload again to include them.',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC0121F))),
      ],
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: total == 0 ? null : _import,
          icon: const Icon(Icons.auto_stories),
          label: Text(total == 0
              ? 'Nothing to import'
              : 'Import ($add new, $upd updates)'),
          style: FilledButton.styleFrom(
            backgroundColor: Palette.burgundy,
            foregroundColor: Palette.creamLight,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: total == 0 ? Colors.transparent : Palette.amber,
                  width: 1.5),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _import() async {
    final fresh =
        _rows.where((r) => r.status == _RowStatus.newBook).toList();
    final upd = _rows.where((r) => r.status == _RowStatus.update).toList();
    final dups = _count(_RowStatus.duplicate);
    final inv = _count(_RowStatus.invalid);

    final ok = await _confirmDialog(
        context,
        'Import Books',
        'Add ${fresh.length} new and update ${upd.length} existing '
            '${upd.length == 1 ? 'book' : 'books'}? ${dups + inv} rows will be skipped.',
        'Yes, import');
    if (!ok || !mounted) return;

    final lib = LibraryService.instance;
    final added = await lib.addAll([for (final r in fresh) r.book!]);
    var updated = 0;
    var failed = fresh.length - added;
    for (final r in upd) {
      try {
        await lib.update(r.book!);
        updated++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      'Imported: $added added, $updated updated, $dups duplicates skipped, '
      '$inv invalid skipped${failed > 0 ? ', $failed failed' : ''}.',
    );
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- Header ----
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
          color: Palette.burgundy,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: Palette.cream, shape: BoxShape.circle),
                child: const Icon(Icons.library_add,
                    color: Palette.burgundy, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bulk Import',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Palette.creamLight,
                        )),
                    Text('Add many books at once from a CSV file',
                        style: TextStyle(
                            fontSize: 13, color: Palette.creamMuted)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                color: Palette.creamLight,
              ),
            ],
          ),
        ),
        Container(height: 3, color: Palette.amber),

        // ---- Body ----
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 1
                _StepCard(
                  step: 1,
                  title: 'Download the template',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'A ready-made .csv with the right columns and two '
                        'sample books. Open it in Excel or Google Sheets.',
                        style: TextStyle(
                            fontSize: 13, color: Palette.textMuted),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _downloadTemplate,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download template (.csv)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Palette.burgundy,
                            side: const BorderSide(
                                color: Palette.amber, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Step 2
                _StepCard(
                  step: 2,
                  title: 'Fill in your books',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'One book per row. Keep the first row (the headers) '
                        'exactly as it is. This is how it should look:',
                        style: TextStyle(
                            fontSize: 13, color: Palette.textMuted),
                      ),
                      const SizedBox(height: 10),
                      const _SamplePreview(),
                      const SizedBox(height: 16),
                      const Text('What goes in each column',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Palette.burgundy)),
                      const SizedBox(height: 8),
                      for (final g in _guide)
                        _GuideRow(
                          name: g.$1,
                          required: g.$2,
                          rule: g.$3,
                          example: g.$4,
                        ),
                      const SizedBox(height: 8),
                      const Text('Allowed categories',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Palette.burgundy)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in _categories)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Palette.cream,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                    color: Palette.burgundy.withAlpha(90)),
                              ),
                              child: Text(c,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Palette.burgundy,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const _TipBox(tips: [
                        'In Excel: File > Save As > "CSV (Comma delimited)".',
                        'If a value contains a comma, wrap it in "quotes".',
                        'Delete the two sample rows before importing real data.',
                                'Up to 500 rows per file. A row matching a catalog book (same ISBN, '
            'or same title and author) updates it. Identical rows are skipped '
            'as duplicates.',
                      ]),
                    ],
                  ),
                ),

                // Step 3
                _StepCard(
                  step: 3,
                  title: 'Upload your file',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _pick,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 22, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Palette.cream.withAlpha(120),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Palette.burgundy.withAlpha(110),
                                width: 1.4),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _fileName == null
                                    ? Icons.upload_file
                                    : Icons.description_outlined,
                                size: 34,
                                color: Palette.burgundy,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _fileName ?? 'Tap to choose a .csv file',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Palette.burgundy),
                              ),
                              if (_fileName != null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Text('Tap to choose a different file',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Palette.textMuted)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_fileError != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: Color(0xFFC0121F)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(_fileError!,
                                  style: const TextStyle(
                                      color: Color(0xFFC0121F),
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Results
                if (_rows.isNotEmpty) ..._resultsView(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Import sheet helpers ----------

// (column, required?, rule, example)
const _guide = <(String, bool, String, String)>[
  ('title', true, '2 to 100 characters', 'The Hobbit'),
  ('author', true, 'Letters only, up to 60', 'J.R.R. Tolkien'),
  ('isbn', true, '10 or 13 digits (used to match existing books)', '9780547928227'),
  ('publisher', true, 'Up to 60 characters', 'Allen & Unwin'),
  ('category', true, 'Pick from the list below', 'Fiction'),
  ('published', true, 'MM/DD/YYYY, not in the future', '09/21/1937'),
  ('pages', true, 'Whole number 1 to 10000', '310'),
  ('description', false, '10 to 300 characters (blank keeps current)', 'A hobbit goes on an adventure.'),
  ('copies', false, 'Whole number 1 to 99 (blank = 1, or current)', '3'),
  ('image', false, 'Link starting with https:// (blank keeps current)', 'https://site.com/cover.jpg'),
  ('subcategory', false, 'Up to 40 characters (blank keeps current)', 'Fantasy'),
  ('shelf', false, 'Up to 40 characters (blank keeps current)', 'Aisle 3, Shelf B'),
];

class _StepCard extends StatelessWidget {
  const _StepCard(
      {required this.step, required this.title, required this.child});
  final int step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Palette.card,
      shape: _cardShape,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Palette.burgundy,
                  child: Text('$step',
                      style: const TextStyle(
                          color: Palette.creamLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Palette.burgundy,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.name,
    required this.required,
    required this.rule,
    required this.example,
  });
  final String name;
  final bool required;
  final String rule;
  final String example;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Palette.burgundy,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Palette.creamLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(rule,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text(required ? 'Required' : 'Optional',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: required
                                ? const Color(0xFFC0121F)
                                : Palette.textMuted)),
                  ],
                ),
                Text('e.g. $example',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Palette.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SamplePreview extends StatelessWidget {
  const _SamplePreview();

  static const _head = [
    'title', 'author', 'isbn', 'publisher', 'category', 'published',
    'copies', 'pages', 'description', 'image', 'subcategory', 'shelf',
  ];
  static const _rows = [
    [
      'The Hobbit', 'J.R.R. Tolkien', '9780547928227', 'Allen & Unwin',
      'Fiction', '09/21/1937', '3', '310', 'A hobbit goes on...', '',
      'Fantasy', 'Aisle 1',
    ],
    [
      'A Brief History of Time', 'Stephen Hawking', '9780553380163',
      'Bantam Books', 'Non-Fiction', '04/01/1988', '2', '212',
      'An intro to cosmology...', 'https://...', 'Cosmology', 'Aisle 4',
    ],
  ];

  Widget _cell(String t, {bool head = false}) => Container(
        width: 118,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Text(t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: head ? FontWeight.w700 : FontWeight.w500,
              color: head ? Palette.creamLight : Palette.textDark,
            )),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Palette.burgundy.withAlpha(80)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              Container(
                color: Palette.burgundy,
                child: Row(children: [
                  for (final h in _head) _cell(h, head: true),
                ]),
              ),
              for (var i = 0; i < _rows.length; i++)
                Container(
                  color: i.isEven
                      ? Palette.cream.withAlpha(110)
                      : Colors.white,
                  child: Row(children: [
                    for (final c in _rows[i]) _cell(c),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox({required this.tips});
  final List<String> tips;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.amber.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.amber.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline,
                      size: 16, color: Palette.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t, style: const TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: color)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Borrowing activity chart ----------

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _BorrowChart extends StatelessWidget {
  const _BorrowChart({required this.transactions, this.requests = const []});
  final List<BookTransaction> transactions;
  final List<LoanRequest> requests;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool sameDay(DateTime? x, DateTime d) =>
        x != null && x.year == d.year && x.month == d.month && x.day == d.day;

    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return (
        label: '${_weekdays[d.weekday - 1]} ${d.day}',
        borrowed: transactions.where((t) => sameDay(t.borrowedOn, d)).length,
        returned: transactions.where((t) => sameDay(t.returnedOn, d)).length,
        pending: requests.where((r) => sameDay(r.requestedOn, d)).length,
        overdue: transactions
            .where((t) => sameDay(t.due, d) && (t.overdue || t.fine > 0))
            .length,
      );
    });

    final borrowed = [for (final d in days) d.borrowed.toDouble()];
    final returned = [for (final d in days) d.returned.toDouble()];
    final pending = [for (final d in days) d.pending.toDouble()];
    final overdue = [for (final d in days) d.overdue.toDouble()];
    double sum(List<double> l) => l.fold(0, (s, v) => s + v);

    const cBorrowed = Color(0xFF433429);
    const cReturned = Color(0xFF0C7A43);
    const cPending = Color(0xFFEAB308);
    const cOverdue = Color(0xFFC0121F);

    final maxY = math.max(
        [...borrowed, ...returned, ...pending, ...overdue].reduce(math.max),
        1.0);

    Widget stat(String label, double v, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: c)),
                Text('${v.toInt()}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B1B1B))),
              ],
            ),
          ),
        );

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: _tableCardShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              stat('Borrowed', sum(borrowed), cBorrowed),
              stat('Returned', sum(returned), cReturned),
              stat('Pending', sum(pending), cPending),
              stat('Overdue', sum(overdue), cOverdue),
            ]),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Text('Last 7 days',
                  style: TextStyle(fontSize: 12, color: Palette.textMuted)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 170,
              child: CustomPaint(
                size: Size.infinite,
                painter: _MultiLinePainter(
                  [borrowed, returned, pending, overdue],
                  const [cBorrowed, cReturned, cPending, cOverdue],
                  maxY,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: Text(d.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 9.5, color: Palette.textMuted)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MultiLinePainter extends CustomPainter {
  _MultiLinePainter(this.series, this.colors, this.maxY);
  final List<List<double>> series;
  final List<Color> colors;
  final double maxY;

  @override
  void paint(Canvas canvas, Size size) {
    const padY = 8.0;
    final h = size.height - padY * 2;
    double yOf(double v) => padY + h - (v / maxY) * h;

    final grid = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = padY + h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (var s = 0; s < series.length; s++) {
      final v = series[s];
      final n = v.length;
      double xOf(int i) =>
          n == 1 ? size.width / 2 : (i + 0.5) / n * size.width;

      final line = Path();
      for (var i = 0; i < n; i++) {
        final p = Offset(xOf(i), yOf(v[i]));
        i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
      }
      final fill = Path.from(line)
        ..lineTo(xOf(n - 1), padY + h)
        ..lineTo(xOf(0), padY + h)
        ..close();
      canvas.drawPath(fill, Paint()..color = colors[s].withAlpha(22));
      canvas.drawPath(
          line,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeJoin = StrokeJoin.round
            ..color = colors[s]);
      for (var i = 0; i < n; i++) {
        canvas.drawCircle(
            Offset(xOf(i), yOf(v[i])), 3, Paint()..color = colors[s]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MultiLinePainter old) => true;
}

// ---------- Desk widgets ----------

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.card,
      shape: _cardShape,
      child: InkWell(
        onTap: onTap,
        customBorder: _cardShape,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Palette.burgundy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Palette.amber, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Palette.burgundy,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800)),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Palette.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: Palette.burgundy.withAlpha(100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withAlpha(13)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.2,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: Color(0xB31B1B1B))),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 18, color: Palette.burgundy.withAlpha(150)),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1B1B),
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.cream.withAlpha(110),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.burgundy.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0C7A43)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.tx});
  final BookTransaction tx;

  @override
  Widget build(BuildContext context) {
    final t = tx;
    final color = t.overdue
        ? const Color(0xFFC0121F)
        : t.returned
            ? const Color(0xFF0C7A43)
            : Palette.amber;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withAlpha(30),
        child: Icon(
          t.returned ? Icons.assignment_return_outlined : Icons.north_east,
          size: 18,
          color: color,
        ),
      ),
      title: Text(t.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        '${t.borrower} · ${t.returned ? 'Returned ${_fmt(t.returnedOn)}' : 'Borrowed ${_fmt(t.borrowedOn)}'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}


class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onDecline,
    this.busy = false,
  });
  final LoanRequest request;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Card(
      elevation: 0,
      color: Palette.card,
      shape: _cardShape,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${r.borrower} (${r.borrowerEmail})',
                style: const TextStyle(fontSize: 13)),
            Text('Requested ${_fmt(r.requestedOn)}',
                style:
                    const TextStyle(fontSize: 12, color: Palette.textMuted)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC0121F),
                      side: const BorderSide(color: Color(0xFFC0121F)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.burgundy,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Decline reason dialog ----------

class _DeclineDialog extends StatefulWidget {
  const _DeclineDialog({required this.request});
  final LoanRequest request;

  @override
  State<_DeclineDialog> createState() => _DeclineDialogState();
}

class _DeclineDialogState extends State<_DeclineDialog> {
  final _reason = TextEditingController();
  final _key = GlobalKey<FormState>();
  String? _choice;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return AlertDialog(
      title: const Text('Decline Request'),
      content: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Decline "${r.book.title}" requested by ${r.borrower}? '
                'The reason will be shown to the borrower.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _choice,
                isExpanded: true,
                decoration: _fieldDec(label: 'Reason for declining'),
                items: [
                  for (final r in _declineReasons)
                    DropdownMenuItem(
                      value: r,
                      child: Text(r, overflow: TextOverflow.ellipsis),
                    ),
                ],
                validator: (v) => v == null ? 'Choose a reason.' : null,
                onChanged: (v) => setState(() => _choice = v),
              ),
              if (_choice == _otherReason) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reason,
                  autofocus: true,
                  maxLines: 4,
                  maxLength: 300,
                  decoration: _fieldDec(
                      label: 'Details',
                      hint: 'Write the reason for the borrower.'),
                  validator: (v) => (v ?? '').trim().length < 5
                      ? 'Please enter a reason (at least 5 characters).'
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_key.currentState!.validate()) {
              Navigator.pop(
                  context,
                  _choice == _otherReason ? _reason.text.trim() : _choice);
            }
          },
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC0121F)),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}

// ---------- Borrow requests page ----------

class _RequestsBanner extends StatelessWidget {
  const _RequestsBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.amber.withAlpha(30),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.amber.withAlpha(120)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Palette.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        count == 1
                            ? '1 request waiting for approval'
                            : '$count requests waiting for approval',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Text('Tap to approve or decline',
                        style: TextStyle(
                            fontSize: 12, color: Palette.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Palette.burgundy),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsScreen extends StatefulWidget {
  const _RequestsScreen();

  @override
  State<_RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<_RequestsScreen> {
  static const _size = 5;
  final _lib = LibraryService.instance;
  final Set<int> _busy = {};
  int _page = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _lib.reload();
  }

  Future<void> _decide(LoanRequest r, bool approve) async {
    if (_busy.contains(r.id)) return;

    var reason = '';
    if (approve) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Approve Request'),
          content: Text(
              'Are you sure you want to approve "${r.book.title}" for ${r.borrower}? '
              'The loan starts today and is due in ${LibraryService.loanDays} days.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style:
                  FilledButton.styleFrom(backgroundColor: Palette.burgundy),
              child: const Text('Yes, approve'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    } else {
      final text = await showDialog<String>(
        context: context,
        builder: (_) => _DeclineDialog(request: r),
      );
      if (text == null) return;
      reason = text;
    }
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(r.id));
    final err = approve
        ? await _lib.approveRequest(r.id)
        : await _lib.declineRequest(r.id, reason);
    if (mounted) setState(() => _busy.remove(r.id));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(err ??
            (approve
                ? 'Approved "${r.book.title}" for ${r.borrower}.'
                : 'Declined the request for "${r.book.title}".')),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.page,
      appBar: AppBar(
        backgroundColor: Palette.burgundy,
        foregroundColor: Palette.creamLight,
        title: const Text('Borrow Requests',
            style:
                TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
      ),
      body: ListenableBuilder(
        listenable: _lib,
        builder: (context, _) {
          final all = _lib.pendingRequests;
          final q = _query.trim().toLowerCase();
          final reqs = q.isEmpty
              ? all
              : all
                  .where((r) =>
                      r.book.title.toLowerCase().contains(q) ||
                      r.borrower.toLowerCase().contains(q) ||
                      r.borrowerEmail.toLowerCase().contains(q))
                  .toList();
          final pages = (reqs.length / _size).ceil();
          final page = pages <= 1 ? 0 : _page.clamp(0, pages - 1);
          final start = page * _size;
          final end = (start + _size).clamp(0, reqs.length);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              Text(
                all.isEmpty
                    ? 'No requests waiting for approval.'
                    : q.isEmpty
                        ? '${all.length} ${all.length == 1 ? 'request' : 'requests'} waiting for approval'
                        : '${reqs.length} of ${all.length} requests match',
                style: const TextStyle(color: Palette.textMuted),
              ),
              const SizedBox(height: 14),
              if (all.isNotEmpty) ...[
                TextField(
                  onChanged: (v) => setState(() {
                    _query = v;
                    _page = 0;
                  }),
                  decoration: _fieldDec(
                      hint: 'Search by book, name, or email',
                      prefix: const Icon(Icons.search)),
                ),
                const SizedBox(height: 14),
              ],
              if (all.isEmpty)
                const _EmptyNote(
                    icon: Icons.verified_outlined,
                    text: 'You\'re all caught up.')
              else if (reqs.isEmpty)
                const _EmptyNote(
                    icon: Icons.search_off,
                    text: 'No requests match your search.')
              else ...[
                for (final r in reqs.sublist(start, end))
                  _RequestCard(
                    request: r,
                    busy: _busy.contains(r.id),
                    onApprove: () => _decide(r, true),
                    onDecline: () => _decide(r, false),
                  ),
                _Pager(
                  page: page,
                  total: reqs.length,
                  pageSize: _size,
                  onChanged: (p) => setState(() => _page = p),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------- Analytics (Overview) ----------

const _shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _chartColors = [
  Color(0xFF55161D), Color(0xFFEEA51C), Color(0xFF0C7A43), Color(0xFF0B4A8B),
  Color(0xFFC0121F), Color(0xFF7C3AED), Color(0xFF0E7490), Color(0xFF9CA3AF),
];

class _AnRec {
  _AnRec(this.date, this.bookId, this.title, this.category, this.sub,
      this.email, this.dept, this.faculty);
  final DateTime date;
  final int bookId;
  final String title, category, sub, email, dept;
  final bool faculty;
}

class _ChartRow {
  _ChartRow(this.label, this.value, [this.sub = '']);
  final String label;
  final double value;
  final String sub;
}

List<_ChartRow> _tally(Iterable<_AnRec> list, String Function(_AnRec) key) {
  final m = <String, int>{};
  for (final r in list) {
    final k = key(r);
    if (k.isNotEmpty) m[k] = (m[k] ?? 0) + 1;
  }
  final out = [for (final e in m.entries) _ChartRow(e.key, e.value.toDouble())];
  out.sort((a, b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.label.compareTo(b.label);
  });
  return out;
}

String _deptOf(AppUser? u) {
  if (u == null) return 'Unassigned';
  final d = (_isFaculty(u) ? u.department : u.course).trim();
  return d.isEmpty ? 'Unassigned' : d;
}

String _dayLabel(DateTime d) => '${_shortMonths[d.month - 1]} ${d.day}';

class _Bucket {
  _Bucket(this.start, this.end, this.label);
  final DateTime start, end;
  final String label;
}

class _AnalyticsSection extends StatefulWidget {
  const _AnalyticsSection();

  @override
  State<_AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<_AnalyticsSection> {
  static const _ranges = {
    'day': 'Today',
    'week': 'Last 7 days',
    'month': 'Last 30 days',
    'year': 'Last 12 months',
    'custom': 'Custom',
  };

  String _range = 'month';
  DateTimeRange? _custom;
  String _bookTop = '5', _bookCat = 'All', _bookSub = 'All';
  String _subTop = '5', _subCat = 'All';
  String _trendCat = 'All', _trendDept = 'All';
  String _deptCat = 'All';
  String _role = 'all';

  DateTime _d(DateTime x) => DateTime(x.year, x.month, x.day);

  (DateTime, DateTime) _resolve() {
    final today = _d(DateTime.now());
    switch (_range) {
      case 'week':
        return (today.subtract(const Duration(days: 6)), today);
      case 'month':
        return (today.subtract(const Duration(days: 29)), today);
      case 'year':
        return (today.subtract(const Duration(days: 364)), today);
      case 'custom':
        final c = _custom;
        return c == null
            ? (today.subtract(const Duration(days: 29)), today)
            : (_d(c.start), _d(c.end));
      default:
        return (today, today);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _custom ??
          DateTimeRange(
              start: now.subtract(const Duration(days: 29)), end: now),
    );
    if (r != null) setState(() => _custom = r);
  }

  (List<_Bucket>, String) _buckets(DateTime start, DateTime end) {
    final span = end.difference(start).inDays + 1;
    final out = <_Bucket>[];
    if (span <= 31) {
      for (var i = 0; i < span; i++) {
        final d = start.add(Duration(days: i));
        out.add(_Bucket(d, d, _dayLabel(d)));
      }
      return (out, 'Daily');
    }
    if (span <= 120) {
      for (var s = start; !s.isAfter(end); s = s.add(const Duration(days: 7))) {
        final e = s.add(const Duration(days: 6));
        out.add(_Bucket(s, e.isAfter(end) ? end : e, _dayLabel(s)));
      }
      return (out, 'Weekly');
    }
    var y = start.year, m = start.month;
    for (var guard = 0; guard < 240; guard++) {
      final first = DateTime(y, m, 1);
      if (first.isAfter(end)) break;
      final last = DateTime(y, m + 1, 0);
      out.add(_Bucket(first.isBefore(start) ? start : first,
          last.isAfter(end) ? end : last,
          "${_shortMonths[m - 1]} '${y % 100}"));
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return (out, 'Monthly');
  }

  @override
  Widget build(BuildContext context) {
    final lib = LibraryService.instance;
    final books = lib.books;
    final students = AuthService.instance.borrowers;
    final booksById = {for (final b in books) b.id: b};
    final usersByEmail = {for (final s in students) s.email: s};

    final (start, end) = _resolve();

    final all = <_AnRec>[];
    for (final t in lib.transactions) {
      final on = t.borrowedOn;
      if (on == null) continue;
      final b = booksById[t.bookId];
      final u = usersByEmail[t.borrowerEmail];
      all.add(_AnRec(
        _d(on),
        t.bookId,
        t.title,
        (b?.category.isNotEmpty ?? false) ? b!.category : 'Uncategorized',
        b?.subcategory ?? '',
        t.borrowerEmail,
        _deptOf(u),
        u != null && _isFaculty(u),
      ));
    }
    final scoped = all
        .where((r) => !r.date.isBefore(start) && !r.date.isAfter(end))
        .toList();

    List<String> subsOf(String cat) => {
          for (final b in books)
            if ((cat == 'All' || b.category == cat) && b.subcategory.isNotEmpty)
              b.subcategory
        }.toList()
          ..sort();
    final allDepts = {for (final r in all) r.dept}.toList()..sort();

    // 1. Top borrowed books
    final topBooks = _tally(
        scoped.where((r) =>
            (_bookCat == 'All' || r.category == _bookCat) &&
            (_bookSub == 'All' || r.sub == _bookSub)),
        (r) => r.title).take(int.parse(_bookTop)).toList();

    // 2. Category
    final byCategory = _tally(scoped, (r) => r.category);

    // 3. Subcategory
    final bySub = _tally(
        scoped.where((r) => _subCat == 'All' || r.category == _subCat),
        (r) => r.sub).take(int.parse(_subTop)).toList();

    // 4. Trend
    final (buckets, unit) = _buckets(start, end);
    final trendRows = scoped.where((r) =>
        (_trendCat == 'All' || r.category == _trendCat) &&
        (_trendDept == 'All' || r.dept == _trendDept));
    final trendValues = [
      for (final b in buckets)
        trendRows
            .where((r) => !r.date.isBefore(b.start) && !r.date.isAfter(b.end))
            .length
            .toDouble()
    ];
    final trendTotal = trendValues.fold<double>(0, (s, v) => s + v);

    // 5. Department borrowing
    final byDept = _tally(
        scoped.where((r) => _deptCat == 'All' || r.category == _deptCat),
        (r) => r.dept);

    // 6. Unique borrowers by department
    final uniq = <String, Set<String>>{};
    for (final r in scoped) {
      uniq.putIfAbsent(r.dept, () => {}).add(r.email);
    }
    final uniqueByDept = [
      for (final e in uniq.entries)
        _ChartRow(e.key, e.value.length.toDouble())
    ]..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.label.compareTo(b.label);
      });

    // 7. Engagement
    bool roleOk(bool faculty) =>
        _role == 'all' || (_role == 'faculty') == faculty;
    final eligible = <String, int>{};
    for (final s in students) {
      if (!roleOk(_isFaculty(s))) continue;
      final d = _deptOf(s);
      if (d != 'Unassigned') eligible[d] = (eligible[d] ?? 0) + 1;
    }
    final borrowersIn = <String, Set<String>>{};
    for (final r in scoped.where((r) => roleOk(r.faculty))) {
      borrowersIn.putIfAbsent(r.dept, () => {}).add(r.email);
    }
    final engagement = [
      for (final e in eligible.entries)
        () {
          final b = borrowersIn[e.key]?.length ?? 0;
          return _ChartRow(e.key, (b / e.value * 1000).round() / 10,
              '($b of ${e.value})');
        }()
    ]..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.label.compareTo(b.label);
      });

    final kpis = [
      ('Borrowing transactions', scoped.length),
      ('Unique borrowers', {for (final r in scoped) r.email}.length),
      ('Different books borrowed', {for (final r in scoped) r.bookId}.length),
    ];

    final rangeText = start == end
        ? _fmt(start)
        : '${_fmt(start)} to ${_fmt(end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rangeText,
            style: const TextStyle(color: Palette.textMuted, fontSize: 13)),
        const SizedBox(height: 10),

        // Date range pills
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Palette.cream.withAlpha(110),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.burgundy.withAlpha(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final e in _ranges.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _range == e.key,
                      showCheckmark: false,
                      backgroundColor: Colors.white,
                      selectedColor: Palette.burgundy,
                      side: BorderSide(
                          color: Palette.burgundy
                              .withAlpha(_range == e.key ? 255 : 70)),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            _range == e.key ? Colors.white : Palette.burgundy,
                      ),
                      onSelected: (_) {
                        setState(() => _range = e.key);
                        if (e.key == 'custom' && _custom == null) _pickRange();
                      },
                    ),
                ],
              ),
              if (_range == 'custom')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: const Text('Change dates'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.burgundy),
                  ),
                ),
              const SizedBox(height: 6),
              const Text(
                  'The date range applies to every chart below and uses the borrow date.',
                  style: TextStyle(fontSize: 11.5, color: Palette.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // KPIs
        for (final k in kpis)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE4F1EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withAlpha(13)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(k.$1.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: Color(0xB31B1B1B))),
                ),
                Text('${k.$2}',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        const SizedBox(height: 6),

        _ChartCard(
          title: 'Borrowing Trends Over Time',
          purpose:
              '$unit borrowing transactions. Shows patterns, seasonal demand and busy periods.',
          controls: [
            _MiniSelect(
              value: _trendCat,
              items: {'All': 'All categories', for (final c in _categories) c: c},
              onChanged: (v) => setState(() => _trendCat = v),
            ),
            _MiniSelect(
              value: _trendDept,
              items: {'All': 'All departments', for (final d in allDepts) d: d},
              onChanged: (v) => setState(() => _trendDept = v),
            ),
          ],
          child: trendTotal == 0
              ? const _EmptyChart()
              : _TrendLine(
                  labels: [for (final b in buckets) b.label],
                  values: trendValues),
        ),

        _ChartCard(
          title: 'Top Borrowed Books',
          purpose: 'Popular titles. Helps decide which books need more copies.',
          controls: [
            _MiniSelect(
              value: _bookCat,
              items: {'All': 'All categories', for (final c in _categories) c: c},
              onChanged: (v) => setState(() {
                _bookCat = v;
                _bookSub = 'All';
              }),
            ),
            _MiniSelect(
              value: subsOf(_bookCat).contains(_bookSub) ? _bookSub : 'All',
              items: {
                'All': 'All subcategories',
                for (final s in subsOf(_bookCat)) s: s
              },
              onChanged: (v) => setState(() => _bookSub = v),
            ),
            _MiniSelect(
              value: _bookTop,
              items: const {'5': 'Top 5', '10': 'Top 10'},
              onChanged: (v) => setState(() => _bookTop = v),
            ),
          ],
          child: _HBars(rows: topBooks, color: Palette.burgundy),
        ),

        _ChartCard(
          title: 'Borrowing by Category',
          purpose:
              'Most borrowed subject areas, highest to lowest. Guides collection development.',
          child: _Donut(rows: byCategory),
        ),

        _ChartCard(
          title: 'Borrowing by Subcategory',
          purpose:
              'Specific subjects in high demand. Books without a subcategory are not counted.',
          controls: [
            _MiniSelect(
              value: _subCat,
              items: {'All': 'All categories', for (final c in _categories) c: c},
              onChanged: (v) => setState(() => _subCat = v),
            ),
            _MiniSelect(
              value: _subTop,
              items: const {'5': 'Top 5', '10': 'Top 10'},
              onChanged: (v) => setState(() => _subTop = v),
            ),
          ],
          child: _HBars(rows: bySub, color: Palette.amber),
        ),

        _ChartCard(
          title: 'Borrowing by Academic Department',
          purpose: 'Which departments generate the most borrowing transactions.',
          controls: [
            _MiniSelect(
              value: _deptCat,
              items: {'All': 'All categories', for (final c in _categories) c: c},
              onChanged: (v) => setState(() => _deptCat = v),
            ),
          ],
          child: _Donut(rows: byDept),
        ),

        _ChartCard(
          title: 'Unique Borrowers by Department',
          purpose:
              'Distinct people who borrowed at least once. Repeat loans count once.',
          child: _VBars(rows: uniqueByDept, color: const Color(0xFF0C7A43)),
        ),

        _ChartCard(
          title: 'Borrowing Engagement by Department',
          purpose:
              'Share of registered users in each department who borrowed at least one book.',
          controls: [
            _MiniSelect(
              value: _role,
              items: const {
                'all': 'All users',
                'student': 'Students',
                'faculty': 'Faculty'
              },
              onChanged: (v) => setState(() => _role = v),
            ),
          ],
          child: _VBars(
            rows: engagement,
            color: Palette.burgundy,
            suffix: '%',
            fixedMax: 100,
            empty: 'No registered users with a department match these filters.',
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.purpose,
    required this.child,
    this.controls = const [],
  });
  final String title, purpose;
  final List<Widget> controls;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: _cardShape,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Palette.burgundy)),
            const SizedBox(height: 2),
            Text(purpose,
                style:
                    const TextStyle(fontSize: 12, color: Palette.textMuted)),
            if (controls.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: controls),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _MiniSelect extends StatelessWidget {
  const _MiniSelect(
      {required this.value, required this.items, required this.onChanged});
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      constraints: const BoxConstraints(minWidth: 100, maxWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.burgundy.withAlpha(60)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.containsKey(value) ? value : items.keys.first,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(fontSize: 12.5, color: Palette.textDark),
          items: [
            for (final e in items.entries)
              DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart([this.text]);
  final String? text;

  @override
  Widget build(BuildContext context) => Container(
        height: 120,
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Palette.cream.withAlpha(110),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
            text ?? 'No borrowing records match the selected filters.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Palette.textMuted, fontSize: 13)),
      );
}

String _cut(String s, int n) => s.length > n ? '${s.substring(0, n - 1)}…' : s;

String _num(double v, String suffix) =>
    '${v == v.roundToDouble() ? v.toInt() : v}$suffix';

// Horizontal bars
class _HBars extends StatelessWidget {
  const _HBars({required this.rows, required this.color});
  final List<_ChartRow> rows;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _EmptyChart();
    final top = rows.map((r) => r.value).reduce(math.max);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(_cut(r.label, 20),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Palette.textDark)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Palette.cream.withAlpha(150),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (r.value / (top * 1.1)).clamp(0.03, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            color.withAlpha(140),
                            color,
                          ]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  child: Text(_num(r.value, ''),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Palette.burgundy)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// Vertical bars (scrolls sideways when there are many)
class _VBars extends StatelessWidget {
  const _VBars({
    required this.rows,
    required this.color,
    this.suffix = '',
    this.fixedMax,
    this.empty,
  });
  final List<_ChartRow> rows;
  final Color color;
  final String suffix;
  final double? fixedMax;
  final String? empty;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return _EmptyChart(empty);
    final top = fixedMax ?? rows.map((r) => r.value).reduce(math.max) * 1.1;
    const chartH = 150.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final r in rows)
            SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(_num(r.value, suffix),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Palette.burgundy)),
                  const SizedBox(height: 3),
                  Container(
                    width: 30,
                    height: top <= 0
                        ? 3
                        : (r.value / top * chartH).clamp(3, chartH).toDouble(),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [color, color.withAlpha(140)],
                      ),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 44,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(_cut(r.label, 18),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10.5, color: Palette.textMuted)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Doughnut with total in the center and a legend
class _Donut extends StatelessWidget {
  const _Donut({required this.rows});
  final List<_ChartRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _EmptyChart();
    const maxSlices = 7;
    final data = rows.length > maxSlices
        ? [
            ...rows.take(maxSlices),
            _ChartRow('Others',
                rows.skip(maxSlices).fold<double>(0, (s, r) => s + r.value)),
          ]
        : rows;
    final total = data.fold<double>(0, (s, r) => s + r.value);

    return Column(
      children: [
        SizedBox(
          height: 190,
          width: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(190, 190),
                painter: _DonutPainter(
                    [for (final r in data) r.value], _chartColors),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_num(total, ''),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Palette.burgundy)),
                  const Text('TRANSACTIONS',
                      style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: Palette.textMuted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < data.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Palette.cream.withAlpha(110),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: _chartColors[i % _chartColors.length],
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(data[i].label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                Text(_num(data[i].value, ''),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Palette.burgundy)),
                SizedBox(
                  width: 42,
                  child: Text('${(data[i].value / total * 100).round()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12, color: Palette.textMuted)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors);
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return;
    final stroke = size.width * 0.17;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final gap = values.length > 1 ? 0.05 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = colors[i % colors.length];
      canvas.drawArc(rect, start + gap / 2, math.max(sweep - gap, 0.01),
          false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors;
}

// Line chart with average line
class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.labels, required this.values});
  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxY = math.max(values.reduce(math.max), 1.0);
    final avg = values.fold<double>(0, (s, v) => s + v) / values.length;
    final mid = labels[labels.length ~/ 2];

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 24,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_num(maxY, ''),
                        style: const TextStyle(
                            fontSize: 10, color: Palette.textMuted)),
                    const Text('0',
                        style: TextStyle(
                            fontSize: 10, color: Palette.textMuted)),
                  ],
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _LinePainter(values, maxY, avg),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(labels.first,
                  style:
                      const TextStyle(fontSize: 10, color: Palette.textMuted)),
              if (labels.length > 2)
                Text(mid,
                    style: const TextStyle(
                        fontSize: 10, color: Palette.textMuted)),
              if (labels.length > 1)
                Text(labels.last,
                    style: const TextStyle(
                        fontSize: 10, color: Palette.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 16, height: 3, color: Palette.burgundy),
            const SizedBox(width: 6),
            const Text('Borrowings',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            const SizedBox(width: 16),
            Container(width: 16, height: 3, color: const Color(0xFF7C3AED)),
            const SizedBox(width: 6),
            Text('Average (${avg.toStringAsFixed(1)})',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.maxY, this.avg);
  final List<double> values;
  final double maxY, avg;

  @override
  void paint(Canvas canvas, Size size) {
    const padY = 8.0;
    final h = size.height - padY * 2;
    double yOf(double v) => padY + h - (v / maxY) * h;
    double xOf(int i) => values.length == 1
        ? size.width / 2
        : i / (values.length - 1) * size.width;

    final grid = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = padY + h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // dashed average line
    final avgPaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..strokeWidth = 1.5;
    final ay = yOf(avg);
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(
          Offset(x, ay), Offset(math.min(x + 5, size.width), ay), avgPaint);
    }

    // line
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = Offset(xOf(i), yOf(values[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round
          ..color = Palette.burgundy);

    // dots
    if (values.length <= 31) {
      for (var i = 0; i < values.length; i++) {
        final p = Offset(xOf(i), yOf(values[i]));
        canvas.drawCircle(p, 3.5, Paint()..color = Colors.white);
        canvas.drawCircle(
            p,
            3.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Palette.burgundy);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.maxY != maxY || old.avg != avg;
}