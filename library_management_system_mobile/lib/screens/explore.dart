import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/app_nav_bar.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/screens/book_details.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/widgets/book_cover.dart';

enum _Sort {
  title('Title A–Z'),
  author('Author A–Z'),
  newest('Newest first');

  const _Sort(this.label);
  final String label;
}

// Shared styling (matches Home and the web app).
const _border = Color(0x2255161D);
const _cream = Color(0xFFFBF6EE);
const _creamLine = Color(0xFFE8DCC8);
const _serif = 'Georgia';
const _serifFallback = ['serif'];

// Same colors as the web categories
Color _categoryColor(String c) => switch (c) {
      'Fiction' => const Color(0xFFE99B1C),
      'Non-Fiction' => const Color(0xFFC0151F),
      'Academic' => const Color(0xFF0E3F8A),
      'Restricted' => const Color(0xFF0A7A46),
      _ => Palette.burgundy,
    };

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  final _lib = LibraryService.instance;

  // Always read straight from the service (MongoDB via the API)
  List<Book> get _books => _lib.books;
  bool _loading = LibraryService.instance.books.isEmpty;
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
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _lib.books.isEmpty;
      _error = null;
    });
    await _lib.reload();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = (_lib.books.isEmpty && _lib.loadError != null)
          ? 'We couldn\'t load the catalog.'
          : null;
    });
  }

  List<Book> get _results {
    final q = _query.trim().toLowerCase();

    final list = _books.where((b) {
      if (_category != 'All' && b.category != _category) return false;
      if (_availableOnly && !_lib.isAvailable(b)) return false;
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
          final ap = a.published;
          final bp = b.published;
          if (ap == null && bp == null) return 0;
          if (ap == null) return 1;
          if (bp == null) return -1;
          return bp.compareTo(ap);
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
        body: ListenableBuilder(
          listenable: LibraryService.instance,
          builder: (context, _) => _buildBody(context),
        ),
        bottomNavigationBar: const AppNavBar(currentIndex: 1),
      ),
    );
  }

  // Hero header: eyebrow, headline, search

  Widget _buildHeader(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B0F12), Palette.burgundy, Color(0xFF7A2B32)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: topInset + 6,
            child: Icon(
              Icons.auto_stories,
              size: 160,
              color: Palette.gold.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HOGWARTS LIBRARY',
                  style: text.labelSmall?.copyWith(
                    color: Palette.gold,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Knowledge is the\ntruest magic.',
                  style: text.headlineMedium?.copyWith(
                    fontFamily: _serif,
                    fontFamilyFallback: _serifFallback,
                    fontWeight: FontWeight.w700,
                    color: Palette.creamLight,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Where every book holds a lesson, and every lesson holds power.',
                  style: text.bodyMedium?.copyWith(color: Palette.creamMuted),
                ),
                const SizedBox(height: 18),
                _buildSearchField(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Search field: the exact frosted look of the Home screen's search field,
  // as a real input. The border and fill brighten slightly while focused.
  Widget _buildSearchField() {
    return ListenableBuilder(
      listenable: _searchFocus,
      builder: (context, _) {
        final focused = _searchFocus.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: focused ? 0.18 : 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: focused ? 0.4 : 0.16),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 20, color: Palette.creamMuted),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textInputAction: TextInputAction.search,
                  cursorColor: Palette.creamLight,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Palette.creamLight),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search titles, authors, or topics',
                    hintStyle: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Palette.creamMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.close,
                        size: 20, color: Palette.creamMuted),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Colored category tabs with counts

  Widget _buildCategoryBar(List<String> categories) {
    int countOf(String c) => c == 'All'
        ? _books.length
        : _books.where((b) => b.category == c).length;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: _cream,
        border: Border(bottom: BorderSide(color: _creamLine)),
      ),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final c = categories[i];
            return _CategoryPill(
              label: c,
              count: countOf(c),
              color: categoryChipColor(c),
              selected: c == _category,
              onTap: () => setState(() => _category = c),
            );
          },
        ),
      ),
    );
  }

  // Body

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Column(
        children: [
          _buildHeader(context),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (_error != null) {
      return Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _MessageState(
              icon: Icons.cloud_off_outlined,
              message: _error!,
              actionLabel: 'Try again',
              onAction: _load,
            ),
          ),
        ],
      );
    }

    // Same four categories the web uses
    const categories = ['All', 'Fiction', 'Non-Fiction', 'Academic', 'Restricted'];
    final results = _results;
    final text = Theme.of(context).textTheme;

    // Like the web: newest available books
    final newArrivals = (_books.where((b) => _lib.isAvailable(b)).toList()
          ..sort((a, b) => (b.published ?? DateTime(0))
              .compareTo(a.published ?? DateTime(0))))
        .take(10)
        .toList();
    final spotlight =
        newArrivals.where((b) => b.description.isNotEmpty).firstOrNull ??
            newArrivals.firstOrNull;

    final heading = _query.trim().isNotEmpty
        ? 'Search results'
        : _category != 'All'
            ? _category
            : 'All books';

    return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              // Category tabs stay pinned while the page scrolls
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedBarDelegate(
                  height: 58,
                  child: _buildCategoryBar(categories),
                ),
              ),
              // Discovery sections only show when nothing is filtered
              if (!_hasFilters) ...[
                SliverToBoxAdapter(
                  child: _FadeSlide(
                    child: _Shelf(
                      title: 'New arrivals',
                      tint: Palette.gold,
                      books: newArrivals,
                    ),
                  ),
                ),
                if (spotlight != null)
                  SliverToBoxAdapter(
                    child: _FadeSlide(
                      child: _Spotlight(
                        book: spotlight,
                        onView: () => openBookDetails(context, spotlight),
                      ),
                    ),
                  ),

                for (final c in categories.where((c) => c != 'All'))
                  SliverToBoxAdapter(
                    child: _FadeSlide(
                      child: _Shelf(
                        title: c,
                        tint: categoryChipColor(c),
                        books:
                            _books.where((b) => b.category == c).take(10).toList(),
                        onSeeAll: () => setState(() => _category = c),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _FadeSlide(
                    child: _PromoBanner(
                      onAction: () =>
                          Navigator.pushReplacementNamed(context, '/mybooks'),
                    ),
                  ),
                ),
              ],

              // Results header: heading, count, availability, sort
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(heading,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Palette.textDark,
                          )),
                      const SizedBox(height: 2),
                      Text(
                        '${results.length} ${results.length == 1 ? 'book' : 'books'}',
                        style: text.bodySmall
                            ?.copyWith(color: Palette.textMuted),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('Available only'),
                            selected: _availableOnly,
                            showCheckmark: false,
                            avatar: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: _availableOnly
                                  ? Colors.white
                                  : Palette.slytherin,
                            ),
                            backgroundColor: Palette.card,
                            selectedColor: Palette.slytherin,
                            shape: const StadiumBorder(),
                            side: BorderSide(
                              color: _availableOnly
                                  ? Palette.slytherin
                                  : _border,
                            ),
                            labelStyle: TextStyle(
                              color: _availableOnly
                                  ? Colors.white
                                  : Palette.textDark,
                              fontWeight: FontWeight.w600,
                            ),
                            onSelected: (v) =>
                                setState(() => _availableOnly = v),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<_Sort>(
                            tooltip: 'Sort books',
                            initialValue: _sort,
                            position: PopupMenuPosition.under,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (s) => setState(() => _sort = s),
                            itemBuilder: (_) => [
                              for (final s in _Sort.values)
                                PopupMenuItem(value: s, child: Text(s.label)),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Palette.card,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.swap_vert,
                                      size: 16, color: Palette.burgundy),
                                  const SizedBox(width: 4),
                                  Text(
                                    _sort.label,
                                    style: text.labelLarge?.copyWith(
                                      color: Palette.textDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (results.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(
                    icon: Icons.search_off,
                    message: 'No books match your search.',
                    actionLabel: _hasFilters ? 'Clear filters' : null,
                    onAction: _hasFilters ? _clearFilters : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 12.0;
                      const cols = 3;
                      // Cover is always 2:3, text area gets a fixed height
                      final tileW =
                          (constraints.crossAxisExtent - gap * (cols - 1)) /
                              cols;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: 18,
                          mainAxisExtent: tileW * 1.5 + 78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => _BookCard(
                            book: results[i],
                            onTap: () => openBookDetails(context, results[i]),
                          ),
                          childCount: results.length,
                        ),
                      );
                    },
                  ),
                ),
            ],
    );
  }
}

