import 'dart:typed_data';

import 'package:flutter/foundation.dart';

enum UserRole { student, professor, librarian }

const yearLevelOptions = [
  '1st Year',
  '2nd Year',
  '3rd Year',
  '4th Year',
  '5th Year',
];

class AppUser {
  const AppUser({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    this.role = UserRole.student,
    this.avatar,
    this.idNumber = '',
    this.course = '',
    this.yearLevel = '',
    this.department = '',
    this.assignedRole = '',
  });

  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String password;
  final UserRole role;

  final Uint8List? avatar;

  final String idNumber;
  final String course;
  final String yearLevel;
  final String department;
  final String assignedRole;

  String get fullName => '$firstName $lastName'.trim();

  String get initial =>
      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    Uint8List? avatar,
    bool clearAvatar = false,
    String? idNumber,
    String? course,
    String? yearLevel,
    String? department,
    String? assignedRole,
  }) =>
      AppUser(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        password: password,
        role: role,
        avatar: clearAvatar ? null : (avatar ?? this.avatar),
        idNumber: idNumber ?? this.idNumber,
        course: course ?? this.course,
        yearLevel: yearLevel ?? this.yearLevel,
        department: department ?? this.department,
        assignedRole: assignedRole ?? this.assignedRole,
      );
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  final List<AppUser> _users = [
    const AppUser(
      firstName: 'Zoe Claudette',
      lastName: 'Reynaldo',
      email: 'student@hogwarts.com',
      phone: '09393883413',
      password: 'hogwarts1',
      idNumber: '2023-152669',
      course: 'BSIT-MWA',
      yearLevel: '4th Year',
    ),
    const AppUser(
      firstName: 'Christianne Marie',
      lastName: 'Navarro',
      email: 'professor@hogwarts.com',
      phone: '09209606155',
      password: 'hogwarts1',
      role: UserRole.professor,
      idNumber: '2023-151496',
      department: 'School of Information Technology',
    ),
    const AppUser(
      firstName: 'Aila Jeane',
      lastName: 'Telebrico',
      email: 'librarian@hogwarts.com',
      phone: '09171234567',
      password: 'hogwarts1',
      role: UserRole.librarian,
      idNumber: '2023-154214',
      assignedRole: 'Head Librarian',
    ),
  ];

  AppUser? _current;
  AppUser? get currentUser => _current;
  bool get isLoggedIn => _current != null;

  List<AppUser> get students =>
      _users.where((u) => u.role == UserRole.student).toList();

  List<AppUser> get professors =>
      _users.where((u) => u.role == UserRole.professor).toList();

  String _norm(String email) => email.trim().toLowerCase();

  String? register(AppUser user) {
    final email = _norm(user.email);
    if (_users.any((u) => _norm(u.email) == email)) {
      return 'An account with this email already exists.';
    }
    _users.add(user.copyWith(email: email));
    return null;
  }

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

  void updateAvatar(Uint8List? bytes) {
    final me = _current;
    if (me == null) return;
    final updated = me.copyWith(avatar: bytes, clearAvatar: bytes == null);
    final i = _users.indexWhere((u) => identical(u, me));
    if (i != -1) _users[i] = updated;
    _current = updated;
    notifyListeners();
  }

  String? updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? idNumber,
    String? course,
    String? yearLevel,
    String? department,
    String? assignedRole,
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
      idNumber: idNumber?.trim(),
      course: course?.trim(),
      yearLevel: yearLevel?.trim(),
      department: department?.trim(),
      assignedRole: assignedRole?.trim(),
    );
    final i = _users.indexWhere((u) => identical(u, me));
    if (i != -1) _users[i] = updated;
    _current = updated;
    notifyListeners();
    return null;
  }
}