import 'package:flutter/material.dart';

Future<bool> confirmDialog(
  BuildContext context,
  String title,
  String message,
  String yes, {
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          style: danger
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFFC0121F))
              : null,
          child: Text(yes),
        ),
      ],
    ),
  );
  return ok == true;
}