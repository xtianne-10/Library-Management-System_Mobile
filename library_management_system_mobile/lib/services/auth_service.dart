import 'dart:typed_data';

import 'package:flutter/foundation.dart';

enum UserRole { student, librarian }

class AppUser {
  const AppUser({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    this.role = UserRole.student,
    this.avatar,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final UserRole role;

  /// Profile picture bytes (null = show the initial instead).
  final Uint8List? avatar;

  String get fullName => '$firstName $lastName'.trim();

  /// First letter for the avatar circle.
  String get initial =>
      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    Uint8List? avatar,
    bool clearAvatar = false,
  }) =>
      AppUser(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        password: password,
        role: role,
        avatar: clearAvatar ? null : (avatar ?? this.avatar),
      );
}

/// In-memory auth. There is no backend yet (the web version only
/// console.logs), so accounts live only while the app is running.
/// Swap the bodies of register/login/updateProfile for real API calls later;
/// the screens won't need to change.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  final List<AppUser> _users = [
    // Demo account so you can test login without signing up first.
    const AppUser(
      firstName: 'Zoe Claudette',
      lastName: 'Reynaldo',
      email: 'student@hogwarts.com',
      phone: '09393883413',
      password: 'hogwarts1',
    ),
    const AppUser(
      firstName: 'Aila Jeane',
      lastName: 'Telebrico',
      email: 'librarian@hogwarts.com',
      phone: '09171234567',
      password: 'hogwarts1',
      role: UserRole.librarian,
    ),
  ];

  AppUser? _current;
  AppUser? get currentUser => _current;
  bool get isLoggedIn => _current != null;

  String _norm(String email) => email.trim().toLowerCase();

  /// Returns an error message, or null on success.
  String? register(AppUser user) {
    final email = _norm(user.email);
    if (_users.any((u) => _norm(u.email) == email)) {
      return 'An account with this email already exists.';
    }
    _users.add(user.copyWith(email: email));
    return null;
  }

  /// Returns an error message, or null on success.
  String? login(String email, String password) {
    final e = _norm(email);
    for (final u in _users) {
      if (_norm(u.email) == e && u.password == password) {
        _current = u;
        notifyListeners();
        return null;
      }
    }
    return 'Incorrect email or password.';
  }

  void logout() {
    _current = null;
    notifyListeners();
  }

  /// Sets (or removes, when [bytes] is null) the profile picture.
  void updateAvatar(Uint8List? bytes) {
    final me = _current;
    if (me == null) return;
    final updated = me.copyWith(avatar: bytes, clearAvatar: bytes == null);
    final i = _users.indexWhere((u) => identical(u, me));
    if (i != -1) _users[i] = updated;
    _current = updated;
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  String? updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) {
    final me = _current;
    if (me == null) return 'You are not signed in.';
    final newEmail = _norm(email);
    if (_users.any((u) => !identical(u, me) && _norm(u.email) == newEmail)) {
      return 'Another account already uses this email.';
    }
    final updated = me.copyWith(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: newEmail,
      phone: phone.trim(),
    );
    final i = _users.indexWhere((u) => identical(u, me));
    if (i != -1) _users[i] = updated;
    _current = updated;
    notifyListeners();
    return null;
  }
}