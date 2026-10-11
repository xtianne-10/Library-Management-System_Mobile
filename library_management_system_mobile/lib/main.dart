import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/screens/register.dart';
import 'package:library_management_system_mobile/screens/login.dart';
import 'package:library_management_system_mobile/screens/home.dart';
import 'package:library_management_system_mobile/screens/explore.dart';
import 'package:library_management_system_mobile/screens/my_books.dart';
import 'package:library_management_system_mobile/screens/profile.dart';
import 'package:library_management_system_mobile/screens/booklist.dart';
import 'package:library_management_system_mobile/screens/librarian.dart';
import 'package:library_management_system_mobile/services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Palette.burgundy,
      brightness: Brightness.light,
    ).copyWith(
      primary: Palette.burgundy,
      onPrimary: Palette.creamLight,
      primaryContainer: Palette.cream,
      onPrimaryContainer: Palette.burgundy,
      secondary: Palette.amber,
      onSecondary: Colors.white,
      surface: Palette.page,
      onSurface: Palette.textDark,
    );

    return MaterialApp(
      title: 'Hogwarts Library',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: Palette.page,
        fontFamily: 'Georgia',
        fontFamilyFallback: const ['serif'],
        textTheme: ThemeData.light().textTheme.apply(
              bodyColor: Palette.textDark,
              displayColor: Palette.textDark,
              fontFamily: 'Georgia',
            ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Palette.burgundy,
          indicatorColor: Palette.cream,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Palette.burgundy
                  : Palette.creamMuted,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            return TextStyle(
              fontFamily: 'Georgia',
              fontSize: 12,
              color: states.contains(WidgetState.selected)
                  ? Palette.creamLight
                  : Palette.creamMuted,
            );
          }),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Palette.amber),
        ),
      ),
      initialRoute: "/login",
      routes: {
        "/register": (context) => const RegisterScreen(),
        "/login": (context) => const LoginScreen(),
        "/home": (context) =>
            RoleGuard(allow: UserRole.student, child: HomeScreen()),
        "/explore": (context) =>
            RoleGuard(allow: UserRole.student, child: ExploreScreen()),
        "/mybooks": (context) =>
            RoleGuard(allow: UserRole.student, child: MyBooksScreen()),
        "/profile": (context) => const ProfileScreen(),
        '/librarian': (_) =>
            const RoleGuard(allow: UserRole.librarian, child: LibrarianScreen()),
        // "/booklist": (context) => BookList(),
      },
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

// Role Guard
class RoleGuard extends StatelessWidget {
  const RoleGuard({super.key, required this.allow, required this.child});
  final UserRole allow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user != null && user.role == allow) return child;

    final target = user == null
        ? '/login'
        : (user.role == UserRole.librarian ? '/librarian' : '/home');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) Navigator.pushReplacementNamed(context, target);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}