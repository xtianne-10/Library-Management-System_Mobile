import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import 'package:library_management_system_mobile/app_nav_bar.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/utils/validators.dart';
import 'package:library_management_system_mobile/globes/borrow_store.dart';
import 'package:library_management_system_mobile/globes/favorites_store.dart';
import 'package:library_management_system_mobile/screens/favorites.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  // Role details
  final _id = TextEditingController();
  final _course = TextEditingController();
  final _year = TextEditingController();
  final _department = TextEditingController();
  final _assigned = TextEditingController();

  final _picker = ImagePicker();
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromUser();
    AuthService.instance.refresh().then((_) {
      if (mounted && !_editing) setState(_loadFromUser);
    });
    if (!AuthService.instance.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      });
    }
  }

  void _loadFromUser() {
    final u = AuthService.instance.currentUser;
    if (u == null) return;
    _first.text = u.firstName;
    _last.text = u.lastName;
    _email.text = u.email;
    _phone.text = u.phone;
    _id.text = u.idNumber;
    _course.text = u.course;
    _year.text = u.yearLevel;
    _department.text = u.department;
    _assigned.text = u.assignedRole;
  }

  @override
  void dispose() {
    for (final c in [
      _first,
      _last,
      _email,
      _phone,
      _id,
      _course,
      _year,
      _department,
      _assigned,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startEdit() => setState(() {
        _error = null;
        _editing = true;
      });

  void _cancelEdit() {
    _formKey.currentState?.reset();
    _loadFromUser();
    setState(() {
      _error = null;
      _editing = false;
    });
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final error = AuthService.instance.updateProfile(
      firstName: _first.text,
      lastName: _last.text,
      email: _email.text,
      phone: _phone.text,
      idNumber: _id.text,
      course: _course.text,
      yearLevel: _year.text,
      department: _department.text,
      assignedRole: _assigned.text,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    _loadFromUser();
    setState(() {
      _error = null;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated.')),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      AuthService.instance.updateAvatar(bytes);
      setState(() {});
      _snack('Profile picture updated.');
    } catch (_) {
      if (!mounted) return;
      _snack('Could not open the camera or gallery.');
    }
  }

  void _changePhoto() {
    final hasPhoto = AuthService.instance.currentUser?.avatar != null;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                title: Text('Remove photo',
                    style: TextStyle(color: Colors.red.shade700)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  AuthService.instance.updateAvatar(null);
                  setState(() {});
                  _snack('Profile picture removed.');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: Palette.textMuted),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE00000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _logout();
  }

  Future<void> _changePassword() async {
    final cur = TextEditingController();
    final next = TextEditingController();
    final conf = TextEditingController();
    final key = GlobalKey<FormState>();

    InputDecoration dec(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        );

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change Password'),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: cur,
                  obscureText: true,
                  decoration: dec('Current password'),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: dec('New password'),
                  validator: (v) {
                    final s = v ?? '';
                    if (s.length < 8) return 'At least 8 characters';
                    if (!RegExp(r'[A-Za-z]').hasMatch(s) ||
                        !RegExp(r'[0-9]').hasMatch(s)) {
                      return 'Use letters and numbers';
                    }
                    if (s == cur.text) return 'Must differ from current';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: conf,
                  obscureText: true,
                  decoration: dec('Confirm new password'),
                  validator: (v) =>
                      v == next.text ? null : 'Passwords don\'t match',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final err =
          await AuthService.instance.changePassword(cur.text, next.text);
      if (!mounted) return;
      _snack(err ?? 'Password changed.');
    }
    cur.dispose();
    next.dispose();
    conf.dispose();
  }

  void _logout() {
    AuthService.instance.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  // The fields shown for each role
  List<Widget> _roleFields(UserRole role) {
    const gap = SizedBox(height: 14);

    final names = <Widget>[
      _ProfileField(
        label: 'First name',
        icon: Icons.person_outline,
        controller: _first,
        editing: _editing,
        validator: (v) => Validators.name(v, 'First name'),
      ),
      gap,
      _ProfileField(
        label: 'Last name',
        icon: Icons.badge_outlined,
        controller: _last,
        editing: _editing,
        validator: (v) => Validators.name(v, 'Last name'),
      ),
      gap,
    ];

    final phone = <Widget>[
      gap,
      _ProfileField(
        label: 'Phone number',
        icon: Icons.phone_outlined,
        controller: _phone,
        editing: _editing,
        keyboardType: TextInputType.phone,
        validator: Validators.phone,
      ),
    ];

    switch (role) {
      case UserRole.student:
        return [
          ...names,
          _ProfileField(
            label: 'Student ID',
            icon: Icons.numbers,
            controller: _id,
            editing: _editing,
            validator: (v) => Validators.idNumber(v, 'Student ID'),
          ),
          gap,
          _ProfileField(
            label: 'Email',
            icon: Icons.mail_outline,
            controller: _email,
            editing: _editing,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          gap,
          _ProfileField(
            label: 'Course',
            icon: Icons.menu_book_outlined,
            controller: _course,
            editing: _editing,
            validator: (v) => Validators.required(v, 'Course'),
          ),
          gap,
          _ProfileField(
            label: 'Year level',
            icon: Icons.grade_outlined,
            controller: _year,
            editing: _editing,
            options: yearLevelOptions,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Choose your year level.' : null,
          ),
          ...phone,
        ];
      case UserRole.professor:
        return [
          ...names,
          _ProfileField(
            label: 'Employee ID',
            icon: Icons.numbers,
            controller: _id,
            editing: _editing,
            validator: (v) => Validators.idNumber(v, 'Employee ID'),
          ),
          gap,
          _ProfileField(
            label: 'Faculty email',
            icon: Icons.mail_outline,
            controller: _email,
            editing: _editing,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          gap,
          _ProfileField(
            label: 'Department',
            icon: Icons.apartment_outlined,
            controller: _department,
            editing: _editing,
            validator: (v) => Validators.required(v, 'Department'),
          ),
          ...phone,
        ];
      case UserRole.librarian:
        return [
          ...names,
          _ProfileField(
            label: 'Employee ID',
            icon: Icons.numbers,
            controller: _id,
            editing: _editing,
            validator: (v) => Validators.idNumber(v, 'Employee ID'),
          ),
          gap,
          _ProfileField(
            label: 'Faculty email',
            icon: Icons.mail_outline,
            controller: _email,
            editing: _editing,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          gap,
          _ProfileField(
            label: 'Assigned role',
            icon: Icons.work_outline,
            controller: _assigned,
            editing: _editing,
            validator: (v) => Validators.required(v, 'Assigned role'),
          ),
          ...phone,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isLibrarian = user.role == UserRole.librarian;
    final roleLabel = switch (user.role) {
      UserRole.librarian => 'Librarian',
      UserRole.professor => 'Professor',
      UserRole.student => 'Student',
    };
    final sectionTitle = '$roleLabel profile';
    final topInset = MediaQuery.of(context).padding.top;
    final text = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Palette.page,
        bottomNavigationBar:
            isLibrarian ? null : const AppNavBar(currentIndex: 3),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Header: avatar, name, role
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(20, topInset + 8, 20, 28),
                decoration: const BoxDecoration(
                  color: Palette.burgundy,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    if (isLibrarian)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: Palette.creamLight,
                          tooltip: 'Back',
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _changePhoto,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Palette.cream,
                            ),
                            child: CircleAvatar(
                              radius: 52,
                              backgroundColor: Palette.creamLight,
                              backgroundImage: user.avatar != null
                                  ? MemoryImage(user.avatar!)
                                  : null,
                              child: user.avatar == null
                                  ? Text(
                                      user.initial,
                                      style: const TextStyle(
                                        fontSize: 44,
                                        color: Palette.burgundy,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const Positioned(
                            right: 2,
                            bottom: 2,
                            child: CircleAvatar(
                              radius: 17,
                              backgroundColor: Palette.amber,
                              child: Icon(Icons.camera_alt,
                                  size: 17, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(user.fullName,
                        textAlign: TextAlign.center,
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Palette.creamLight,
                        )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        roleLabel,
                        style: text.labelMedium?.copyWith(
                          color: Palette.creamLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats (students and professors)
              if (!isLibrarian)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: ListenableBuilder(
                    listenable: BorrowStore.instance,
                    builder: (context, _) {
                      final store = BorrowStore.instance;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Palette.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x2655161D)),
                        ),
                        child: Row(
                          children: [
                            _StatTile(
                                value: store.items.length, label: 'Borrowed'),
                            const _StatDivider(),
                            _StatTile(
                              value: store.overdue.length,
                              label: 'Overdue',
                              color: store.overdue.isEmpty
                                  ? null
                                  : Colors.red.shade700,
                            ),
                            const _StatDivider(),
                            _StatTile(
                                value: store.history.length,
                                label: 'Returned'),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              // Favorites shortcut
              if (!isLibrarian)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: ListenableBuilder(
                    listenable: FavoritesStore.instance,
                    builder: (context, _) {
                      final count = FavoritesStore.instance.items.length;
                      return Material(
                        color: Palette.card,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FavoritesScreen()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0x2655161D)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.favorite,
                                    color: Palette.burgundy),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text('My favorites',
                                      style: text.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Palette.textDark,
                                      )),
                                ),
                                Text('$count',
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Palette.burgundy,
                                    )),
                                const SizedBox(width: 4),
                                const Icon(Icons.chevron_right,
                                    color: Palette.textMuted),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // Role details
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sectionTitle,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Palette.burgundy,
                        )),
                    const SizedBox(height: 14),
                    ..._roleFields(user.role),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: TextStyle(color: Colors.red.shade700)),
                      ),
                    const SizedBox(height: 24),

                    // Primary action
                    SizedBox(
                      width: double.infinity,
                      child: _editing
                          ? FilledButton.icon(
                              onPressed: _save,
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Save changes'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Palette.burgundy,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: _startEdit,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit profile'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Palette.burgundy,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                    ),
                    if (_editing)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _cancelEdit,
                          style: TextButton.styleFrom(
                              foregroundColor: Palette.textMuted),
                          child: const Text('Cancel'),
                        ),
                      ),
                    if (!_editing) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _changePassword,
                          icon: const Icon(Icons.lock_reset, size: 18),
                          label: const Text('Change password'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Palette.burgundy,
                            side: const BorderSide(color: Palette.burgundy),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _confirmLogout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Log out'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE00000),
                          side: const BorderSide(color: Color(0xFFE00000)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.color});

  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text('$value',
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color ?? Palette.burgundy,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: text.bodySmall?.copyWith(color: Palette.textMuted)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: const Color(0x2655161D));
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.editing,
    required this.validator,
    this.keyboardType,
    this.options,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool editing;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;

  final List<String>? options;

  InputDecoration _decoration() {
    final radius = BorderRadius.circular(12);
    return InputDecoration(
      filled: true,
      fillColor: editing ? Colors.white : Palette.card,
      prefixIcon: Icon(icon, size: 20, color: Palette.burgundy),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: editing ? Palette.burgundy : const Color(0x2655161D),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Palette.burgundy, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.red.shade700),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.red.shade700, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: Palette.textDark);

    final Widget input;
    if (editing && options != null) {
      input = DropdownButtonFormField<String>(
        value: options!.contains(controller.text) ? controller.text : null,
        style: style,
        decoration: _decoration(),
        items: [
          for (final o in options!) DropdownMenuItem(value: o, child: Text(o)),
        ],
        onChanged: (v) => controller.text = v ?? '',
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
      );
    } else {
      input = TextFormField(
        controller: controller,
        readOnly: !editing || options != null,
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: editing
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        style: style,
        decoration: _decoration(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Palette.textMuted)),
        const SizedBox(height: 6),
        input,
      ],
    );
  }
}