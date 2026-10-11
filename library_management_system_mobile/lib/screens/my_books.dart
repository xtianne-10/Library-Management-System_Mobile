import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/app_nav_bar.dart';
import 'package:library_management_system_mobile/globes/book_details_sheet.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/theme/palette.dart';

enum _Filter {
  current('Current'),
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

class MyBooksScreen extends StatefulWidget {
  const MyBooksScreen({super.key});

  @override
  State<MyBooksScreen> createState() => _MyBooksScreenState();
}

class _MyBooksScreenState extends State<MyBooksScreen> {
  _Filter _filter = _Filter.current;

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
            final lists = {
              _Filter.current: store.current,
              _Filter.overdue: store.overdue,
              _Filter.history: store.history,
            };
            final loans = lists[_filter]!;
            final activeCount = store.items.length;
            final overdueCount = store.overdue.length;

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
                        overdueCount > 0
                            ? '$activeCount borrowed  •  $overdueCount overdue'
                            : activeCount == 0
                                ? 'Nothing borrowed right now.'
                                : '$activeCount borrowed',
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
                                  count: lists[f]!.length,
                                  selected: f == _filter,
                                  alert: f == _Filter.overdue &&
                                      lists[f]!.isNotEmpty,
                                  onTap: () => setState(() => _filter = f),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: loans.isEmpty
                      ? _EmptyState(filter: _filter)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                          itemCount: loans.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, i) => _LoanCard(
                            key: ValueKey(loans[i].txId),
                            loan: loans[i],
                          ),
                        ),
                ),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Palette.cream : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
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
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
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

class _LoanCard extends StatefulWidget {
  const _LoanCard({super.key, required this.loan});
  final BorrowedBook loan;

  @override
  State<_LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<_LoanCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final text = Theme.of(context).textTheme;
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

    // How much of the loan period has passed (0 to 1).
    final progress = loan.isOverdue
        ? 1.0
        : ((BorrowStore.loanDays - loan.daysLeft) / BorrowStore.loanDays)
            .clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: loan.isOverdue ? red : const Color(0x2655161D),
        ),
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
                    _MiniCover(book: loan.book),
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
                                  color: statusColor.withAlpha(31),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(statusLabel,
                                  style: text.labelSmall?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  )
                                ),
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
                          Text(loan.book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Palette.textDark,
                              )),
                          const SizedBox(height: 2),
                          Text(loan.book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium
                                  ?.copyWith(color: Palette.textMuted)),
                          const SizedBox(height: 10),
                          if (!loan.isReturned) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: const Color(0x1A55161D),
                                color: loan.isOverdue
                                    ? red
                                    : progress > 0.8
                                        ? Palette.amber
                                        : Palette.slytherin,
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Text(summary,
                              style: text.bodySmall?.copyWith(
                                color:
                                    loan.isOverdue ? red : Palette.textDark,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),

                // Expanded details
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: !_expanded
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          children: [
                            const SizedBox(height: 14),
                            const Divider(
                                height: 1, color: Color(0x2655161D)),
                            const SizedBox(height: 12),
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
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        showBookDetails(context, loan.book),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Palette.burgundy,
                                      side: const BorderSide(
                                          color: Palette.burgundy),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: const Text('View Details'),
                                  ),
                                ),
                                if (!loan.isReturned) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => BorrowStore.instance
                                          .giveBack(loan.book),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Palette.burgundy,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Return'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 92,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: book.color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        book.title,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Palette.gold,
          fontFamily: 'Georgia',
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}