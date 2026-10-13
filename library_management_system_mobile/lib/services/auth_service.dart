import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

enum UserRole { student, professor, librarian }

String _s(Map u, List<String> keys) {
  for (final k in keys) {
    final v = u[k];
    if (v != null && v.toString().isNotEmpty) return v.toString();
  }
  return '';
}

Uint8List? _decodeAvatar(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  try {
    final i = v.indexOf(',');
    return base64Decode(i == -1 ? v : v.substring(i + 1));
  } catch (_) {
    return null;
  }
}

AppUser _userFromJson(Map u) => AppUser(
      firstName: _s(u, ['firstName', 'first_name']),
      lastName: _s(u, ['lastName', 'last_name']),
      email: _s(u, ['email']),
      phone: _s(u, ['phone_number', 'phone']),
      idNumber: _s(u, ['idNumber', 'id_number', 'employeeId', 'employee_id']),
      course: _s(u, ['course']),
      yearLevel: _s(u, ['yearLevel', 'year_level']),
      department: _s(u, ['department']),
      assignedRole: _s(u, ['assignedRole', 'assigned_role']),
      avatar: _decodeAvatar(u['avatar']),
      password: '',
      role: UserRole.values.asNameMap()[u['role']] ?? UserRole.student,
    );

class AppUser {
  const AppUser({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.password,
    this.role = UserRole.student,
    this.avatar,
    this.employeeId = '',
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
  final String employeeId;

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
    String? password,
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
        password: password ?? this.password,
        role: role,
        employeeId: employeeId,
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
      employeeId: 'LIB-0001',
      assignedRole: 'Librarian',
    ),
  ];

  String? _token;
  String? get token => _token;
  AppUser? _current;
  AppUser? get currentUser => _current;
  bool get isLoggedIn => _current != null;

  List<AppUser> get students =>
      _users.where((u) => u.role == UserRole.student).toList();

  List<AppUser> _remoteBorrowers = [];
  bool _borrowersLoaded = false;

  /// Students and professors (everyone who can borrow). Comes from the
  /// server once loaded, otherwise the demo users.
  List<AppUser> get borrowers => _borrowersLoaded
      ? _remoteBorrowers
      : _users
          .where((u) =>
              u.role == UserRole.student || u.role == UserRole.professor)
          .toList();

  Future<void> loadBorrowers() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/borrowings/borrowers'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode != 200) return;
      final list = jsonDecode(res.body) as List;
      _remoteBorrowers = [for (final m in list) _userFromJson(m as Map)];
      _borrowersLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  String _norm(String email) => email.trim().toLowerCase();

  String? register(AppUser user) {
    if (user.role == UserRole.librarian) {
      return 'Librarian accounts can only be created by an administrator.';
    }
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

  /// Logs in against the Express API. Returns an error message, or null on success.
  Future<String?> loginApi(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _norm(email), 'password': password}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        return data['error'] ?? 'Something went wrong.';
      }
      final u = data['user'];
      _token = data['token'];
      _current = _userFromJson(u);
      notifyListeners();
      return null;
    } catch (_) {
      return 'Cannot reach the server.';
    }
  }

    /// Registers against the Express API. Returns an error message, or null on success.
  Future<String?> registerApi(AppUser user) async {
    if (user.role == UserRole.librarian) {
      return 'Librarian accounts can only be created by an administrator.';
    }
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'role': user.role.name,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'email': _norm(user.email),
          'phone_number': user.phone,
          'password': user.password,
          'idNumber': user.idNumber,
          'course': user.course,
          'yearLevel': user.yearLevel,
          'department': user.department,
        }),
      );
      if (res.statusCode == 201) return null;
      final data = jsonDecode(res.body);
      return data['error'] ?? 'Something went wrong.';
    } catch (_) {
      return 'Cannot reach the server.';
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> changePassword(String current, String next) async {
    final me = _current;
    if (me == null) return 'You are not signed in.';
    if (next == current) return 'New password must differ from the current one.';

    // Signed in through the API: the server checks the current password
    if (_token != null) {
      try {
        final res = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/auth/password'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: jsonEncode({'currentPassword': current, 'newPassword': next}),
        );
        if (res.statusCode == 200) return null;
        Map? data;
        try {
          data = jsonDecode(res.body) as Map;
        } catch (_) {}
        return (data?['error'] as String?) ?? 'Could not change password.';
      } catch (_) {
        return 'Cannot reach the server.';
      }
    }

    // Demo accounts (no server)
    if (me.password != current) return 'Current password is incorrect.';
    final updated = me.copyWith(password: next);
    final i = _users.indexWhere((u) => identical(u, me));
    if (i != -1) _users[i] = updated;
    _current = updated;
    notifyListeners();
    return null;
  }

  void logout() {
    _current = null;
    _token = null;
    _remoteBorrowers = [];
    _borrowersLoaded = false;
    notifyListeners();
  }

  /// Re-reads the profile from the server so web edits show up here.
  Future<void> refresh() async {
    if (_token == null) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (res.statusCode != 200) return;
      _current = _userFromJson(jsonDecode(res.body)['user']);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _pushProfile(Map<String, dynamic> body) async {
    if (_token == null) return;
    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(body),
      );
    } catch (_) {}
  }

  void updateAvatar(Uint8List? bytes) {
    final me = _current;
    if (me == null) return;
    final updated = me.copyWith(avatar: bytes, clearAvatar: bytes == null);
    final i = _users.indexWhere((u) => identical(u, me));
    if (i != -1) _users[i] = updated;
    _current = updated;
    notifyListeners();
    _pushProfile({
      'avatar':
          bytes == null ? null : 'data:image/jpeg;base64,${base64Encode(bytes)}',
    });
  }

  String? updateProfile({
    required String firstName,
    required String lastName,
    String? email,
    required String phone,
    String? idNumber,
    String? course,
    String? yearLevel,
    String? department,
    String? assignedRole,
  }) {
    final me = _current;
    if (me == null) return 'You are not signed in.';
    final newEmail = _norm(email ?? me.email);
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
    _pushProfile({
      'firstName': updated.firstName,
      'lastName': updated.lastName,
      'email': updated.email,
      'phone_number': updated.phone,
      'idNumber': updated.idNumber,
      'course': updated.course,
      'yearLevel': updated.yearLevel,
      'department': updated.department,
      'assignedRole': updated.assignedRole,
    });
    return null;
  }
}