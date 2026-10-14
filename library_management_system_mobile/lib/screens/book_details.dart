import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/globes/favorites_store.dart';

void openBookDetails(BuildContext context, Book book) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => BookDetailsScreen(book: book)),
  );
}

class BookDetailsScreen extends StatelessWidget {
  const BookDetailsScreen({super.key, required this.book});

  final Book book;

  // Negative years are BC
  String get _yearLabel {
    final y = book.year;
    if (y == null) return '—';
    return y < 0 ? '${-y} BC' : '$y';
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final wasFav = FavoritesStore.instance.isFavorite(book);
    final err = await FavoritesStore.instance.toggle(book);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(err ??
            (wasFav ? 'Removed from favorites' : 'Added to favorites')),
      ));
  }

    Future<void> _onBorrowPressed(BuildContext context,
      {required bool isAvail}) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (!isAvail) {
      messenger.showSnackBar(SnackBar(
        content: Text('All copies of "${book.title}" are on loan right now.'),
      ));
      return;
    }

    final me = AuthService.instance.currentUser;
    if (me == null) return;
    final error = await LibraryService.instance.requestBorrow(book, me);
    messenger.showSnackBar(SnackBar(
      content: Text(error ??
          'Request sent for "${book.title}". Waiting for librarian approval.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.of(context).padding.top;

    FavoritesStore.instance.ensureLoaded();

    // Header gradient
    final hsl = HSLColor.fromColor(book.color);
    final darker =
        hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          LibraryService.instance,
          FavoritesStore.instance,
        ]),
        builder: (context, _) {
          final isFav = FavoritesStore.instance.isFavorite(book);
          final store = LibraryService.instance;
          final email = AuthService.instance.currentUser?.email ?? '';
          final left = store.copiesLeft(book);
          final isAvail = left > 0;
          final loan = store
              .activeLoansOf(email)
              .where((t) => t.bookId == book.id)
              .firstOrNull;
          final pending = store.hasPendingFor(book, email);
          final declined = store.wasDeclinedFor(book, email);

          // Button text and action for the current state
          String buttonLabel;
          VoidCallback? buttonAction;

          if (loan != null) {
            final now = DateTime.now();
            final d = DateTime(loan.due.year, loan.due.month, loan.due.day)
                .difference(DateTime(now.year, now.month, now.day))
                .inDays;
            buttonLabel = loan.overdue
                ? 'Borrowed - Overdue by ${loan.daysOverdue} ${loan.daysOverdue == 1 ? 'day' : 'days'}'
                : d == 0
                    ? 'Borrowed - Due today'
                    : 'Borrowed - Due in $d ${d == 1 ? 'day' : 'days'}';
            buttonAction = null;
          } else if (pending) {
            buttonLabel = 'Waiting for approval';
            buttonAction = null;
          } else if (declined) {
            buttonLabel = 'Request declined - Try again';
            buttonAction = () => _onBorrowPressed(context, isAvail: isAvail);
          } else if (isAvail) {
            buttonLabel = 'Request to borrow';
            buttonAction = () => _onBorrowPressed(context, isAvail: isAvail);
          } else {
            buttonLabel = 'Currently on loan';
            buttonAction = null;
          }

          return Scaffold(
            backgroundColor: Palette.page,

            // Bottom action bar
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                color: Palette.page,
                border: Border(top: BorderSide(color: Color(0x1A000000))),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.burgundy,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Palette.burgundy.withValues(alpha: 0.5),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      onPressed: buttonAction,
                      child: Text(buttonLabel),
                    ),
                  ),
                ),
              ),
            ),

            body: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Hero header
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [book.color, darker],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 28),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _RoundIconButton(
                              icon: Icons.arrow_back,
                              tooltip: 'Back',
                              onPressed: () => Navigator.pop(context),
                            ),
                            _RoundIconButton(
                              icon: isFav
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              tooltip: isFav
                                  ? 'Remove from favorites'
                                  : 'Add to favorites',
                              iconColor: isFav
                                  ? const Color(0xFFF87171)
                                  : Colors.white,
                              onPressed: () => _toggleFavorite(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _Cover(book: book),
                        const SizedBox(height: 22),
                        Text(
                          book.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Georgia',
                            fontFamilyFallback: ['serif'],
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'by ${book.author}',
                          textAlign: TextAlign.center,
                          style: text.titleMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            book.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats card
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Palette.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x2655161D)),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _Stat(
                                  icon: Icons.auto_stories_outlined,
                                  value: book.pages?.toString() ?? '—',
                                  label: 'Pages',
                                ),
                              ),
                              const _StatDivider(),
                              Expanded(
                                child: _Stat(
                                  icon: Icons.calendar_today_outlined,
                                  value: _yearLabel,
                                  label: 'Published',
                                ),
                              ),
                              const _StatDivider(),
                              Expanded(
                                child: _Stat(
                                  icon: Icons.inventory_2_outlined,
                                  value: '$left / ${book.totalCopies}',
                                  label: 'Copies left',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Availability banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: (isAvail ? Palette.slytherin : Palette.amber)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isAvail ? Icons.check_circle : Icons.schedule,
                              size: 20,
                              color:
                                  isAvail ? Palette.slytherin : Palette.amber,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isAvail
                                    ? 'Available now: $left of ${book.totalCopies} copies on the shelf'
                                    : 'All copies are on loan right now. Check back soon.',
                                style: text.bodyMedium?.copyWith(
                                  color: Palette.textDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Overview
                      if (book.description.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text('Overview',
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Palette.burgundy,
                            )),
                        const SizedBox(height: 10),
                        Text(book.description,
                            style: text.bodyLarge?.copyWith(
                              color: Palette.textDark,
                              height: 1.6,
                            )),
                      ],

                      // Details
                      if (book.publisher.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text('Details',
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Palette.burgundy,
                            )),
                        const SizedBox(height: 10),
                        _DetailRow(label: 'Publisher', value: book.publisher),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Widgets
class _Cover extends StatelessWidget {
  const _Cover({required this.book});
  final Book book;

  static const double width = 170;
  static const double height = 245;
  static const radius = BorderRadius.only(
    topLeft: Radius.circular(4),
    bottomLeft: Radius.circular(4),
    topRight: Radius.circular(12),
    bottomRight: Radius.circular(12),
  );

  // Book has no image
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
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  book.title,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Palette.gold,
                    fontFamily: 'Georgia',
                    fontFamilyFallback: const ['serif'],
                    fontWeight: FontWeight.w700,
                    fontSize: width * 0.12,
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
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.22),
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: Palette.burgundy),
        const SizedBox(height: 8),
        Text(value,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Palette.textDark,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: text.bodySmall?.copyWith(color: Palette.textMuted)),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: const Color(0x2655161D));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2655161D)),
      ),
      child: Row(
        children: [
          Text(label,
              style: text.bodyMedium?.copyWith(color: Palette.textMuted)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: text.bodyMedium?.copyWith(
                  color: Palette.textDark,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }
}