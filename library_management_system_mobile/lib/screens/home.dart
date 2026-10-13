import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/app_nav_bar.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';
import 'package:library_management_system_mobile/screens/book_details.dart';
import 'package:library_management_system_mobile/widgets/book_cover.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

String _days(int n) => n == 1 ? 'day' : 'days';

// Shared surface styling so every card looks like part of one system.
const _cardBorder = Color(0x1A55161D);
const _cardShadow = [
  BoxShadow(
    color: Color(0x1255161D),
    blurRadius: 18,
    offset: Offset(0, 6),
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _lib = LibraryService.instance;
  bool _loading = LibraryService.instance.books.isEmpty;

  // Always read straight from the service (MongoDB via the API)
  List<Book> get _books => _lib.books;

  @override
  void initState() {
    super.initState();
    _lib.addListener(_refresh);
    // Re-fetch every time Home opens so web changes show up
    _lib.reload().whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _lib.removeListener(_refresh);
    super.dispose();
  }

  // Featured picks: available books the user isn't already borrowing, newest first
  List<Book> get _recommended {
    final email = AuthService.instance.currentUser?.email ?? '';
    final mine = _lib.activeLoansOf(email).map((t) => t.bookId).toSet();
    final list = _books
        .where((b) => _lib.isAvailable(b) && !mine.contains(b.id))
        .toList()
      ..sort((a, b) => (b.published ?? DateTime(0))
          .compareTo(a.published ?? DateTime(0)));
    return list.take(8).toList();
  }

  // Pass tab: 'pending' to open My Books on the Pending tab
  void _goMyBooks({String? tab}) =>
      Navigator.pushReplacementNamed(context, '/mybooks', arguments: tab);
  void _goExplore() => Navigator.pushReplacementNamed(context, '/explore');

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

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
            // Header + summary card that overlaps the header edge
            Stack(
              children: [
                Positioned.fill(
                  bottom: 44,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.burgundy,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 0),
                  child: Column(
                    children: [
                      _Header(onSearch: _goExplore),
                      const SizedBox(height: 24),
                      ListenableBuilder(
                        listenable: BorrowStore.instance,
                        builder: (context, _) {
                          final store = BorrowStore.instance;
                          return _SummaryCard(
                            borrowed: store.items.length,
                            pending: store.myPendingRequests.length,
                            overdue: store.overdue.length,
                            returned: store.history.length,
                            onTap: () => _goMyBooks(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Declined requests (until the borrower opens or dismisses them)
            ListenableBuilder(
              listenable: BorrowStore.instance,
              builder: (context, _) {
                final declined = BorrowStore.instance.unseenDeclined;
                if (declined.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _DeclinedBanner(
                    requests: declined,
                    onTap: () {
                      BorrowStore.instance.markDeclinedSeen();
                      _goMyBooks(tab: 'history');
                    },
                    onDismiss: BorrowStore.instance.markDeclinedSeen,
                  ),
                );
              },
            ),

            // Pending requests shortcut (only when there are some)
            ListenableBuilder(
              listenable: BorrowStore.instance,
              builder: (context, _) {
                final pending = BorrowStore.instance.myPendingRequests.length;
                if (pending == 0) return const SizedBox(height: 8);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _PendingBanner(
                    count: pending,
                    onTap: () => _goMyBooks(tab: 'pending'),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

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
                    child: _EmptyCard(
                      icon: Icons.menu_book_outlined,
                      message:
                          'No borrowed books yet. Head to Explore to find one.',
                    ),
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
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Palette.burgundy,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => _goMyBooks(),
                            child: Text('+ $more more on loan'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // Recommended
            _SectionTitle('Recommended for you', onSeeAll: _goExplore),
            const SizedBox(height: 14),
            if (recommended.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _EmptyCard(
                  icon: Icons.auto_stories_outlined,
                  message: 'No recommendations right now.',
                ),
              )
            else
              SizedBox(
                height: 262,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: recommended.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, i) => _BookTile(book: recommended[i]),
                ),
              ),
            const SizedBox(height: 28),
          ],
        ),
        bottomNavigationBar: const AppNavBar(currentIndex: 0),
      ),
    );
  }
}

// Header

class _Header extends StatelessWidget {
  const _Header({required this.onSearch});
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final user = AuthService.instance.currentUser;
    final firstName = (user?.firstName.trim().isNotEmpty ?? false)
        ? user!.firstName.trim()
        : 'Reader';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting().toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      color: Palette.creamMuted,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Palette.creamLight,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Palette.cream.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Palette.cream,
                backgroundImage:
                    user?.avatar != null ? MemoryImage(user!.avatar!) : null,
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
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Search shortcut: opens Explore
        Material(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onSearch,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: Palette.creamMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search books, authors, topics',
                      style: text.bodyMedium
                          ?.copyWith(color: Palette.creamMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Section title

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Palette.textDark,
                  ),
            ),
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
    );
  }
}

// Empty state

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: Palette.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Text(message,
                style: text.bodyMedium?.copyWith(color: Palette.textMuted)),
          ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color ?? Palette.burgundy,
                height: 1.1,
              )),
          const SizedBox(height: 4),
          Text(label,
              style: text.bodySmall?.copyWith(
                color: Palette.textMuted,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 32,
        color: const Color(0x1F55161D),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: _cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                _stat(context, borrowed, 'Borrowed'),
                _divider(),
                _stat(context, pending, 'Pending',
                    color: pending == 0 ? null : Palette.amber),
                _divider(),
                _stat(context, overdue, 'Overdue',
                    color: overdue == 0 ? null : Colors.red.shade700),
                _divider(),
                _stat(context, returned, 'Returned'),
              ],
            ),
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Palette.amber.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Palette.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded,
                    size: 18, color: Palette.amber),
              ),
              const SizedBox(width: 12),
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
              const Icon(Icons.chevron_right, color: Palette.burgundy),
            ],
          ),
        ),
      ),
    );
  }
}

