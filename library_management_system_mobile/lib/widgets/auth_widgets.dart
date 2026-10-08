import 'package:flutter/material.dart';

import 'package:library_management_system_mobile/theme/palette.dart';

/// Crest + "Hogwarts Library" title used on login and sign up.
/// To use your real crest, replace the Icon with
/// Image.asset('assets/crest.webp', ...) and register it in pubspec.yaml.
class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.shield_outlined, size: 64, color: color),
        const SizedBox(width: 14),
        Text(
          'Hogwarts\nLibrary',
          style: TextStyle(
            fontSize: 38,
            height: 0.95,
            color: color,
            fontFamily: 'Georgia',
          ),
        ),
      ],
    );
  }
}

/// Underline-style text field (matches the web login / sign up inputs).
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.color,
    required this.errorColor,
    this.icon,
    this.password = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String hint;
  final Color color;
  final Color errorColor;
  final IconData? icon;
  final bool password;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.password && _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      style: TextStyle(fontSize: 17, color: c),
      cursorColor: c,
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: c.withValues(alpha: 0.6)),
        prefixIcon:
            widget.icon == null ? null : Icon(widget.icon, size: 20, color: c),
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: c,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c.withValues(alpha: 0.7)),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: c, width: 1.5),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: widget.errorColor),
        ),
        focusedErrorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: widget.errorColor, width: 1.5),
        ),
        errorStyle: TextStyle(color: widget.errorColor),
      ),
    );
  }
}

/// Small inline banner for form-level errors (wrong password, email taken).
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key, required this.color});
  final String? message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(message!, style: TextStyle(color: color, fontSize: 14)),
    );
  }
}

const authErrorOnDark = Color(0xFFFFB4AB);
final authErrorOnLight = Colors.red.shade800;
const authLoginBg = Palette.cream;