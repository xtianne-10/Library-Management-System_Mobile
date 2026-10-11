import 'package:flutter/material.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';

class BorrowRequestsScreen extends StatelessWidget {
  const BorrowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.page,
      appBar: AppBar(
        title: const Text('Borrow requests'),
        backgroundColor: Palette.burgundy,
        foregroundColor: Palette.creamLight,
      ),
      body: ListenableBuilder(
        listenable: BorrowStore.instance,
        builder: (context, _) {
          final requests = BorrowStore.instance.pendingRequests;
          if (requests.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final r = requests[i];
              return Card(
                color: Palette.card,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0x2655161D)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.book.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text('Requested by ${r.email}',
                          style: const TextStyle(color: Palette.textMuted)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  BorrowStore.instance.decline(r),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Palette.burgundy),
                              onPressed: () {
                                final error =
                                    BorrowStore.instance.approve(r);
                                if (error != null) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                          content: Text(error)));
                                }
                              },
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}