import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:library_management_system_mobile/services/library_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';

String _mmss(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

class ReturnQrScreen extends StatefulWidget {
  const ReturnQrScreen({super.key, required this.txId});
  final int txId;

  @override
  State<ReturnQrScreen> createState() => _ReturnQrScreenState();
}

class _ReturnQrScreenState extends State<ReturnQrScreen> {
  final _lib = LibraryService.instance;
  Timer? _tick;
  Timer? _poll;
  DateTime _now = DateTime.now();
  String? _error;
  bool _busy = false;

  BookTransaction? get _tx {
    for (final t in _lib.transactions) {
      if (t.id == widget.txId) return t;
    }
    return null;
  }

  bool _active(BookTransaction t) =>
      t.pendingReturn &&
      t.returnCode.isNotEmpty &&
      (t.returnExpires?.isAfter(DateTime.now()) ?? false);

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Picks up the librarian's verification
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _lib.reload());
    final t = _tx;
    if (t != null && !t.returned && !_active(t)) {
      _busy = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    if (mounted) setState(() { _busy = true; _error = null; });
    final err = await _lib.requestReturn(widget.txId);
    if (!mounted) return;
    setState(() { _busy = false; _error = err; });
  }

  Widget _center(List<Widget> children) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.page,
        appBar: AppBar(
          backgroundColor: Palette.burgundy,
          foregroundColor: Palette.creamLight,
          title: const Text('Return Book',
              style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.w700)),
        ),
        body: ListenableBuilder(
          listenable: _lib,
          builder: (context, _) {
            final t = _tx;
            if (t == null) {
              return _center([const Text('This loan is no longer active.')]);
            }
            if (t.returned) {
              return _center([
                const Icon(Icons.check_circle, size: 72, color: Color(0xFF0C7A43)),
                const SizedBox(height: 12),
                const Text('Return confirmed',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('The librarian verified your return of "${t.title}".',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(backgroundColor: Palette.burgundy),
                  child: const Text('Done'),
                ),
              ]);
            }

            final exp = t.returnExpires;
            final left = (t.pendingReturn && exp != null)
                ? exp.difference(_now).inSeconds
                : 0;
            final hasCode = t.pendingReturn && t.returnCode.isNotEmpty;
            final expired = hasCode && left <= 0;

            if (!hasCode && !_busy) {
              return _center([
                Text(_error ?? 'Your return code is not ready.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFC0121F))),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _generate,
                  style: FilledButton.styleFrom(backgroundColor: Palette.burgundy),
                  child: const Text('Generate code'),
                ),
              ]);
            }
            if (!hasCode) {
              return _center([const CircularProgressIndicator()]);
            }

            final code = t.returnCode;
            return _center([
              Text(t.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Status: Pending Return',
                  style: TextStyle(
                      color: Palette.amber, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 16),
              Opacity(
                opacity: expired ? 0.25 : 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x2655161D)),
                  ),
                  child: QrImageView(
                    data: 'HLRET:$code',
                    size: 220,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('VERIFICATION NUMBER',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: Palette.textMuted)),
              Text('${code.substring(0, 4)} ${code.substring(4)}',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(height: 6),
              Text(expired ? 'This code has expired.' : 'Expires in ${_mmss(left)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: expired ? const Color(0xFFC0121F) : Palette.textMuted)),
              const SizedBox(height: 14),
              if (expired)
                FilledButton(
                  onPressed: _busy ? null : _generate,
                  style: FilledButton.styleFrom(backgroundColor: Palette.burgundy),
                  child: Text(_busy ? 'Generating...' : 'Generate a new code'),
                )
              else
                const Text(
                  'Show this to the librarian. The book stays Pending Return until it is verified.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Palette.textMuted),
                ),
              if (t.overdue) ...[
                const SizedBox(height: 12),
                Text(
                    'Overdue by ${t.daysOverdue} ${t.daysOverdue == 1 ? 'day' : 'days'}. '
                    'A fine of ₱${t.fine.toStringAsFixed(2)} will be recorded.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFC0121F), fontWeight: FontWeight.w600)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Color(0xFFC0121F))),
              ],
            ]);
          },
        ),
      ),
    );
  }
}