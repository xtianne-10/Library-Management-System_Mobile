import 'package:flutter/material.dart';
import 'package:library_management_system_mobile/app_nav_bar.dart';
class AppNavBar extends StatelessWidget {
  const AppNavBar({super.key, required this.currentIndex});

  final int currentIndex;

  static const _routes = ['/home', '/explore', '/mybooks', '/profile'];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) {
        if (i == currentIndex) return;
        Navigator.pushReplacementNamed(context, _routes[i]);
      },
      destinations: const [
        NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home'),
        NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore'),
        NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: 'My books'),
        NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account'),
      ],
    );
  }
}