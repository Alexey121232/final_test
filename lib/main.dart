
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School for Teach',
      home: Scaffold(
        appBar: AppBar(title: const Text('School for Teach')),
        body: const Center(child: Text('Добро пожаловать!')),
      ),
    );
  }
}
