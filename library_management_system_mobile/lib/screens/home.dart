import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/app_nav_bar.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';
import 'package:library_management_system_mobile/screens/book_details.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Book> _books = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LibraryService.instance.ensureLoaded().then((books) {
      if (!mounted) return;
      setState(() {
        _books = books;
        _loading = false;
      });
    }).catchError((Object e) {
      debugPrint('Failed to load books: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  // Featured picks: popular or new, available, and not already borrowed
  List<Book> get _recommended {
    final store = BorrowStore.instance;
    return _books
        .where((b) =>
            (b.isPopular || b.isNewArrival) &&
            store.isAvailable(b) &&
            !store.isBorrowed(b))
        .take(8)
        .toList();
  }

  // Pass tab: 'pending' to open My Books on the Pending tab
  void _goMyBooks({String? tab}) =>
      Navigator.pushReplacementNamed(context, '/mybooks', arguments: tab);
  void _goExplore() => Navigator.pushReplacementNamed(context, '/explore');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.of(context).padding.top;
    final user = AuthService.instance.currentUser;
    final firstName = (user?.firstName.trim().isNotEmpty ?? false)
        ? user!.firstName.trim()
        : 'Reader';

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
        bottomNavigationBar: AppNavBar(currentIndex: 0),
      );
    }

    final recommended = _recommended;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Welcome header
            Container(
              padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 24),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_greeting()}, $firstName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Palette.creamLight,
                            )),
                        const SizedBox(height: 2),
                        Text('Knowledge is the truest magic.',
                            style: text.bodyMedium?.copyWith(
                              color: Palette.creamMuted,
                            )),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Palette.cream,
                    backgroundImage: user?.avatar != null
                        ? MemoryImage(user!.avatar!)
                        : null,
                    child: user?.avatar == null
                        ? Text(
                            user?.initial ?? '?',
                            style: const TextStyle(
                              color: Palette.burgundy,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Borrowing summary + pending shortcut
            ListenableBuilder(
              listenable: BorrowStore.instance,
              builder: (context, _) {
                final store = BorrowStore.instance;
                final pending = store.myPendingRequests.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _SummaryCard(
                        borrowed: store.items.length,
                        pending: pending,
                        overdue: store.overdue.length,
                        returned: store.history.length,
                        onTap: () => _goMyBooks(),
                      ),
                      if (pending > 0) ...[
                        const SizedBox(height: 12),
                        _PendingBanner(
                          count: pending,
                          onTap: () => _goMyBooks(tab: 'pending'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Due soon (nearest one + a link)
            _SectionTitle('Due soon', onSeeAll: () => _goMyBooks()),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: BorrowStore.instance,
              builder: (context, _) {
                final loans = BorrowStore.instance.items;
                if (loans.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                        'No borrowed books yet. Head to Explore to find one.'),
                  );
                }
                final next =
                    loans.reduce((a, b) => a.dueOn.isBefore(b.dueOn) ? a : b);
                final more = loans.length - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DueSoonCard(book: next.book, daysLeft: next.daysLeft),
                      if (more > 0)
                        TextButton(
                          onPressed: () => _goMyBooks(),
                          child: Text('+ $more more on loan'),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Recommended
            _SectionTitle('Recommended for you', onSeeAll: _goExplore),
            const SizedBox(height: 12),
            if (recommended.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('No recommendations right now.'),
              )
            else
              SizedBox(
                height: 250,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: recommended.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) => _BookTile(book: recommended[i]),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
        bottomNavigationBar: const AppNavBar(currentIndex: 0),
      ),
    );
  }
}

// Widgets

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.onSeeAll});
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Palette.burgundy,
                  ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: const Text('See all')),
        ],
      ),
    );
  }
}

// Borrowing summary

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.borrowed,
    required this.pending,
    required this.overdue,
    required this.returned,
    required this.onTap,
  });

  final int borrowed;
  final int pending;
  final int overdue;
  final int returned;
  final VoidCallback onTap;

  Widget _stat(BuildContext context, int value, String label, {Color? color}) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color ?? Palette.burgundy,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: text.bodySmall?.copyWith(color: Palette.textMuted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x2655161D)),
          ),
          child: Row(
            children: [
              _stat(context, borrowed, 'Borrowed'),
              _stat(context, pending, 'Pending',
                  color: pending == 0 ? null : Palette.amber),
              _stat(context, overdue, 'Overdue',
                  color: overdue == 0 ? null : Colors.red.shade700),
              _stat(context, returned, 'Returned'),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.chevron_right, color: Palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Pending requests shortcut

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: Palette.amber.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 1
                      ? '1 request waiting for approval'
                      : '$count requests waiting for approval',
                  style: text.bodyMedium?.copyWith(
                    color: Palette.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text('View',
                  style: text.bodyMedium?.copyWith(
                    color: Palette.burgundy,
                    fontWeight: FontWeight.w700,
                  )),
              const Icon(Icons.chevron_right, color: Palette.burgundy),
            ],
          ),
        ),
      ),
    );
  }
}

// Book Cover

class _BookCover extends StatelessWidget {
  const _BookCover({required this.book, this.width = 120, this.height = 170});

  final Book book;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(book.color);
    final spine = hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0));

    return Container(
      width: width,
      height: height,
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
                    fontSize: width * 0.13,
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
}

// Recommended tile

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 120,
      child: InkWell(
        onTap: () => openBookDetails(context, book),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookCover(book: book),
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
          ],
        ),
      ),
    );
  }
}

// Due Soon Card

class _DueSoonCard extends StatelessWidget {
  const _DueSoonCard({required this.book, required this.daysLeft});

  final Book book;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.burgundy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _BookCover(book: book, width: 64, height: 92),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Palette.creamLight,
                    )),
                Text(book.author,
                    style: text.bodyMedium
                        ?.copyWith(color: Palette.creamMuted)),
                const SizedBox(height: 8),
                Text(
                    daysLeft < 0
                        ? '${-daysLeft} days overdue'
                        : 'Due in $daysLeft days',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Palette.cream,
                    )),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.amber,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {},
                  child: const Text('Renew'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}