import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:library_management_system_mobile/models/book.dart';
import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';

class VerifyReturnScreen extends StatefulWidget {
  const VerifyReturnScreen({super.key});

  @override
  State<VerifyReturnScreen> createState() => _VerifyReturnScreenState();
}

class _VerifyReturnScreenState extends State<VerifyReturnScreen> {
  final _lib = LibraryService.instance;
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _code = TextEditingController();
  int _mode = 0;
  bool _busy = false;
  String? _error;
  String? _success;
  BookTransaction? _tx;
  String _lastText = '';
  DateTime _lastAt = DateTime(2000);

  @override
  void dispose() {
    _scanner.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify(String raw) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });

    // Loans waiting for return verification before we verify
    final pendingIds =
        _lib.transactions.where((t) => t.pendingReturn).map((t) => t.id).toSet();

    final (err, summary) = await _lib.verifyReturn(raw);

    // Reload, then find which pending loan is now returned
    BookTransaction? done;
    if (err == null) {
      await _lib.reload();
      final matches = _lib.transactions
          .where((t) => pendingIds.contains(t.id) && t.returned)
          .toList()
        ..sort((a, b) => (b.returnedOn ?? DateTime(2000))
            .compareTo(a.returnedOn ?? DateTime(2000)));
      if (matches.isNotEmpty) done = matches.first;
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _success = summary;
      _tx = done;
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _success != null) return;
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    final now = DateTime.now();
    if (raw == _lastText && now.difference(_lastAt).inSeconds < 3) return;
    _lastText = raw;
    _lastAt = now;
    _verify(raw);
  }

  void _submitManual() {
    final v = _code.text.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{8}$').hasMatch(v)) {
      setState(() => _error = 'Enter the 8-digit verification number.');
      return;
    }
    _verify(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.page,
      appBar: AppBar(
        backgroundColor: Palette.burgundy,
        foregroundColor: Palette.creamLight,
        title: const Text('Verify Return',
            style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (_success != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0C7A43).withAlpha(25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF0C7A43).withAlpha(90)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 56, color: Color(0xFF0C7A43)),
                  const SizedBox(height: 8),
                  const Text('Return confirmed',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_success!, textAlign: TextAlign.center),
                ],
              ),
            ),
            if (_tx != null) ...[
              const SizedBox(height: 14),
              _ReturnDetails(tx: _tx!),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() {
                _success = null;
                _tx = null;
                _error = null;
                _code.clear();
              }),
              style: FilledButton.styleFrom(backgroundColor: Palette.burgundy),
              child: const Text('Verify another'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, _success),
              child: const Text('Done'),
            ),
          ] else ...[
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.qr_code_scanner),
                    label: Text('Scan QR')),
                ButtonSegment(
                    value: 1, icon: Icon(Icons.pin), label: Text('Enter number')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                if (s.first == 1) _scanner.stop().catchError((_) {});
                setState(() {
                  _mode = s.first;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_mode == 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 320,
                  child: MobileScanner(controller: _scanner, onDetect: _onDetect),
                ),
              ),
              const SizedBox(height: 10),
              const Text("Point the camera at the borrower's QR code.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.textMuted)),
            ] else ...[
              TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 9,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 4),
                decoration: const InputDecoration(
                    labelText: 'Verification number',
                    hintText: '1234 5678',
                    border: OutlineInputBorder()),
                onSubmitted: (_) => _submitManual(),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _submitManual,
                style: FilledButton.styleFrom(backgroundColor: Palette.amber),
                child: Text(_busy ? 'Verifying...' : 'Verify'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFC0121F), fontWeight: FontWeight.w600)),
            ],
          ],
        ],
      ),
    );
  }
}


String _d(DateTime? d) {
  const m = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  return d == null ? '-' : '${m[d.month - 1]} ${d.day}, ${d.year}';
}

class _ReturnDetails extends StatelessWidget {
  const _ReturnDetails({required this.tx});
  final BookTransaction tx;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFC0121F);
    const green = Color(0xFF0C7A43);
    final t = tx;

    Book? book;
    for (final b in LibraryService.instance.books) {
      if (b.id == t.bookId) {
        book = b;
        break;
      }
    }

    Widget cover() {
      final placeholder = Container(
        width: 64,
        height: 92,
        color: book?.color ?? Palette.burgundy,
      );
      final url = book?.imageUrl.trim() ?? '';
      Widget img = placeholder;
      if (book?.imageBytes != null) {
        img = Image.memory(book!.imageBytes!,
            width: 64, height: 92, fit: BoxFit.cover);
      } else if (url.isNotEmpty) {
        img = Image.network(url,
            width: 64,
            height: 92,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder);
      }
      return ClipRRect(borderRadius: BorderRadius.circular(4), child: img);
    }

    Widget cell(String label, String value) => SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Palette.textMuted)),
              Text(value.isEmpty ? '-' : value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    final cat = book == null
        ? ''
        : '${book.category}${book.subcategory.isNotEmpty ? ' · ${book.subcategory}' : ''}';

    final late = t.daysOverdue;
    final rate = LibraryService.finePerDay;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x334A1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Book
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cover(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Palette.burgundy)),
                    if (book != null)
                      Text('by ${book.author}',
                          style: const TextStyle(
                              fontSize: 13, color: Palette.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          if (book != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                cell('Category', cat),
                cell('Publisher', book.publisher),
                cell('ISBN', book.isbn),
                cell('Pages', book.pages == null ? '' : '${book.pages}'),
                cell('Shelf / Location', book.shelf),
              ],
            ),
          ],
          const Divider(height: 24, color: Color(0x1A4A1F1F)),

          // Borrower + dates
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              cell('Returned by', t.borrower),
              cell('Email', t.borrowerEmail),
              cell('Borrowed on', _d(t.borrowedOn)),
              cell('Due date', _d(t.due)),
              cell('Returned on', _d(t.returnedOn)),
            ],
          ),
          const SizedBox(height: 14),

          // Fine computation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (t.fine > 0 ? red : green).withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: t.fine > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Late return',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: red)),
                      const SizedBox(height: 4),
                      Text(
                          '$late ${late == 1 ? 'day' : 'days'} late × '
                          '₱${rate.toStringAsFixed(2)}/day',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('Fine due: ₱${t.fine.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: red)),
                    ],
                  )
                : const Text('Returned on time. No fine.',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: green)),
          ),
        ],
      ),
    );
  }
}