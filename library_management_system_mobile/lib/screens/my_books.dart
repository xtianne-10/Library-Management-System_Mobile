import 'package:flutter/material.dart';
import 'package:library_management_system_mobile/app_nav_bar.dart';

class MyBooksScreen extends StatelessWidget {
  const MyBooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('My books')),
      bottomNavigationBar: AppNavBar(currentIndex: 2),
    );
  }
}