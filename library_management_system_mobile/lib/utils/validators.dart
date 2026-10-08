// Same rules as the web version (SignUp.jsx / Profile.jsx).

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
final _phoneRe = RegExp(r'^(09\d{9}|\+639\d{9})$');
final _nameRe = RegExp(r"^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .'-]*$");

class Validators {
  static String? name(String? v, String label) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '$label is required.';
    if (!_nameRe.hasMatch(s)) return 'Use letters only.';
    return null;
  }

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required.';
    if (!_emailRe.hasMatch(s)) return 'Enter a valid email address.';
    return null;
  }

  static String? phone(String? v) {
    final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (s.isEmpty) return 'Phone number is required.';
    if (!_phoneRe.hasMatch(s)) return 'Use 09XXXXXXXXX or +639XXXXXXXXX.';
    return null;
  }

  static String? password(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required.';
    if (s.length < 8) return 'Password must be at least 8 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    final s = v ?? '';
    if (s.isEmpty) return 'Confirm your password.';
    if (s != original) return 'Passwords do not match.';
    return null;
  }
}