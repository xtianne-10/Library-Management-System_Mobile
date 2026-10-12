import 'package:flutter/material.dart';

import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/utils/validators.dart';
import 'package:library_management_system_mobile/widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _fg = Palette.cream;

  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _id = TextEditingController();
  final _course = TextEditingController();
  final _department = TextEditingController();
  final _assignedRole = TextEditingController();
  String? _yearLevel;

  UserRole? _role;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _email,
      _phone,
      _password,
      _confirm,
      _id,
      _course,
      _department,
      _assignedRole,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final role = _role!;
    final error = AuthService.instance.register(AppUser(
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.replaceAll(RegExp(r'[\s-]'), ''),
      password: _password.text,
      role: role,
      idNumber: _id.text.trim(),
      course: role == UserRole.student ? _course.text.trim() : '',
      yearLevel: role == UserRole.student ? (_yearLevel ?? '') : '',
      department: role == UserRole.professor ? _department.text.trim() : '',
      assignedRole:
          role == UserRole.librarian ? _assignedRole.text.trim() : '',
    ));
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created. Please sign in.')),
    );
    Navigator.pushReplacementNamed(context, '/login');
  }

  String _roleLabel(UserRole role) => switch (role) {
        UserRole.student => 'Student',
        UserRole.professor => 'Professor',
        UserRole.librarian => 'Librarian',
      };

  Widget _signInLink() => Row(
        children: [
          Text('Do you already have an account? ',
              style: TextStyle(fontSize: 13, color: _fg.withValues(alpha: 0.8))),
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text(
              'Sign in now',
              style: TextStyle(
                fontSize: 13,
                color: _fg,
                decoration: TextDecoration.underline,
                decorationColor: _fg,
              ),
            ),
          ),
        ],
      );

  Widget _roleStep() {
    Widget card(UserRole role, String label, IconData icon) => InkWell(
          onTap: () => setState(() => _role = role),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 112,
            decoration: BoxDecoration(
              color: Palette.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36, color: Palette.burgundy),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, color: Palette.burgundy)),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Create Account to explore the library',
            style: TextStyle(fontSize: 20, color: _fg)),
        const SizedBox(height: 8),
        _signInLink(),
        const SizedBox(height: 28),
        const Text('I am a:', style: TextStyle(fontSize: 18, color: _fg)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: card(UserRole.student, 'Student', Icons.school)),
            const SizedBox(width: 12),
            Expanded(
                child: card(UserRole.professor, 'Professor',
                    Icons.cast_for_education)),
          ],
        ),
      ],
    );
  }

  Widget _yearLevelField() {
    UnderlineInputBorder line(Color c, [double w = 1]) =>
        UnderlineInputBorder(borderSide: BorderSide(color: c, width: w));

    return DropdownButtonFormField<String>(
      value: _yearLevel,
      dropdownColor: Palette.burgundy,
      iconEnabledColor: _fg,
      style: const TextStyle(fontSize: 17, color: _fg),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        hintText: 'Year level',
        hintStyle: TextStyle(color: _fg.withValues(alpha: 0.6)),
        prefixIcon: const Icon(Icons.grade_outlined, size: 20, color: _fg),
        enabledBorder: line(_fg.withValues(alpha: 0.7)),
        focusedBorder: line(_fg, 1.5),
        errorBorder: line(authErrorOnDark),
        focusedErrorBorder: line(authErrorOnDark, 1.5),
        errorStyle: const TextStyle(color: authErrorOnDark),
      ),
      items: [
        for (final y in yearLevelOptions)
          DropdownMenuItem(value: y, child: Text(y)),
      ],
      onChanged: (v) => setState(() => _yearLevel = v),
      validator: (v) => v == null ? 'Choose your year level.' : null,
    );
  }

  Widget _formStep() {
    final role = _role!;
    final isStudent = role == UserRole.student;

    Widget field(
      TextEditingController c,
      String hint,
      String? Function(String?) validator, {
      IconData? icon,
      bool password = false,
      TextInputType? type,
      TextInputAction action = TextInputAction.next,
      VoidCallback? onSubmitted,
    }) =>
        AuthField(
          controller: c,
          hint: hint,
          icon: icon,
          color: _fg,
          errorColor: authErrorOnDark,
          password: password,
          keyboardType: type,
          textInputAction: action,
          onSubmitted: onSubmitted,
          validator: validator,
        );

    const gap = SizedBox(height: 16);
    final idLabel = isStudent ? 'Student ID' : 'Employee ID';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Account to explore our library',
              style: TextStyle(fontSize: 20, color: _fg)),
          const SizedBox(height: 8),
          _signInLink(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: field(_first, 'First Name',
                    (v) => Validators.name(v, 'First name')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: field(_last, 'Last Name',
                    (v) => Validators.name(v, 'Last name')),
              ),
            ],
          ),
          gap,
          field(_id, 'Enter your $idLabel',
              (v) => Validators.idNumber(v, idLabel),
              icon: Icons.badge_outlined),
          gap,
          field(
              _email,
              isStudent ? 'Enter your email' : 'Enter your faculty email',
              Validators.email,
              icon: Icons.mail_outline,
              type: TextInputType.emailAddress),
          gap,

          if (role == UserRole.student) ...[
            field(_course, 'Enter your course',
                (v) => Validators.required(v, 'Course'),
                icon: Icons.menu_book_outlined),
            gap,
            _yearLevelField(),
            gap,
          ],
          if (role == UserRole.professor) ...[
            field(_department, 'Enter your department',
                (v) => Validators.required(v, 'Department'),
                icon: Icons.apartment_outlined),
            gap,
          ],
          if (role == UserRole.librarian) ...[
            field(_assignedRole, 'Enter your assigned role',
                (v) => Validators.required(v, 'Assigned role'),
                icon: Icons.work_outline),
            gap,
          ],

          field(_phone, 'Enter your Phone Number', Validators.phone,
              icon: Icons.phone_outlined, type: TextInputType.phone),
          gap,
          field(_password, 'Enter your password', Validators.password,
              icon: Icons.lock_outline, password: true),
          gap,
          field(_confirm, 'Confirm your password',
              (v) => Validators.confirmPassword(v, _password.text),
              icon: Icons.lock_outline,
              password: true,
              action: TextInputAction.done,
              onSubmitted: _submit),
          AuthError(_error, color: authErrorOnDark),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.cream,
                foregroundColor: Palette.burgundy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Sign Up', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _role = null;
              _error = null;
              _yearLevel = null;
            }),
            style: TextButton.styleFrom(foregroundColor: _fg),
            child: Text(
              'Change account type (${_roleLabel(role)})',
              style: const TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.burgundy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthBrand(color: _fg),
                  const SizedBox(height: 28),
                  _role == null ? _roleStep() : _formStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}