// Widgets

class _PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedBarDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox(height: height, child: child);

  @override
  bool shouldRebuild(covariant _PinnedBarDelegate old) =>
      old.child != child || old.height != height;
}

/// Gentle fade + rise when a section first appears.
class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.only(left: 14, right: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.title,
    required this.books,
    required this.tint,
    this.onSeeAll,
  });

  final String title;
  final List<Book> books;
  final Color tint;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 12, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Palette.textDark,
                    )),
              ),
              if (onSeeAll != null)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Palette.burgundy,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onSeeAll,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('See all',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 276,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: books.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, i) {
              final b = books[i];
              return SizedBox(
                width: 130,
                child: InkWell(
                  onTap: () => openBookDetails(context, b),
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 130, height: 184, child: _Cover(book: b)),
                      const SizedBox(height: 10),
                      Text(b.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Palette.textDark,
                          )),
                      const SizedBox(height: 1),
                      Text(b.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall
                              ?.copyWith(color: Palette.textMuted)),
                      const SizedBox(height: 6),
                      _AvailabilityLabel(book: b),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// "Featured this week" card with a glowing backdrop behind the cover.
class _Spotlight extends StatelessWidget {
  const _Spotlight({required this.book, required this.onView});

  final Book book;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _creamLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FEATURED THIS WEEK',
                  style: text.labelSmall?.copyWith(
                    color: Palette.amber,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(
                    fontFamily: _serif,
                    fontFamilyFallback: _serifFallback,
                    fontWeight: FontWeight.w700,
                    color: Palette.textDark,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text('by ${book.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: Palette.textMuted)),
                if (book.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    book.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall
                        ?.copyWith(color: Palette.textDark, height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.burgundy,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: onView,
                  child: const Text('View details',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 112,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Palette.gold.withValues(alpha: 0.28),
                  ),
                ),
                GestureDetector(
                  onTap: onView,
                  child: SizedBox(width: 106, height: 156, child: _Cover(book: book)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Burgundy call-to-action banner (mirrors the web promo).
class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onAction});
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF2B0F12), Palette.burgundy, Color(0xFF7A2B32)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3355161D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Transform.rotate(
              angle: 0.2,
              child: Icon(
                Icons.bookmarks,
                size: 130,
                color: Palette.gold.withValues(alpha: 0.14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: text.titleLarge?.copyWith(
                      fontFamily: _serif,
                      fontFamilyFallback: _serifFallback,
                      color: Palette.creamLight,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    children: [
                      const TextSpan(text: 'Borrow any available book for '),
                      TextSpan(
                        text: '7 days',
                        style: TextStyle(color: Palette.gold),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Return on time and keep your record clean. Mischief managed.',
                  style: text.bodySmall?.copyWith(color: Palette.creamMuted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.amber,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  onPressed: onAction,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View my books',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
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

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = _categoryColor(book.category);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _Cover(book: book)),
                Positioned(
                  top: 6,
                  left: 6,
                  child: _StatusDot(book: book),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Palette.textDark,
                height: 1.2,
              )),
          const SizedBox(height: 2),
          Text(book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelSmall?.copyWith(color: Palette.textMuted)),
          const SizedBox(height: 5),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(book.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(
                      color: Palette.textMuted,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact status marker for small covers (icon only).
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final isAvail = LibraryService.instance.isAvailable(book);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isAvail ? Palette.slytherin : Palette.amber,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4),
        ],
      ),
      child: Icon(isAvail ? Icons.check : Icons.schedule,
          size: 11, color: Colors.white),
    );
  }
}

// Solid status pill laid over a cover.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final isAvail = LibraryService.instance.isAvailable(book);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isAvail ? Palette.slytherin : Palette.amber,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isAvail ? Icons.check_circle : Icons.schedule,
              size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            isAvail ? 'Available' : 'On hold',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    final store = LibraryService.instance;
    final isAvail = store.isAvailable(book);
    final color = isAvail ? Palette.slytherin : Palette.amber;
    final label = isAvail
        ? (showCopies
            ? '${store.copiesLeft(book)} of ${book.totalCopies} available'
            : 'Available')
        : 'On hold';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: text.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) => BookCover(book: book);
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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Palette.burgundy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: Palette.burgundy),
            ),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: Palette.textDark)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.burgundy,
                  side: const BorderSide(color: Palette.burgundy),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: onAction,
                child: Text(actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}