import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:library_management_system_mobile/app_nav_bar.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';
import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/utils/validators.dart';

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

  final _picker = ImagePicker();
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFromUser();
    // Not signed in -> back to login.
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
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _startEdit() => setState(() {
        _error = null;
        _editing = true;
      });

  void _cancelEdit() {
    // reset() clears the controllers, so reload the saved values after it.
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
      if (file == null) return; // user cancelled
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

  void _logout() {
    AuthService.instance.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    return Scaffold(
      bottomNavigationBar: const AppNavBar(currentIndex: 3),
      body: SafeArea(
        child: user == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _changePhoto,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Palette.burgundy,
                                ),
                                child: CircleAvatar(
                                  radius: 56,
                                  backgroundColor: Palette.cream,
                                  backgroundImage: user.avatar != null
                                      ? MemoryImage(user.avatar!)
                                      : null,
                                  child: user.avatar == null
                                      ? Text(
                                          user.initial,
                                          style: const TextStyle(
                                            fontSize: 48,
                                            color: Palette.burgundy,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Palette.amber,
                                  child: Icon(Icons.camera_alt,
                                      size: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('My Profile',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        user.role == UserRole.librarian ? 'Librarian' : 'Student',
                        style: const TextStyle(color: Palette.textMuted),
                      ),
                      const SizedBox(height: 16),
                      _ProfileField(
                        label: 'First Name',
                        controller: _first,
                        editing: _editing,
                        validator: (v) => Validators.name(v, 'First name'),
                      ),
                      const SizedBox(height: 14),
                      _ProfileField(
                        label: 'Last Name',
                        controller: _last,
                        editing: _editing,
                        validator: (v) => Validators.name(v, 'Last name'),
                      ),
                      const SizedBox(height: 14),
                      _ProfileField(
                        label: 'Email',
                        controller: _email,
                        editing: _editing,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 14),
                      _ProfileField(
                        label: 'Phone Number',
                        controller: _phone,
                        editing: _editing,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red.shade700)),
                        ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _editing
                                ? FilledButton(
                                    onPressed: _save,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Palette.burgundy,
                                      shape: _btnShape,
                                      padding: _btnPad,
                                    ),
                                    child: const Text('Save Changes'),
                                  )
                                : OutlinedButton.icon(
                                    onPressed: _startEdit,
                                    icon: const Icon(Icons.edit_square, size: 16),
                                    label: const Text('Edit Profile'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Palette.textDark,
                                      side: const BorderSide(
                                          color: Palette.burgundy),
                                      shape: _btnShape,
                                      padding: _btnPad,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _confirmLogout,
                              icon: const Icon(Icons.logout, size: 16),
                              label: const Text('Logout'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFE00000),
                                foregroundColor: Colors.white,
                                shape: _btnShape,
                                padding: _btnPad,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_editing)
                        Center(
                          child: TextButton(
                            onPressed: _cancelEdit,
                            style: TextButton.styleFrom(
                                foregroundColor: Palette.textMuted),
                            child: const Text('Cancel'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

final _btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
const _btnPad = EdgeInsets.symmetric(vertical: 14);

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.editing,
    required this.validator,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final bool editing;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          readOnly: !editing,
          keyboardType: keyboardType,
          validator: validator,
          autovalidateMode: editing
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: editing ? Colors.white : Palette.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: editing ? Palette.burgundy : Palette.textMuted,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Palette.burgundy, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}