// Declined requests notice

class _DeclinedBanner extends StatelessWidget {
  const _DeclinedBanner({
    required this.requests,
    required this.onTap,
    required this.onDismiss,
  });

  final List<BorrowRequest> requests;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final red = Colors.red.shade700;
    final message = requests.length == 1
        ? 'Your request for "${requests.first.book.title}" was declined'
        : '${requests.length} of your requests were declined';

    return Material(
      color: red.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: red.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, size: 22, color: red),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message,
                    style: text.bodyMedium?.copyWith(
                      color: Palette.textDark,
                      fontWeight: FontWeight.w600,
                    )),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
                color: Palette.textMuted,
              ),
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
  Widget build(BuildContext context) =>
      BookCover(book: book, width: width, height: height);
}

// Recommended tile

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book});
  final Book book;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pub = book.published;
    final badge = (pub != null && DateTime.now().difference(pub).inDays < 365)
        ? 'New'
        : null;

    return SizedBox(
      width: 130,
      child: InkWell(
        onTap: () => openBookDetails(context, book),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _BookCover(book: book, width: 130, height: 184),
                if (badge != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Palette.cream,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Palette.burgundy,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Palette.textDark,
                )),
            const SizedBox(height: 1),
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

    final overdue = daysLeft < 0;
    final soon = daysLeft <= 3;
    final statusColor = overdue
        ? Colors.red.shade700
        : soon
            ? Palette.amber
            : Colors.green.shade700;
    final statusLabel = overdue
        ? '${-daysLeft} ${_days(-daysLeft)} overdue'
        : daysLeft == 0
            ? 'Due today'
            : 'Due in $daysLeft ${_days(daysLeft)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorder),
        boxShadow: _cardShadow,
      ),
      child: Row(
        children: [
          _BookCover(book: book, width: 68, height: 98),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Palette.textDark,
                      height: 1.2,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 13, color: statusColor),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: text.labelMedium?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.burgundy,
                        side: const BorderSide(color: Palette.burgundy),
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () {},
                      child: const Text('Renew',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}