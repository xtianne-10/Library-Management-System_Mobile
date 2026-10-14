import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
  int _mode = 0; // 0 = scan, 1 = enter number
  bool _busy = false;
  String? _error;
  String? _success;
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
    final (err, summary) = await _lib.verifyReturn(raw);
    if (!mounted) return;
    setState(() { _busy = false; _error = err; _success = summary; });
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() {
                _success = null;
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