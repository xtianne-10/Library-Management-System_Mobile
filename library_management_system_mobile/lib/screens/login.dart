import 'package:flutter/material.dart';

import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/utils/validators.dart';
import 'package:library_management_system_mobile/widgets/auth_widgets.dart';

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

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final error = AuthService.instance.login(_email.text, _password.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pushReplacementNamed(context, '/home');
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
                    const Text(
                      'Demo: student@hogwarts.com / hogwarts1',
                      style: TextStyle(fontSize: 12, color: Palette.textMuted),
                    ),
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