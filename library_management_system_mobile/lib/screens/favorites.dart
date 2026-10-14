import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';
import 'package:library_management_system_mobile/globes/favorites_store.dart';
import 'package:library_management_system_mobile/screens/book_details.dart';

const _pageSize = 10;
const _cardBorder = Color(0x1A000000);

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _searchController = TextEditingController();
  final _scroll = ScrollController();

  String _query = '';
  String _category = 'All';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    FavoritesStore.instance.ensureLoaded();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _remove(Book book) async {
    final messenger = ScaffoldMessenger.of(context);
    final err = await FavoritesStore.instance.toggle(book);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(err ?? 'Removed "${book.title}"'),
        action: err != null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () => FavoritesStore.instance.toggle(book),
              ),
      ));
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = 'All';
      _page = 1;
    });
  }

  void _changePage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.page,
        body: ListenableBuilder(
          listenable: Listenable.merge([
            FavoritesStore.instance,
            BorrowStore.instance,
          ]),
          builder: (context, _) {
            final all = FavoritesStore.instance.items;

            // Categories that actually exist in the favorites
            final categories = {
              for (final b in all)
                if (b.category.isNotEmpty) b.category,
            }.toList()
              ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

            // If the selected category no longer exists, fall back to All
            final category =
                (_category == 'All' || categories.contains(_category))
                    ? _category
                    : 'All';

            final q = _query.trim().toLowerCase();
            final filtered = all.where((b) {
              if (category != 'All' && b.category != category) return false;
              if (q.isEmpty) return true;
              return b.title.toLowerCase().contains(q) ||
                  b.author.toLowerCase().contains(q) ||
                  b.category.toLowerCase().contains(q);
            }).toList();

            final totalPages =
                filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
            final page = _page > totalPages ? totalPages : _page;
            final pageItems =
                filtered.skip((page - 1) * _pageSize).take(_pageSize).toList();

            final hasFilters = q.isNotEmpty || category != 'All';

            Widget body;
            if (all.isEmpty) {
              body = const _EmptyState();
            } else if (filtered.isEmpty) {
              body = _NoMatches(
                onClear: hasFilters ? _clearFilters : null,
              );
            } else {
              body = ListView.separated(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: pageItems.length + 1, // +1 = pagination footer
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  if (i < pageItems.length) {
                    final b = pageItems[i];
                    return _FavoriteCard(
                      key: ValueKey(b.remoteId),
                      book: b,
                      onRemove: () => _remove(b),
                    );
                  }
                  return _PaginationBar(
                    shown: pageItems.length,
                    total: filtered.length,
                    page: page,
                    totalPages: totalPages,
                    onChange: _changePage,
                  );
                },
              );
            }

            return Column(
              children: [
                // Header: back, title, count, search
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(8, topInset + 8, 20, 20),
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
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: Palette.creamLight,
                            tooltip: 'Back',
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('My Favorites',
                                    style: text.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Palette.creamLight,
                                    )),
                                const SizedBox(height: 2),
                                Text(
                                  '${all.length} ${all.length == 1 ? 'book' : 'books'} saved',
                                  style: text.bodyMedium
                                      ?.copyWith(color: Palette.creamMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (all.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: _buildSearch(text),
                        ),
                      ],
                    ],
                  ),
                ),

                // Category chips
                if (all.isNotEmpty)
                  SizedBox(
                    height: 62,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      children: [
                        for (final c in ['All', ...categories]) ...[
                          _CategoryPill(
                            label: c,
                            count: c == 'All'
                                ? all.length
                                : all.where((b) => b.category == c).length,
                            selected: c == category,
                            onTap: () => setState(() {
                              _category = c;
                              _page = 1;
                            }),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),

                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearch(TextTheme text) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Palette.creamMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              cursorColor: Palette.creamLight,
              style: text.bodyMedium?.copyWith(color: Palette.creamLight),
              onChanged: (v) => setState(() {
                _query = v;
                _page = 1;
              }),
              decoration: InputDecoration(
                hintText: 'Search title or author',
                hintStyle: text.bodyMedium?.copyWith(color: Palette.creamMuted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _page = 1;
                });
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, size: 20, color: Palette.creamMuted),
              ),
            ),
        ],
      ),
    );
  }
}

