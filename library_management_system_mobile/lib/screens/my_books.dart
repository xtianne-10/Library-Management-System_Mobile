import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: Palette.page,
      appBar: AppBar(
        title: const Text('My books'),
        backgroundColor: Colors.transparent,
        foregroundColor: Palette.burgundy,
        elevation: 0,
      ),
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

          return Column(
            children: [
              // Tab buttons
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _Filter.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = _Filter.values[i];
                    final selected = f == _filter;
                    final color =
                        f == _Filter.overdue ? Colors.red.shade700 : Palette.burgundy;
                    return ChoiceChip(
                      label: Text('${f.label} (${lists[f]!.length})'),
                      selected: selected,
                      showCheckmark: false,
                      backgroundColor: Palette.page,
                      selectedColor: color,
                      side: BorderSide(color: color, width: 1.2),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : color,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _filter = f),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // List
              Expanded(
                child: loans.isEmpty
                    ? Center(
                        child: Text(switch (_filter) {
                          _Filter.current => 'No current loans.',
                          _Filter.overdue => 'No overdue books.',
                          _Filter.history => 'No returned books yet.',
                        }),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: loans.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _LoanCard(
                          key: ObjectKey(loans[i]),
                          loan: loans[i],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 2),
    );
  }
}

// Loan card: collapsed by default, tap to expand

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

    final (statusLabel, statusColor) = loan.isReturned
        ? ('RETURNED', Palette.textMuted)
        : loan.isOverdue
            ? ('OVERDUE', Colors.red.shade700)
            : ('BORROWED', Palette.slytherin);

    final summary = loan.isReturned
        ? 'Returned ${_fmt(loan.returnedOn!)}'
        : loan.isOverdue
            ? '${loan.daysOverdue} ${loan.daysOverdue == 1 ? 'day' : 'days'} overdue'
            : loan.daysLeft == 0
                ? 'Due today'
                : '${loan.daysLeft} ${loan.daysLeft == 1 ? 'day' : 'days'} remaining';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Palette.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: loan.isOverdue
              ? Colors.red.shade700
              : const Color(0x2655161D),
        ),
      ),
      child: InkWell(
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
                        Text(loan.book.title,
                            maxLines: _expanded ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Palette.textDark,
                            )),
                        const SizedBox(height: 2),
                        Text(loan.book.author,
                            style: text.bodyMedium
                                ?.copyWith(color: Palette.textMuted)),

                        // Extra details, only when expanded
                        if (_expanded) ...[
                          const SizedBox(height: 8),
                          Text('Borrowed: ${_fmt(loan.borrowedOn)}',
                              style: text.bodySmall
                                  ?.copyWith(color: Palette.textDark)),
                          Text('Due: ${_fmt(loan.dueOn)}',
                              style: text.bodySmall
                                  ?.copyWith(color: Palette.textDark)),
                        ],

                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: statusColor),
                            const SizedBox(width: 6),
                            Text(statusLabel,
                                style: text.labelMedium?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                )),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(summary,
                            style: text.bodySmall?.copyWith(
                              color: loan.isOverdue
                                  ? Colors.red.shade700
                                  : Palette.textDark,
                              fontWeight: FontWeight.w600,
                            )),
                        if (_expanded && loan.isOverdue)
                          Text('Fine: ₱${loan.fine.toStringAsFixed(2)}',
                              style: text.bodySmall?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w700,
                              )),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Palette.burgundy,
                  ),
                ],
              ),

              // Buttons, only when expanded
              if (_expanded) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => showBookDetails(context, loan.book),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.burgundy,
                          side: const BorderSide(color: Palette.burgundy),
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                    if (!loan.isReturned) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              BorrowStore.instance.giveBack(loan.book),
                          style: FilledButton.styleFrom(
                            backgroundColor: Palette.burgundy,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Return'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
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