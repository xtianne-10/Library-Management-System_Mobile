import 'package:flutter/material.dart';

import 'package:library_management_system_mobile/theme/palette.dart';
import 'package:library_management_system_mobile/screens/register.dart';
import 'package:library_management_system_mobile/screens/login.dart';
import 'package:library_management_system_mobile/screens/home.dart';
import 'package:library_management_system_mobile/screens/explore.dart';
import 'package:library_management_system_mobile/screens/my_books.dart';
import 'package:library_management_system_mobile/screens/profile.dart';
import 'package:library_management_system_mobile/screens/booklist.dart';
import 'package:library_management_system_mobile/screens/librarian.dart';

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
        "/home": (context) => HomeScreen(),
        "/explore": (context) => ExploreScreen(),
        "/mybooks": (context) => MyBooksScreen(),
        "/profile": (context) => const ProfileScreen(),
        '/librarian': (_) => const LibrarianScreen(),
        // "/booklist": (context) => BookList(),
      },
    );
  }
}