// Widgets

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
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
          color: selected ? Palette.burgundy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Palette.burgundy
                : Palette.burgundy.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Palette.burgundy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.25)
                    : Palette.burgundy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Palette.burgundy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({super.key, required this.book, required this.onRemove});

  final Book book;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isAvail = BorrowStore.instance.isAvailable(book);
    final statusColor = isAvail ? Palette.slytherin : Palette.amber;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openBookDetails(context, book),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniCover(book: book),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (book.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Palette.burgundy.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            book.category,
                            style: text.labelSmall?.copyWith(
                              color: Palette.burgundy,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Palette.textDark,
                          )),
                      const SizedBox(height: 2),
                      Text(book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium
                              ?.copyWith(color: Palette.textMuted)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            isAvail ? Icons.check_circle : Icons.schedule,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAvail ? 'Available' : 'On hold',
                            style: text.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove from favorites',
                  color: const Color(0xFFEF4444),
                  icon: const Icon(Icons.favorite),
                  onPressed: onRemove,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.book});
  final Book book;

  static const double width = 64;
  static const double height = 92;
  static const radius = BorderRadius.only(
    topLeft: Radius.circular(3),
    bottomLeft: Radius.circular(3),
    topRight: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  Widget _fallback() {
    final hsl = HSLColor.fromColor(book.color);
    final spine = hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0));

    return Container(
      width: width,
      height: height,
      color: book.color,
      child: Row(
        children: [
          Container(width: width * 0.08, color: spine.toColor()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  book.title,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.gold,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['serif'],
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (book.imageBytes != null) {
      content = Image.memory(
        book.imageBytes!,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else if (book.imageUrl.isNotEmpty) {
      content = Image.network(
        book.imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    } else {
      content = _fallback();
    }

    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );
  }
}

// Pagination (mirrors Pagination in Profile.jsx)

List<Object> _pageNumbers(int page, int total) {
  if (total <= 7) return [for (var i = 1; i <= total; i++) i];
  final shown = {1, total, page - 1, page, page + 1}
      .where((p) => p >= 1 && p <= total)
      .toList()
    ..sort();
  final out = <Object>[];
  for (var i = 0; i < shown.length; i++) {
    if (i > 0 && shown[i] - shown[i - 1] > 1) out.add('…');
    out.add(shown[i]);
  }
  return out;
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.shown,
    required this.total,
    required this.page,
    required this.totalPages,
    required this.onChange,
  });

  final int shown;
  final int total;
  final int page;
  final int totalPages;
  final ValueChanged<int> onChange;

  Widget _btn(String label, {VoidCallback? onTap, bool selected = false}) {
    return Opacity(
      opacity: onTap == null && !selected ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minWidth: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Palette.burgundy : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Palette.burgundy : const Color(0xFF9CA3AF),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : Palette.textDark,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          if (totalPages > 1) ...[
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                _btn('Prev', onTap: page > 1 ? () => onChange(page - 1) : null),
                for (final p in _pageNumbers(page, totalPages))
                  if (p is int)
                    _btn('$p', selected: p == page, onTap: () => onChange(p))
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text('…',
                          style: TextStyle(color: Palette.textMuted)),
                    ),
                _btn('Next',
                    onTap: page < totalPages ? () => onChange(page + 1) : null),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'Showing $shown of $total',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Palette.textMuted),
          ),
        ],
      ),
    );
  }
}

// Empty states

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Palette.burgundy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_border,
                  size: 40, color: Palette.burgundy),
            ),
            const SizedBox(height: 16),
            Text('No favorites yet',
                style: text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Palette.burgundy,
                )),
            const SizedBox(height: 6),
            Text(
              'Tap the heart on any book to save it here.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: Palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({this.onClear});
  final VoidCallback? onClear;

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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Palette.burgundy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off,
                  size: 40, color: Palette.burgundy),
            ),
            const SizedBox(height: 16),
            Text('No favorites match your search.',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: Palette.textDark)),
            if (onClear != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Palette.burgundy,
                  side: const BorderSide(color: Palette.burgundy),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: onClear,
                child: const Text('Clear filters',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}