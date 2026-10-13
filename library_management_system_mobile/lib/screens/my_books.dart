import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/app_nav_bar.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/screens/book_details.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';

enum _Filter {
  current('Current'),
  pending('Pending'),
  overdue('Overdue'),
  history('History');

  const _Filter(this.label);
  final String label;
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _fmt(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

const _cardColor = Colors.white;
const _cardBorder = Color(0x1A000000);

ButtonStyle _detailsButtonStyle() => FilledButton.styleFrom(
      backgroundColor: Palette.burgundy,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

class MyBooksScreen extends StatefulWidget {
  const MyBooksScreen({super.key});

  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen> {
  _Filter _filter = _Filter.current;
  bool _argsRead = false;

  @override
  void initState() {
    super.initState();
    LibraryService.instance.reload();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == 'pending') _filter = _Filter.pending;
    if (args == 'history') _filter = _Filter.history;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.page,
        body: ListenableBuilder(
          listenable: BorrowStore.instance,
          builder: (context, _) {
            final store = BorrowStore.instance;
            final pendingReqs = store.myPendingRequests;
            final counts = {
              _Filter.current: store.current.length,
              _Filter.pending: pendingReqs.length,
              _Filter.overdue: store.overdue.length,
              _Filter.history:
                  store.history.length + store.myDeclinedRequests.length,
            };
            final activeCount = store.items.length;
            final overdueCount = store.overdue.length;
            final pendingCount = pendingReqs.length;

            final summaryParts = <String>[
              if (activeCount > 0) '$activeCount borrowed',
              if (overdueCount > 0) '$overdueCount overdue',
              if (pendingCount > 0) '$pendingCount pending',
            ];
            final summary = summaryParts.isEmpty
                ? 'Nothing borrowed right now.'
                : summaryParts.join('  •  ');

            // Body for the selected tab
            Widget list;
            if (_filter == _Filter.pending) {
              list = pendingReqs.isEmpty
                  ? _EmptyState(filter: _filter)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      itemCount: pendingReqs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => _RequestCard(
                        key: ValueKey(pendingReqs[i].id),
                        request: pendingReqs[i],
                      ),
                    );
            } else if (_filter == _Filter.history) {
              // returned loans + declined requests, newest first
              final entries = <(DateTime, Widget)>[
                for (final l in store.history)
                  (l.returnedOn!, _LoanCard(key: ValueKey('l${l.txId}'), loan: l)),
                for (final d in store.myDeclinedRequests)
                  (
                    d.decidedOn ?? d.requestedOn,
                    _DeclinedCard(key: ValueKey('d${d.id}'), request: d)
                  ),
              ]..sort((a, b) => b.$1.compareTo(a.$1));
              list = entries.isEmpty
                  ? _EmptyState(filter: _filter)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => entries[i].$2,
                    );
            } else {
              final loans = switch (_filter) {
                _Filter.current => store.current,
                _Filter.overdue => store.overdue,
                _Filter.history => store.history,
                _Filter.pending => const <BorrowedBook>[],
              };
              list = loans.isEmpty
                  ? _EmptyState(filter: _filter)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      itemCount: loans.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) => _LoanCard(
                        key: ValueKey(loans[i].txId),
                        loan: loans[i],
                      ),
                    );
            }

            return Column(
              children: [
                // Header: title + summary + segmented tabs
                Container(
                  width: double.infinity,
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
                      Text('My books',
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Palette.creamLight,
                          )),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: text.bodyMedium
                            ?.copyWith(color: Palette.creamMuted),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0x26FFFFFF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            for (final f in _Filter.values)
                              Expanded(
                                child: _SegmentButton(
                                  label: f.label,
                                  count: counts[f]!,
                                  selected: f == _filter,
                                  alert: f == _Filter.overdue &&
                                      counts[f]! > 0,
                                  onTap: () {
                                    setState(() => _filter = f);
                                    if (f == _Filter.history) {
                                      BorrowStore.instance.markDeclinedSeen();
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(child: list),
              ],
            );
          },
        ),
        bottomNavigationBar: const AppNavBar(currentIndex: 2),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.alert,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final bool alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? Palette.cream : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),

        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: selected ? Palette.burgundy : Palette.creamLight,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: alert
                      ? Colors.red.shade700
                      : selected
                          ? Palette.burgundy
                          : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    final (icon, message) = switch (filter) {
      _Filter.current => (Icons.auto_stories_outlined, 'No current loans.'),
      _Filter.pending => (Icons.hourglass_empty, 'No pending requests.'),
      _Filter.overdue => (Icons.task_alt, 'No overdue books.'),
      _Filter.history => (Icons.history, 'No returned books yet.'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Palette.burgundy),
          const SizedBox(height: 12),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Palette.textDark)),
        ],
      ),
    );
  }
}

