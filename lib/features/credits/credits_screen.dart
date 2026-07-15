import 'package:flutter/material.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Credits')),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'Special thanks to Xeno-canto, CC licenses, and all the recordists who provided the audio datasets.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
