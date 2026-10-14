import 'package:flutter/material.dart';

import 'package:library_management_system_mobile/theme/palette.dart';

const _dangerRed = Color(0xFFC0121F);

/// Shared popup: cancel on the LEFT, confirm on the RIGHT.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.icon,
    this.cancelLabel = 'Cancel',
    this.danger = false,
    this.confirmEnabled = true,
  });

  final String title;
  final Widget child;
  final String confirmLabel;
  final String cancelLabel;
  final IconData? icon;
  final bool danger;
  final bool confirmEnabled;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? _dangerRed : Palette.burgundy;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: Palette.card,
                border: const Border(
                    bottom: BorderSide(color: Color(0x1A55161D))),
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 20, color: accent),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontFamilyFallback: ['serif'],
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Palette.burgundy,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: child,
              ),
            ),

            // Footer: Cancel (left) | Confirm (right)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.burgundy,
                        side: const BorderSide(color: Color(0x4055161D)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: shape,
                      ),
                      child: Text(cancelLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: confirmEnabled ? onConfirm : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: accent.withValues(alpha: 0.35),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: shape,
                      ),
                      child: Text(confirmLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String message,
  String confirmLabel, {
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AppDialog(
      title: title,
      icon: danger ? Icons.delete_outline : Icons.help_outline,
      confirmLabel: confirmLabel,
      danger: danger,
      onCancel: () => Navigator.pop(c, false),
      onConfirm: () => Navigator.pop(c, true),
      child: Text(
        message,
        style: const TextStyle(
            fontSize: 15, height: 1.5, color: Palette.textDark),
      ),
    ),
  );
  return ok ?? false;
}