// Shared collapsible card used by loans and declined requests
class _ExpandableCard extends StatefulWidget {
  const _ExpandableCard({
    super.key,
    required this.book,
    required this.statusLabel,
    required this.statusColor,
    required this.cardColor,
    required this.borderColor,
    required this.summary,
    required this.summaryColor,
    required this.details,
    required this.actions,
    this.progress,
    this.progressColor,
  });

  final Book book;
  final String statusLabel;
  final Color statusColor;
  final Color cardColor;
  final Color borderColor;
  final String summary;
  final Color summaryColor;
  final double? progress; // null hides the bar
  final Color? progressColor;
  final List<Widget> details; // rows shown when expanded
  final List<Widget> actions; // buttons shown when expanded

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final book = widget.book;

    return Container(
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.borderColor),
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
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MiniCover(book: book),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: widget.statusColor.withAlpha(31),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(widget.statusLabel,
                                    style: text.labelSmall?.copyWith(
                                      color: widget.statusColor,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    )),
                              ),
                              const Spacer(),
                              AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: const Icon(Icons.expand_more,
                                    color: Palette.burgundy),
                              ),
                            ],
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
                          if (widget.progress != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: widget.progress,
                                minHeight: 6,
                                backgroundColor: const Color(0x1A55161D),
                                color: widget.progressColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(widget.summary,
                              style: text.bodySmall?.copyWith(
                                color: widget.summaryColor,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: !_expanded
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          children: [
                            const SizedBox(height: 14),
                            const Divider(height: 1, color: Color(0x2655161D)),
                            const SizedBox(height: 12),
                            ...widget.details,
                            const SizedBox(height: 12),
                            Row(children: widget.actions),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Pending request card

class _RequestCard extends StatelessWidget {
  const _RequestCard({super.key, required this.request});
  final BorrowRequest request;

  @override
  Widget build(BuildContext context) {
    final book = request.book;
    final text = Theme.of(context).textTheme;
    const statusColor = Palette.amber;

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MiniCover(book: book),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(31),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('PENDING',
                            style: text.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
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
                      Text('Requested ${_fmt(request.requestedOn)}',
                          style: text.bodySmall?.copyWith(
                            color: Palette.textDark,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      Text('Waiting for librarian approval',
                          style: text.bodySmall
                              ?.copyWith(color: Palette.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => openBookDetails(context, book),
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.white, backgroundColor: Palette.burgundy, elevation: 0,
                      side: const BorderSide(color: Palette.burgundy),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final err =
                          await BorrowStore.instance.cancelRequest(request);
                      messenger
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text(err ??
                              'Request cancelled for "${book.title}".'),
                        ));
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel request'),
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

// Declined request card

class _DeclinedCard extends StatelessWidget {
  const _DeclinedCard({super.key, required this.request});
  final BorrowRequest request;

  @override
  Widget build(BuildContext context) {
    final red = Colors.red.shade700;
    final declinedOn = request.decidedOn ?? request.requestedOn;

    return _ExpandableCard(
      book: request.book,
      statusLabel: 'DECLINED',
      statusColor: red,
      cardColor: const Color.fromARGB(255, 235, 235, 235),
      borderColor: red.withAlpha(90),
      summary: 'Declined ${_fmt(declinedOn)}',
      summaryColor: red,
      details: [
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'Requested',
          value: _fmt(request.requestedOn),
        ),
        _InfoRow(
          icon: Icons.block,
          label: 'Declined',
          value: _fmt(declinedOn),
          color: red,
        ),
      ],
      actions: [
        Expanded(
          child: FilledButton(
            onPressed: () => openBookDetails(context, request.book),
            style: _detailsButtonStyle(),
            child: const Text('View Details'),
          ),
        ),
      ],
    );
  }
}

// Loan card

class _LoanCard extends StatefulWidget {
  const _LoanCard({super.key, required this.loan});
  final BorrowedBook loan;

  @override
  State<_LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<_LoanCard> {
  bool _expanded = false;
  bool _returning = false;

  Future<void> _return() async {
    final loan = widget.loan;
    final messenger = ScaffoldMessenger.of(context);
    final fine = loan.fine;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Return this book?'),
        content: Text(loan.isOverdue
            ? '"${loan.book.title}" is ${loan.daysOverdue} ${loan.daysOverdue == 1 ? 'day' : 'days'} overdue. A fine of ₱${fine.toStringAsFixed(2)} applies.'
            : 'Return "${loan.book.title}" to the library?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Return')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _returning = true);
    final err = await BorrowStore.instance.giveBackLoan(loan);
    if (mounted) setState(() => _returning = false);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(err ??
            (fine > 0
                ? 'Returned "${loan.book.title}". Fine due: ₱${fine.toStringAsFixed(2)}.'
                : 'Returned "${loan.book.title}".')),
      ));
  }

    @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final red = Colors.red.shade700;

    final (statusLabel, statusColor) = loan.isReturned
        ? ('RETURNED', Palette.textMuted)
        : loan.isOverdue
            ? ('OVERDUE', red)
            : ('BORROWED', Palette.slytherin);

    final summary = loan.isReturned
        ? 'Returned ${_fmt(loan.returnedOn!)}'
        : loan.isOverdue
            ? '${loan.daysOverdue} ${loan.daysOverdue == 1 ? 'day' : 'days'} overdue'
            : loan.daysLeft == 0
                ? 'Due today'
                : '${loan.daysLeft} ${loan.daysLeft == 1 ? 'day' : 'days'} remaining';

    final progress = loan.isOverdue
        ? 1.0
        : ((BorrowStore.loanDays - loan.daysLeft) / BorrowStore.loanDays)
            .clamp(0.0, 1.0);

    return _ExpandableCard(
      book: loan.book,
      statusLabel: statusLabel,
      statusColor: statusColor,
      cardColor: _cardColor,
      borderColor: loan.isOverdue ? red : _cardBorder,
      summary: summary,
      summaryColor: loan.isOverdue ? red : Palette.textDark,
      progress: loan.isReturned ? null : progress,
      progressColor: loan.isOverdue
          ? red
          : progress > 0.8
              ? Palette.amber
              : Palette.slytherin,
      details: [
        _InfoRow(
          icon: Icons.event_available_outlined,
          label: 'Borrowed',
          value: _fmt(loan.borrowedOn),
        ),
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'Due',
          value: _fmt(loan.dueOn),
          color: loan.isOverdue ? red : null,
        ),
        if (loan.isOverdue)
          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Fine',
            value: '₱${loan.fine.toStringAsFixed(2)}',
            color: red,
            bold: true,
          ),
      ],
      actions: [
        Expanded(
          child: FilledButton(
            onPressed: () => openBookDetails(context, loan.book),
            style: _detailsButtonStyle(),
            child: const Text('View Details'),
          ),
        ),
        if (!loan.isReturned) ...[
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _returning ? null : _return,
              style: _detailsButtonStyle().copyWith(
                backgroundColor: WidgetStatePropertyAll(Palette.slytherin),
              ),
              child: _returning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Return'),
            ),
          ),
        ],
      ],
    );
  }
}


class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Palette.textDark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Palette.burgundy),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Palette.textMuted)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: c,
              )),
        ],
      ),
    );
  }
}

class _MiniCover extends StatelessWidget {
  const _MiniCover({required this.book});
  final Book book;

  static const double width = 64;
  static const double height = 92;
  static const radius = BorderRadius.all(Radius.circular(6));

  // Used when the book has no image or it fails to load
  Widget _fallback() => Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(6),
        color: book.color,
        child: Text(
          book.title,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Palette.gold,
            fontFamily: 'Georgia',
            fontFamilyFallback: ['serif'],
            fontWeight: FontWeight.w700,
            fontSize: 10,
            height: 1.2,
          ),
        ),
      );

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
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: content),
    );
  }
}