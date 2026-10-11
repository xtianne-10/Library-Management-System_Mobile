import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';
import 'package:library_management_system_mobile/globes/favorites_store.dart';
import 'package:library_management_system_mobile/screens/book_details.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  void _remove(BuildContext context, Book book) {
    FavoritesStore.instance.toggle(book);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Removed "${book.title}"'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => FavoritesStore.instance.toggle(book),
        ),
      ));
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
            final books = FavoritesStore.instance.items;

            return Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(8, topInset + 8, 20, 24),
                  decoration: const BoxDecoration(
                    color: Palette.burgundy,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
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
                            Text('My favorites',
                                style: text.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Palette.creamLight,
                                )),
                            const SizedBox(height: 2),
                            Text(
                              '${books.length} ${books.length == 1 ? 'book' : 'books'} saved',
                              style: text.bodyMedium
                                  ?.copyWith(color: Palette.creamMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Expanded(
                  child: books.isEmpty
                      ? const _EmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          itemCount: books.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _FavoriteRow(
                            book: books[i],
                            onRemove: () => _remove(context, books[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Widgets
class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.book, required this.onRemove});

  final Book book;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isAvail = BorrowStore.instance.isAvailable(book);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Palette.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x2655161D)),
      ),
      child: InkWell(
        onTap: () => openBookDetails(context, book),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _MiniCover(book: book),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Palette.textDark,
                        )),
                    const SizedBox(height: 2),
                    Text(book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium
                            ?.copyWith(color: Palette.textMuted)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          isAvail ? Icons.check_circle : Icons.schedule,
                          size: 16,
                          color: isAvail ? Palette.slytherin : Palette.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isAvail ? 'Available' : 'On hold',
                          style: text.bodySmall
                              ?.copyWith(color: Palette.textDark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from favorites',
                color: Palette.burgundy,
                icon: const Icon(Icons.favorite),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.book});
  final Book book;

  static const double width = 56;
  static const double height = 80;
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
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.gold,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: ['serif'],
                    fontWeight: FontWeight.w700,
                    fontSize: 8,
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
      content = Image.memory(book.imageBytes!,
          width: width, height: height, fit: BoxFit.cover);
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
            const Icon(Icons.favorite_border,
                size: 56, color: Palette.burgundy),
            const SizedBox(height: 14),
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