import 'package:flutter/material.dart';
import '../widgets/navbar_home.dart';

class CareGuidesPage extends StatelessWidget {
  const CareGuidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NavbarHome(),
      body: const Center(
        child: Text(
          'Care Guides Page (Coming Soon)',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
