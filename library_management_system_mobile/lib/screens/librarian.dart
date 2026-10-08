import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

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

class LibrarianScreen extends StatefulWidget {
  const LibrarianScreen({super.key});

  @override
  State<LibrarianScreen> createState() => _LibrarianScreenState();
}

class _LibrarianScreenState extends State<LibrarianScreen> {
  final _lib = LibraryService.instance;
  String _query = '';
  String _sortKey = 'title';
  bool _asc = true;
  String _txFilter = 'All Statuses';

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
        'status' => b.available ? 'Available' : 'Unavailable',
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

  @override
  Widget build(BuildContext context) {
    if (!_isLibrarian) return const Scaffold();

    final books = _visibleBooks;
    final tx = _lib.transactions
        .where((t) => _txFilter == 'All Statuses' || t.status == _txFilter)
        .toList();
    final all = _lib.books;
    final stats = [
      ('Total Books', all.length, const Color(0xFFE4F1EE)),
      ('Borrowed', _lib.transactions.where((t) => !t.returned).length,
          const Color(0xFFDEDAF4)),
      ('Overdue', _lib.transactions.where((t) => t.overdue).length,
          const Color(0xFFFFADAD)),
      ('Available', all.where((b) => b.available).length,
          const Color(0xFFFFD6A5)),
    ];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.burgundy,
        foregroundColor: Palette.creamLight,
        title: const Text('Hogwarts Library'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: Palette.amber,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Book'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [
          Text('Librarian Dashboard',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
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
                      color: s.$3, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(s.$1,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('${s.$2}',
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // ---- Catalog ----
          Text('Book Catalog',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _query = v),
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
                  onChanged: (v) => setState(() => _sortKey = v ?? 'title'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: _asc ? 'A to Z' : 'Z to A',
                icon: Icon(_asc ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () => setState(() => _asc = !_asc),
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
            for (final b in books)
              _CatalogCard(
                book: b,
                onEdit: () => _openForm(b),
                onDelete: () => _confirmDelete(b),
              ),
          const SizedBox(height: 28),

          // ---- Transactions ----
          Text('Transaction History',
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _txFilter,
            decoration: const InputDecoration(
                isDense: true, border: OutlineInputBorder()),
            items: const ['All Statuses', 'Not Returned', 'Returned']
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _txFilter = v ?? 'All Statuses'),
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
            for (final t in tx)
              Card(
                elevation: 0,
                color: Palette.card,
                child: ListTile(
                  title: Text(t.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${t.borrower}\nBorrowed ${_fmt(t.borrowedOn)} · Due ${_fmt(t.due)}'
                    '${t.returned ? '\nReturned ${_fmt(t.returnedOn)}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: _Badge(
                    t.overdue ? 'Overdue' : t.status,
                    t.overdue
                        ? const Color(0xFFC0121F)
                        : t.returned
                            ? const Color(0xFF0C7A43)
                            : const Color(0xFFEEA51C),
                  ),
                ),
              ),
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
      this.w = 40, this.h = 58});
  final String url;
  final Uint8List? bytes;
  final Color color;
  final double w, h;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: w,
      height: h,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
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
  const _CatalogCard(
      {required this.book, required this.onEdit, required this.onDelete});
  final Book book;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Palette.card,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Cover(url: book.imageUrl, bytes: book.imageBytes, color: book.color),
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
                  const SizedBox(height: 6),
                  book.available
                      ? const _Badge('Available', Color(0xFF0C7A43))
                      : const _Badge('Unavailable', Color(0xFFEEA51C)),
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
    for (final c in [_title, _author, _publisher, _desc, _image, _dateCtl]) {
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