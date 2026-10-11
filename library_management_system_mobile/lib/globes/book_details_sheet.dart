import 'package:flutter/material.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';
import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/theme/palette.dart';

void showBookDetails(BuildContext context, Book book) {
  final messenger = ScaffoldMessenger.of(context);

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
        if (book.year != null) book.year!.toString(),
        if (book.pages != null) '${book.pages} pages',
      ].join('  •  ');

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: ListenableBuilder(
            listenable: BorrowStore.instance,
            builder: (_, __) {
              final borrowed = BorrowStore.instance.isBorrowed(book);
              final left = BorrowStore.instance.copiesLeft(book);
              final isAvail = left > 0;
              final canBorrow = isAvail && !borrowed;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 90,
                        height: 130,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: book.color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(book.title,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Palette.gold,
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            )),
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isAvail ? Icons.check_circle : Icons.schedule,
                                  size: 16,
                                  color: isAvail ? Palette.slytherin : Palette.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAvail
                                      ? '$left of ${book.totalCopies} available'
                                      : 'On hold',
                                  style: text.bodySmall?.copyWith(color: Palette.textDark),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (book.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(book.description,
                        style: text.bodyMedium?.copyWith(
                            color: Palette.textDark, height: 1.4)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Palette.burgundy,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: borrowed
                          ? null // borrowed = disabled
                          : () {
                              Navigator.pop(sheetContext);
                              if (canBorrow) {
                                final ok = BorrowStore.instance.borrow(book);
                                messenger.showSnackBar(SnackBar(
                                  content: Text(ok
                                      ? 'Borrowed "${book.title}". Due in ${BorrowStore.loanDays} days.'
                                      : 'Can\'t borrow "${book.title}": limit reached or overdue books.'),
                                ));
                              } else {
                                messenger.showSnackBar(SnackBar(
                                  content: Text(
                                      'You\'re on the waitlist for "${book.title}".'),
                                ));
                              }
                            },
                      child: Text(borrowed
                        ? 'Already borrowed'
                        : isAvail
                            ? 'Borrow'
                            : 'Join waitlist'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}