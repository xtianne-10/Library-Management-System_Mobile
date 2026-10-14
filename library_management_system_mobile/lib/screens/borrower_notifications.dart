import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';

const _red = Color(0xFFC0121F);
const _green = Color(0xFF0C7A43);

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _fmt(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _days(int n) => '$n ${n == 1 ? 'day' : 'days'}';

class BorrowerNote {
  const BorrowerNote(this.key, this.icon, this.title, this.sub, this.color,
      [this.at]);
  final DateTime? at;
  final String key;
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
}

// Keys of notifications the borrower has already opened (this session)
final Set<String> _seen = {};
final Set<String> _cleared = {};

List<BorrowerNote> borrowerNotifications() {
  final me = AuthService.instance.currentUser?.email ?? '';
  final lib = LibraryService.instance;
  final today = _day(DateTime.now());
  bool recent(DateTime? d) =>
      d != null && today.difference(_day(d)).inDays <= 7;

  final loans = lib.recordsOf(me);
  final active = loans.where((t) => !t.returned).toList();
  final requests = lib.requestsOf(me);
  final out = <BorrowerNote>[];

  for (final t in active.where((t) => t.overdue)) {
    out.add(BorrowerNote(
        'overdue|${t.id}',
        Icons.warning_amber_rounded,
        'Overdue: ${t.title}',
        '${_days(t.daysOverdue)} late · fine ₱${t.fine.toStringAsFixed(2)}',
        _red));
  }
  for (final t in loans.where((t) => t.returned && t.fine > 0 && !t.finePaid)) {
    out.add(BorrowerNote(
        'fine|${t.id}',
        Icons.payments_outlined,
        'Unpaid fine: ₱${t.fine.toStringAsFixed(2)}',
        '${t.title} was returned late. Please settle it with the librarian.',
        _red));
  }
  for (final t in active.where(
      (t) => !t.overdue && _day(t.due).difference(today).inDays <= 2)) {
    final d = _day(t.due).difference(today).inDays;
    out.add(BorrowerNote(
        'soon|${t.id}',
        Icons.schedule,
        'Due soon: ${t.title}',
        d <= 0 ? 'Due today.' : 'Due in ${_days(d)} (${_fmt(t.due)}).',
        Palette.amber));
  }
  for (final r in requests
      .where((r) => r.declined && recent(r.decidedOn ?? r.requestedOn))) {
    out.add(BorrowerNote(
        'declined|${r.id}',
        Icons.cancel_outlined,
        'Request declined: ${r.book.title}',
        r.declineReason.isEmpty
            ? 'No reason was given.'
            : 'Reason: ${r.declineReason}',
        _red,
        r.decidedOn ?? r.requestedOn));
  }
  for (final t in active.where((t) => recent(t.borrowedOn))) {
    out.add(BorrowerNote('approved|${t.id}', Icons.check_circle_outline,
        'Borrow approved: ${t.title}', 'Due ${_fmt(t.due)}.', _green,
        t.borrowedOn));
  }
  for (final r in requests.where((r) => !r.declined)) {
    out.add(BorrowerNote('pending|${r.id}', Icons.hourglass_top_rounded,
        'Request sent: ${r.book.title}', 'Waiting for librarian approval.',
        Palette.amber, r.requestedOn));
  }
  for (final t in loans.where((t) => t.returned && recent(t.returnedOn))) {
    out.add(BorrowerNote('returned|${t.id}', Icons.assignment_return_outlined,
        'Returned: ${t.title}', 'Returned on ${_fmt(t.returnedOn!)}.', _green,
        t.returnedOn));
  }
  // Alerts that need action stay on top; the rest go newest first
  final alerts = out.where((n) => n.at == null).toList();
  final events = out.where((n) => n.at != null).toList()
    ..sort((a, b) => b.at!.compareTo(a.at!));
  return [...alerts, ...events]
      .where((n) => !_cleared.contains(n.key))
      .toList();
}

int unseenBorrowerCount() =>
    borrowerNotifications().where((n) => !_seen.contains(n.key)).length;

void markBorrowerNotesSeen() =>
    _seen.addAll(borrowerNotifications().map((n) => n.key));

void clearBorrowerNotes() =>
    _cleared.addAll(borrowerNotifications().map((n) => n.key));

class BorrowerNotificationsScreen extends StatefulWidget {
  const BorrowerNotificationsScreen({super.key});

  @override
  State<BorrowerNotificationsScreen> createState() =>
      _BorrowerNotificationsScreenState();
}

class _BorrowerNotificationsScreenState
    extends State<BorrowerNotificationsScreen> {
  static const _size = 8;
  int _page = 0;
  late final Set<String> _fresh;

  @override
  void initState() {
    super.initState();
    _fresh = {
      for (final n in borrowerNotifications())
        if (!_seen.contains(n.key)) n.key,
    };
    markBorrowerNotesSeen();
    LibraryService.instance.reload();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.page,
        appBar: AppBar(
          backgroundColor: Palette.burgundy,
          foregroundColor: Palette.creamLight,
          title: const Text('Notifications',
              style: TextStyle(
                  fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
          actions: [
            TextButton(
              onPressed: () => setState(clearBorrowerNotes),
              style: TextButton.styleFrom(foregroundColor: Palette.creamLight),
              child: const Text('Clear all'),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: LibraryService.instance,
          builder: (context, _) {
            final notes = borrowerNotifications();
            final pages = (notes.length / _size).ceil();
            final page = pages <= 1 ? 0 : _page.clamp(0, pages - 1);
            final shown = notes.skip(page * _size).take(_size).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  notes.isEmpty
                      ? 'Nothing needs your attention.'
                      : '${notes.length} ${notes.length == 1 ? 'notification' : 'notifications'}',
                  style: const TextStyle(color: Palette.textMuted),
                ),
                const SizedBox(height: 14),
                if (notes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Palette.cream.withAlpha(110),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Palette.burgundy.withAlpha(50)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.verified_outlined, color: _green),
                        SizedBox(width: 10),
                        Text("You're all caught up.",
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                else ...[
                  for (final n in shown)
                    Card(
                      elevation: 0,
                      color: Palette.card,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        side: BorderSide(color: Color(0x2655161D)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: n.color.withAlpha(30),
                          child: Icon(n.icon, color: n.color, size: 20),
                        ),
                        title: Text(n.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(n.sub),
                        trailing: _fresh.contains(n.key)
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Palette.burgundy,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: const Text('New',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700)),
                              )
                            : null,
                      ),
                    ),
                  if (pages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Previous page',
                          onPressed:
                              page > 0 ? () => setState(() => _page = page - 1) : null,
                          icon: const Icon(Icons.chevron_left),
                          color: Palette.burgundy,
                        ),
                        Text('Page ${page + 1} of $pages',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        IconButton(
                          tooltip: 'Next page',
                          onPressed: page < pages - 1
                              ? () => setState(() => _page = page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          color: Palette.burgundy,
                        ),
                      ],
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}