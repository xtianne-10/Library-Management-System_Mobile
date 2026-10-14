import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
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
  const _Section(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: Palette.amber, size: 22),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Georgia',
                    color: Palette.burgundy,
                  )),
          const SizedBox(width: 12),
          Expanded(
              child: Divider(color: Palette.amber.withAlpha(120), thickness: 1)),
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
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
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
            q.isEmpty ||
            b.title.toLowerCase().contains(q) ||
            b.author.toLowerCase().contains(q))
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
      Row(
        children: [
          Expanded(
              child: _QuickAction(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Borrowing',
                  onTap: () => _openIssue())),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickAction(
                  icon: Icons.assignment_return_outlined,
                  label: 'Returns',
                  badge: _lib.transactions.where((t) => t.pendingReturn).length,
                  onTap: _openVerifyReturn)),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickAction(
                  icon: Icons.menu_book_outlined,
                  label: 'Catalog',
                  onTap: () => setState(() {
                        _tab = 1;
                        _sortKey = 'title';
                        _asc = true;
                        _catalogPage = 0;
                      }))),
          const SizedBox(width: 10),
          Expanded(
              child: _QuickAction(
                  icon: Icons.history,
                  label: 'History',
                  onTap: () => _goTransactions('All Statuses'))),
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
        childAspectRatio: 1.8,
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
      _BorrowChart(transactions: _lib.transactions),
      const SizedBox(height: 28),

      // Pending requests
      _Section('Pending Requests (${pending.length})', Icons.how_to_reg),
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _openRequests,
            style: TextButton.styleFrom(foregroundColor: Palette.burgundy),
            child: Text('View all (${pending.length})'),
          ),
        ),
      ],
      const SizedBox(height: 20),

      // Overdue books
      const _Section('Overdue Books', Icons.warning_amber_rounded),
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _goTransactions('Overdue'),
            style: TextButton.styleFrom(foregroundColor: Palette.burgundy),
            child: Text('View all (${overdue.length})'),
          ),
        ),
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

  Future<void> _openStudent(AppUser s) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _StudentSheet(
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
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
    return Card(
      elevation: 0,
      color: Palette.card,
      shape: _cardShape,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(
                url: book.imageUrl,
                bytes: book.imageBytes,
                color: book.color,
                title: book.title,
                w: 56,
                h: 80),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(book.author,
                      style: const TextStyle(color: Palette.textMuted)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (book.publisher.isNotEmpty) book.publisher,
                      book.category,
                      if (book.published != null) _fmt(book.published),
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text('$left of ${book.totalCopies} copies available',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      left > 0
                          ? const _Badge('Available', Color(0xFF0C7A43))
                          : const _Badge('Unavailable', Color(0xFFEEA51C)),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: left > 0 ? onIssue : null,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Palette.burgundy,
                        ),
                        child: const Text('Issue'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                    tooltip: 'Edit ${book.title}',
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    tooltip: 'Delete ${book.title}',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    color: const Color(0xFFC0121F),
                    icon: const Icon(Icons.delete_outline)),
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
      color: Palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: t.overdue ? red.withAlpha(150) : const Color(0x2655161D)),
      ),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(t.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
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
  static const _size = 3;
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
          _TxCard(tx: t, onReturn: () => widget.onReturn(t)),
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
      color: Palette.card,
      shape: _cardShape,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Palette.burgundy,
          child: Text(student.initial,
              style: const TextStyle(
                  color: Palette.creamLight, fontWeight: FontWeight.w700)),
        ),
        title: Text(student.fullName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${student.email}\n${student.phone}'),
        isThreeLine: true,
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Badge('${active.length}/${LibraryService.maxActiveLoans} books',
                Palette.burgundy),
            if (overdue > 0) ...[
              const SizedBox(height: 4),
              _Badge('$overdue overdue', const Color(0xFFC0121F)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentSheet extends StatelessWidget {
  const _StudentSheet({
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
        final problem = lib.eligibility(s);
        final fines = lib.finesOutstanding(email);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(s.fullName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              Text('${s.email} · ${s.phone}',
                  style: const TextStyle(color: Palette.textMuted)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (problem == null
                          ? const Color(0xFF0C7A43)
                          : const Color(0xFFC0121F))
                      .withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  problem == null ? 'Eligible to borrow' : problem,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: problem == null
                        ? const Color(0xFF0C7A43)
                        : const Color(0xFFC0121F),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                  'Borrowing limit: ${lib.activeLoansOf(email).length}/${LibraryService.maxActiveLoans} books',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (fines > 0) ...[
                const SizedBox(height: 8),
                Text('Outstanding fines: ₱${fines.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Color(0xFFC0121F), fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onIssue(s),
                  icon: const Icon(Icons.add),
                  label: const Text('Issue a book'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.burgundy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Borrowing records',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (records.isEmpty)
                const Text('No borrowing records yet.',
                    style: TextStyle(color: Palette.textMuted))
              else
                _PagedTxList(records: records, onReturn: onReturn),
            ],
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

const _csvTemplate = '''title,author,isbn,publisher,category,published,copies,pages,description,image,shelf
The Hobbit,J.R.R. Tolkien,9780547928227,Allen & Unwin,Fiction,1937-09-21,3,310,A hobbit goes on an unexpected adventure.,,Aisle 1
A Brief History of Time,Stephen Hawking,9780553380163,Bantam Books,Non-Fiction,1988-04-01,2,212,An introduction to cosmology for general readers.,https://example.com/cover.jpg,Aisle 4
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

class _ImportRow {
  _ImportRow(this.line, this.label);
  final int line; // row number in the file (header = 1)
  final String label;
  Book? book;
  final errors = <String>[];
  bool get ok => book != null && errors.isEmpty;
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

  List<_ImportRow> get _valid => _rows.where((r) => r.ok).toList();
  List<_ImportRow> get _bad => _rows.where((r) => !r.ok).toList();

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

    // Map header names (case-insensitive) to column positions.
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

    // Existing books + earlier rows count as duplicates (title + author).
    String keyOf(String t, String a) => '${t.toLowerCase()}|${a.toLowerCase()}';
    final seen = <String>{
      for (final b in LibraryService.instance.books) keyOf(b.title, b.author),
    };

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
      final published = DateTime.tryParse(pubRaw);
      check(Validators.publishedDate(published));
      if (published == null && pubRaw.isNotEmpty) {
        row.errors.add('Use the date format YYYY-MM-DD.');
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

      if (row.errors.isEmpty) {
        final k = keyOf(title, author);
        if (seen.contains(k)) {
          row.errors.add('Duplicate: this title and author already exist.');
        } else {
          seen.add(k);
          final n = int.parse(copies);
          row.book = Book(
            title: title,
            author: author,
            publisher: publisher,
            category: category,
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
        }
      }
      out.add(row);
    }

    setState(() {
      _fileName = name;
      _fileError = table.length - 1 > _maxRows
          ? 'Only the first $_maxRows rows were read.'
          : null;
      _rows = out;
    });
  }

  Future<void> _import() async {
    final count = _valid.length;
    final ok = await _confirmDialog(
        context,
        'Import Books',
        'Import $count ${count == 1 ? 'book' : 'books'} into the catalog?',
        'Yes, import');
    if (!ok || !mounted) return;
    final books = _valid.map((r) => r.book!).toList();
    final n = await LibraryService.instance.addAll(books);
    if (!mounted) return;
    final skipped = _bad.length + (books.length - n);
    Navigator.pop(
      context,
      'Imported $n ${n == 1 ? 'book' : 'books'}'
      '${skipped > 0 ? ' ($skipped skipped)' : ''}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _valid.length;
    final bad = _bad;

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
                        'Up to 500 rows per file. Books already in the '
                            'catalog (same title and author) are skipped.',
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
                if (_rows.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _ResultTile(
                            label: 'Ready to import',
                            value: valid,
                            color: const Color(0xFF0C7A43),
                            icon: Icons.check_circle_outline),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ResultTile(
                            label: 'Will be skipped',
                            value: bad.length,
                            color: const Color(0xFFC0121F),
                            icon: Icons.warning_amber_rounded),
                      ),
                    ],
                  ),
                  if (bad.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC0121F).withAlpha(18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFC0121F).withAlpha(90)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fix these rows and upload again:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFC0121F))),
                          const SizedBox(height: 8),
                          for (final r in bad.take(20))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Row ${r.line} · ${r.label}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  Text(r.errors.join(' '),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Palette.textDark)),
                                ],
                              ),
                            ),
                          if (bad.length > 20)
                            Text('...and ${bad.length - 20} more.',
                                style: const TextStyle(
                                    fontSize: 12, color: Palette.textMuted)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: valid == 0 ? null : _import,
                      icon: const Icon(Icons.auto_stories),
                      label: Text(valid == 0
                          ? 'Nothing to import'
                          : 'Import $valid ${valid == 1 ? 'book' : 'books'}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.burgundy,
                        foregroundColor: Palette.creamLight,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: valid == 0
                                  ? Colors.transparent
                                  : Palette.amber,
                              width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
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
  ('isbn', true, '10 or 13 digits', '9780547928227'),
  ('publisher', true, 'Up to 60 characters', 'Allen & Unwin'),
  ('category', true, 'Pick from the list below', 'Fantasy'),
  ('published', true, 'YYYY-MM-DD, not in the future', '1937-09-21'),
  ('pages', true, 'Whole number 1 to 10000', '310'),
  ('description', false, '10 to 300 characters (can be blank)', 'A hobbit goes on an adventure.'),
  ('copies', false, 'Whole number 1 to 99 (blank = 1)', '3'),
  ('image', false, 'Link starting with https://', 'https://site.com/cover.jpg'),
  ('shelf', false, 'Up to 40 characters', 'Aisle 3, Shelf B'),
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
    'title', 'author', 'publisher', 'category',
    'published', 'description', 'copies', 'image',
  ];
  static const _rows = [
    [
      'The Hobbit', 'J.R.R. Tolkien', 'Allen & Unwin', 'Fantasy',
      '1937-09-21', 'A hobbit goes on...', '3', '',
    ],
    [
      'A Brief History of Time', 'Stephen Hawking', 'Bantam Books',
      'Science', '1988-04-01', 'An intro to cosmology...', '2',
      'https://...',
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
  const _BorrowChart({required this.transactions});
  final List<BookTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool sameDay(DateTime? x, DateTime d) =>
        x != null && x.year == d.year && x.month == d.month && x.day == d.day;

    final days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return (
        label: _weekdays[d.weekday - 1],
        borrowed: transactions.where((t) => sameDay(t.borrowedOn, d)).length,
        returned: transactions.where((t) => sameDay(t.returnedOn, d)).length,
      );
    });

    var max = 1;
    var totalB = 0;
    var totalR = 0;
    for (final d in days) {
      if (d.borrowed > max) max = d.borrowed;
      if (d.returned > max) max = d.returned;
      totalB += d.borrowed;
      totalR += d.returned;
    }

    const borrowedColor = Palette.burgundy;
    const returnedColor = Color(0xFF0C7A43);

    Widget bar(int n, Color c) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$n',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: n == 0 ? Colors.transparent : c)),
            const SizedBox(height: 2),
            Container(
              width: 14,
              height: n == 0 ? 3 : (n / max * 44).clamp(6, 44).toDouble(),
              decoration: BoxDecoration(
                color: n == 0 ? c.withAlpha(50) : c,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ),
          ],
        );

    Widget legend(Color c, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(text,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        );

    return Card(
      elevation: 0,
      color: Palette.card,
      shape: _cardShape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                legend(borrowedColor, 'Borrowed ($totalB)'),
                const SizedBox(width: 16),
                legend(returnedColor, 'Returned ($totalR)'),
                const Spacer(),
                const Text('Last 7 days',
                    style: TextStyle(fontSize: 12, color: Palette.textMuted)),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0x2655161D)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: Column(
                      children: [
                        SizedBox(
                          height: 66,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              bar(d.borrowed, borrowedColor),
                              const SizedBox(width: 3),
                              bar(d.returned, returnedColor),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(d.label,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Palette.textMuted)),
                      ],
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

// ---------- Desk widgets ----------

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.badge = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Palette.burgundy,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.amber, width: 1.2),
        ),
        child: Column(
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(icon, color: Palette.cream, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Palette.creamLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.burgundy.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withAlpha(150), shape: BoxShape.circle),
            child: Icon(icon, color: Palette.burgundy, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Palette.burgundy)),
                ),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.1,
                        fontWeight: FontWeight.w600)),
              ],
            ),
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