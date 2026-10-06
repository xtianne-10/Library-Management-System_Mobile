import 'package:flutter/material.dart';
import 'package:library_management_system_mobile/app_nav_bar.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Explore')),
      bottomNavigationBar: AppNavBar(currentIndex: 1),
    );
  }
}