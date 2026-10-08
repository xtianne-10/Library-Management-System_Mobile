import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/app_nav_bar.dart';
import 'package:library_management_system_mobile/models/book.dart';

enum _Sort {
  title('Title A–Z'),
  author('Author A–Z'),
  newest('Newest first');

  const _Sort(this.label);
  final String label;
}

String _formatYear(int year) => year < 0 ? '${-year} BCE' : '$year';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();

  List<Book> _books = [];
  bool _loading = true;
  String? _error;

  String _query = '';
  String _category = 'All';
  bool _availableOnly = false;
  _Sort _sort = _Sort.title;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final books = await BookRepository.loadBooks();
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Failed to load books: $e');
      if (!mounted) return;
      setState(() {
        _error = 'We couldn\'t load the catalog.';
        _loading = false;
      });
    }
  }

  List<Book> get _results {
    final q = _query.trim().toLowerCase();

    final list = _books.where((b) {
      if (_category != 'All' && b.category != _category) return false;
      if (_availableOnly && !b.available) return false;
      if (q.isEmpty) return true;
      return b.title.toLowerCase().contains(q) ||
          b.author.toLowerCase().contains(q) ||
          b.category.toLowerCase().contains(q) ||
          b.description.toLowerCase().contains(q);
    }).toList();

    switch (_sort) {
      case _Sort.title:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _Sort.author:
        list.sort((a, b) =>
            a.author.toLowerCase().compareTo(b.author.toLowerCase()));
      case _Sort.newest:
        // Books with no year go last.
        list.sort((a, b) {
          final ay = a.year;
          final by = b.year;
          if (ay == null && by == null) return 0;
          if (ay == null) return 1;
          if (by == null) return -1;
          return by.compareTo(ay);
        });
    }
    return list;
  }

  bool get _hasFilters =>
      _query.isNotEmpty || _category != 'All' || _availableOnly;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = 'All';
      _availableOnly = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.page,
        body: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildBody(context)),
          ],
        ),
        bottomNavigationBar: const AppNavBar(currentIndex: 1),
      ),
    );
  }

  // Header: title + search

  Widget _buildHeader(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 20),
      decoration: const BoxDecoration(
        color: Palette.burgundy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Explore',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Palette.creamLight,
              )),
          const SizedBox(height: 2),
          Text('Find your next read.',
              style: text.bodyMedium?.copyWith(color: Palette.creamMuted)),
          const SizedBox(height: 16),
          SearchBar(
            controller: _searchController,
            hintText: 'Search titles, authors, or topics',
            hintStyle: const WidgetStatePropertyAll(
              TextStyle(color: Palette.textMuted),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(color: Palette.textDark),
            ),
            leading: const Icon(Icons.search, color: Palette.burgundy),
            trailing: [
              if (_query.isNotEmpty)
                IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close, color: Palette.burgundy),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                ),
            ],
            backgroundColor: const WidgetStatePropertyAll(Palette.cream),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v),
          ),
        ],
      ),
    );
  }

  // Body

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    // Categories come from books.json, not a hard-coded list.
    final categories = categoriesOf(_books);
    final results = _results;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Category chips
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final c = categories[i];
              final color = categoryChipColor(c);
              final selected = c == _category;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                showCheckmark: false,
                backgroundColor: Palette.page,
                selectedColor: color,
                side: BorderSide(color: color, width: 1.2),
                labelStyle: TextStyle(
                  fontFamily: 'Georgia',
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => _category = c),
              );
            },
          ),
        ),

        // Result count, availability filter, sort
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${results.length} ${results.length == 1 ? 'book' : 'books'}',
                  style: text.bodyMedium?.copyWith(color: Palette.textMuted),
                ),
              ),
              FilterChip(
                label: const Text('Available'),
                selected: _availableOnly,
                showCheckmark: false,
                avatar: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: _availableOnly ? Colors.white : Palette.slytherin,
                ),
                backgroundColor: Palette.page,
                selectedColor: Palette.slytherin,
                side: const BorderSide(color: Palette.slytherin, width: 1.2),
                labelStyle: TextStyle(
                  color: _availableOnly ? Colors.white : Palette.slytherin,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (v) => setState(() => _availableOnly = v),
              ),
              PopupMenuButton<_Sort>(
                tooltip: 'Sort books',
                icon: const Icon(Icons.sort, color: Palette.burgundy),
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => [
                  for (final s in _Sort.values)
                    PopupMenuItem(value: s, child: Text(s.label)),
                ],
              ),
            ],
          ),
        ),

        // Results
        Expanded(
          child: results.isEmpty
              ? _MessageState(
                  icon: Icons.search_off,
                  message: 'No books match your search.',
                  actionLabel: _hasFilters ? 'Clear filters' : null,
                  onAction: _hasFilters ? _clearFilters : null,
                )
              : GridView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.58,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, i) => _BookCard(
                    book: results[i],
                    onTap: () => _showDetails(results[i]),
                  ),
                ),
        ),
      ],
    );
  }

  // Book details sheet

  void _showDetails(Book book) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.page,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final text = Theme.of(sheetContext).textTheme;
        final meta = [
          book.category,
          if (book.year != null) _formatYear(book.year!),
          if (book.pages != null) '${book.pages} pages',
        ].join('  •  ');

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 130,
                      child: _Cover(book: book),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(book.title,
                              style: text.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Palette.burgundy,
                              )),
                          const SizedBox(height: 2),
                          Text(book.author,
                              style: text.bodyMedium
                                  ?.copyWith(color: Palette.textMuted)),
                          const SizedBox(height: 8),
                          Text(meta,
                              style: text.bodySmall
                                  ?.copyWith(color: Palette.textDark)),
                          const SizedBox(height: 8),
                          _AvailabilityLabel(book: book, showCopies: true),
                        ],
                      ),
                    ),
                  ],
                ),
                if (book.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(book.description,
                      style: text.bodyMedium?.copyWith(
                        color: Palette.textDark,
                        height: 1.4,
                      )),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.burgundy,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(book.available
                              ? 'Reserved "${book.title}".'
                              : 'You\'re on the waitlist for "${book.title}".'),
                        ),
                      );
                    },
                    child: Text(
                        book.available ? 'Reserve' : 'Join waitlist'),
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

// Widgets

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _Cover(book: book)),
          const SizedBox(height: 10),
          Text(book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Palette.textDark,
              )),
          Text(book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: Palette.textMuted)),
          const SizedBox(height: 6),
          _AvailabilityLabel(book: book),
        ],
      ),
    );
  }
}

class _AvailabilityLabel extends StatelessWidget {
  const _AvailabilityLabel({required this.book, this.showCopies = false});

  final Book book;
  final bool showCopies;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = book.available
        ? (showCopies
            ? '${book.copiesAvailable} of ${book.totalCopies} available'
            : 'Available')
        : 'On hold';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          book.available ? Icons.check_circle : Icons.schedule,
          size: 16,
          color: book.available ? Palette.slytherin : Palette.amber,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: text.bodySmall?.copyWith(color: Palette.textDark)),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(book.color);
    final spine = hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0));

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;

      return Container(
        decoration: BoxDecoration(
          color: book.color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            bottomLeft: Radius.circular(3),
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(width: width * 0.08, color: spine.toColor()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    book.title,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Palette.gold,
                      fontFamily: 'Georgia',
                      fontFamilyFallback: const ['serif'],
                      fontWeight: FontWeight.w700,
                      fontSize: (width * 0.13).clamp(11.0, 20.0),
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Palette.burgundy),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: Palette.textDark)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}