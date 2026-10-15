import 'package:flutter/material.dart';

import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/utils/validators.dart';
import 'package:library_management_system_mobile/widgets/auth_widgets.dart';
import 'package:library_management_system_mobile/utils/confirm_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final error = await AuthService.instance.loginApi(_email.text, _password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final role = AuthService.instance.currentUser?.role;
    final route = switch (role) {
      UserRole.librarian => '/librarian',
      UserRole.professor => '/home',
      _ => '/home',
    };
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _forgotPassword() async {
  final email = TextEditingController(text: _email.text.trim());
  final id = TextEditingController();
  final next = TextEditingController();
  final conf = TextEditingController();
  final key = GlobalKey<FormState>();
  String? err;
  bool busy = false;

  InputDecoration dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x4055161D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0x4055161D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Palette.burgundy, width: 2),
        ),
      );

  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialog) => AppDialog(
        title: 'Forgot Password',
        icon: Icons.lock_reset,
        confirmLabel: busy ? 'Resetting...' : 'Reset',
        confirmEnabled: !busy &&
            email.text.isNotEmpty &&
            id.text.isNotEmpty &&
            next.text.isNotEmpty &&
            conf.text.isNotEmpty,
        onCancel: () async {
          if (c.mounted) Navigator.pop(c, false);
        },
        onConfirm: () async {
          if (!key.currentState!.validate()) return;
          setDialog(() {
            busy = true;
            err = null;
          });
          final e = await AuthService.instance.resetPassword(
            email: email.text,
            idNumber: id.text,
            newPassword: next.text,
          );
          if (!c.mounted) return;
          if (e != null) {
            setDialog(() {
              busy = false;
              err = e;
            });
            return;
          }
          Navigator.pop(c, true);
        },
        child: Form(
          key: key,
          onChanged: () => setDialog(() {}),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: dec('Email'),
                validator: Validators.email,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: id,
                decoration: dec('Student / Employee ID'),
                validator: (v) => Validators.idNumber(v, 'ID number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: dec('New password'),
                validator: Validators.password,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: conf,
                obscureText: true,
                decoration: dec('Confirm new password'),
                validator: (v) => Validators.confirmPassword(v, next.text),
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(err!,
                      style: TextStyle(color: Colors.red.shade700)),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  email.dispose();
  id.dispose();
  next.dispose();
  conf.dispose();

  if (ok == true && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset. You can sign in now.')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    const ink = Palette.burgundy;
    return Scaffold(
      backgroundColor: authLoginBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthBrand(color: ink),
                    const SizedBox(height: 32),
                    const Text(
                      'Welcome back to Hogwarts Library',
                      style: TextStyle(fontSize: 22, color: ink),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('New here? ',
                            style: TextStyle(fontSize: 14, color: ink)),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushReplacementNamed(context, '/register'),
                          child: const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 14,
                              color: ink,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    AuthField(
                      controller: _email,
                      hint: 'Enter your email',
                      icon: Icons.person,
                      color: ink,
                      errorColor: authErrorOnLight,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 20),
                    AuthField(
                      controller: _password,
                      hint: 'Enter your password',
                      icon: Icons.lock,
                      color: ink,
                      errorColor: authErrorOnLight,
                      password: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: _submit,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Password is required.' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        style: TextButton.styleFrom(foregroundColor: ink),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 14,
                            decoration: TextDecoration.underline,
                            decorationColor: ink,
                          ),
                        ),
                      ),
                    ),
                    AuthError(_error, color: authErrorOnLight),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: ink,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text('Sign in',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}