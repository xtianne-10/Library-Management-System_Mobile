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

  // ---- Book form (same rules as HomeLibrarian.jsx) ----

  static String? bookTitle(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Book title is required.';
    if (s.length < 2) return 'Title must be at least 2 characters.';
    if (s.length > 100) return 'Title must be 100 characters or fewer.';
    return null;
  }

  static String? bookAuthor(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Author name is required.';
    if (!RegExp(r"^\p{L}[\p{L}\s.'-]*$", unicode: true).hasMatch(s)) {
      return 'Use letters only.';
    }
    if (s.length > 60) return 'Keep it under 60 characters.';
    return null;
  }

  static String? publisher(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Publisher is required.';
    if (s.length > 60) return 'Keep it under 60 characters.';
    return null;
  }

  static String? category(String? v) =>
      (v == null || v.isEmpty) ? 'Choose a category.' : null;

  static String? publishedDate(DateTime? d) {
    if (d == null) return 'Pick a publish date.';
    if (d.isAfter(DateTime.now())) return "Date can't be in the future.";
    return null;
  }

  static String? description(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Description is required.';
    if (s.length < 10) return 'Write at least 10 characters.';
    if (s.length > 300) return 'Keep it under 300 characters.';
    return null;
  }

  /// Optional field.
  static String? imageUrl(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final u = Uri.tryParse(s);
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) {
      return 'Enter a valid image link (https://...).';
    }
    return null;
  }
}