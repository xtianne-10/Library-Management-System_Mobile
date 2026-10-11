import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:library_management_system_mobile/utils/csv_download.dart';

import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/utils/validators.dart';

const _categories = [
  'Fiction', 'Non-Fiction', 'Science Fiction', 'Fantasy',
  'Mystery', 'Biography', 'History', 'Science',
];

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
  borderRadius: BorderRadius.all(Radius.circular(12)),
  side: BorderSide(color: Color(0x2655161D)),
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
        const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Students'),
        NavigationDestination(
            icon: Badge(
              isLabelVisible: overdue > 0,
              label: Text('$overdue'),
              child: const Icon(Icons.history_edu_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: overdue > 0,
              label: Text('$overdue'),
              child: const Icon(Icons.history_edu),
            ),
            label: 'Loans'),
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
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lib.removeListener(_refresh);
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
    final result = await showModalBottomSheet<Book>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BookForm(book: book),
    );
    if (result == null) return;
    book == null ? _lib.add(result) : _lib.update(result);
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
    if (ok == true) _lib.remove(b.id);
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
            20, MediaQuery.of(context).padding.top + 16, 20, 20),
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
                      style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Palette.creamLight)),
                  const SizedBox(height: 2),
                  Text('Keeper of the Hogwarts Library',
                      style: text.bodyMedium
                          ?.copyWith(color: Palette.creamMuted)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'profile') {
                  Navigator.pushNamed(context, '/profile');
                } else {
                  _confirmLogout();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'profile', child: Text('My Profile')),
                PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Palette.cream,
                backgroundImage:
                    user?.avatar != null ? MemoryImage(user!.avatar!) : null,
                child: user?.avatar == null
                    ? Text(user?.initial ?? '?',
                        style: const TextStyle(
                            color: Palette.burgundy,
                            fontWeight: FontWeight.w700))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _returnTx(BookTransaction t) {
    final fine = t.fine;
    final err = _lib.returnBook(t.id);
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
        .where((t) =>
            _txFilter == 'All Statuses' ||
            (_txFilter == 'Overdue' ? t.overdue : t.status == _txFilter))
        .toList();
    final all = _lib.books;
    final allStudents = AuthService.instance.students;
    final sq = _studentQuery.trim().toLowerCase();
    final foundStudents = allStudents
        .where((s) =>
            sq.isEmpty ||
            s.fullName.toLowerCase().contains(sq) ||
            s.email.toLowerCase().contains(sq) ||
            s.phone.contains(sq))
        .toList();
    final stats = [
      ('Total Books', '${all.length}', const Color(0xFFE4F1EE)),
      ('Borrowed', '${_lib.transactions.where((t) => !t.returned).length}',
          const Color(0xFFDEDAF4)),
      ('Overdue', '${_lib.transactions.where((t) => t.overdue).length}',
          const Color(0xFFFFADAD)),
      ('Available', '${all.where((b) => _lib.isAvailable(b)).length}',
          const Color(0xFFFFD6A5)),
      ('Students', '${allStudents.length}', const Color(0xFFD7ECFF)),
      ('Fines Due', '₱${_lib.outstandingFines.toStringAsFixed(0)}',
          const Color(0xFFF6D6E8)),
    ];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Palette.page,
      appBar: PreferredSize(
        preferredSize:
            Size.fromHeight(112 + MediaQuery.of(context).padding.top),
        child: _header(),
      ),
      bottomNavigationBar: _LibNavBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          if (_tab == 0) ...[
          const _Section('Overview', Icons.auto_stories),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: [
              for (final s in stats)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: s.$3,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Palette.burgundy.withAlpha(50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.$1,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${s.$2}',
                          style: const TextStyle(
                              fontSize: 28,
                              fontFamily: 'Georgia',
                              color: Palette.burgundy,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openIssue(),
              icon: const Icon(Icons.assignment_ind_outlined),
              label: const Text('Issue Book to Student'),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.burgundy,
                foregroundColor: Palette.creamLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Palette.amber, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          ],
          if (_tab == 1) ...[
          // ---- Catalog ----
          const _Section('Book Catalog', Icons.menu_book),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openImport,
              icon: const Icon(Icons.upload_file),
              label: const Text('Bulk Import (CSV)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Palette.burgundy,
                side: const BorderSide(color: Palette.burgundy),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() {
              _query = v;
              _catalogPage = 0;
            }),
            decoration: const InputDecoration(
              hintText: 'Search by title or author',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Sort by',
                      isDense: true,
                      border: OutlineInputBorder()),
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
          // ---- Student lookup ----
          const _Section('Student Lookup', Icons.school),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() {
              _studentQuery = v;
              _studentPage = 0;
            }),
            decoration: const InputDecoration(
              hintText: 'Search by name, email, or phone',
              prefixIcon: Icon(Icons.person_search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
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
          if (_tab == 3) ...[
          // ---- Transactions ----
          const _Section('Transaction History', Icons.history_edu),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _txFilter,
            decoration: const InputDecoration(
                isDense: true, border: OutlineInputBorder()),
            items: const ['All Statuses', 'Not Returned', 'Overdue', 'Returned']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() {
              _txFilter = v ?? 'All Statuses';
              _txPage = 0;
            }),
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
        ],
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
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    tooltip: 'Delete ${book.title}',
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
                  onPressed: () {
                    final err = LibraryService.instance.payFine(t.id);
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
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
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
    final students = AuthService.instance.students;
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
                    ? () {
                        final err = _lib.checkOut(book, student);
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
    for (final c in [_title, _author, _publisher, _desc, _image, _dateCtl, _copies]) {
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
    final f = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
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
        totalCopies: int.parse(_copies.text.trim()),
        copiesAvailable: int.parse(_copies.text.trim()),
        description: _desc.text.trim(),
        imageUrl: _bytes != null ? '' : _image.text.trim(),
        imageBytes: _bytes,
        clearImageBytes: _bytes == null,
      ),
    );
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    const auto = AutovalidateMode.onUserInteraction;
    final previewUrl =
        Validators.imageUrl(_image.text) == null ? _image.text.trim() : '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(_editing ? 'Edit Book' : 'Add Book',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
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
                decoration: _dec('Number of Copies', hint: 'e.g. 3'),
                validator: Validators.copies,
                autovalidateMode: auto,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _desc,
                maxLines: 4,
                maxLength: 300,
                decoration: _dec('Description',
                    hint: 'Enter a short description...'),
                validator: Validators.description,
                autovalidateMode: auto,
              ),
              const SizedBox(height: 6),
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

const _csvTemplate = '''title,author,publisher,category,published,copies,description,image
The Hobbit,J.R.R. Tolkien,Allen & Unwin,Fantasy,1937-09-21,3,A hobbit goes on an unexpected adventure.,
A Brief History of Time,Stephen Hawking,Bantam Books,Science,1988-04-01,2,An introduction to cosmology for general readers.,https://example.com/cover.jpg
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
    'title', 'author', 'publisher', 'category', 'published', 'description',
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
      check(Validators.description(desc));
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

  void _import() {
    final books = _valid.map((r) => r.book!).toList();
    final n = LibraryService.instance.addAll(books);
    final skipped = _bad.length;
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
  ('publisher', true, 'Up to 60 characters', 'Allen & Unwin'),
  ('category', true, 'Pick from the list below', 'Fantasy'),
  ('published', true, 'YYYY-MM-DD, not in the future', '1937-09-21'),
  ('description', true, '10 to 300 characters', 'A hobbit goes on an adventure.'),
  ('copies', false, 'Whole number 1 to 99 (blank = 1)', '3'),
  ('image', false, 'Link starting with https://', 'https://site.com/cover.jpg'),
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