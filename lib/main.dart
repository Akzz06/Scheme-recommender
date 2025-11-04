import 'package:flutter/material.dart';
import 'screens/language.dart';
// No Firebase or Hive imports needed

void main() async {
  // All initialization logic is removed
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Farmer Buddy',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
      ),
      home: const LanguageSelectionScreen(),
    );
  }
}