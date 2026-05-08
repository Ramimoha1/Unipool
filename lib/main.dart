import 'package:firebase_core/firebase_core.dart'; 
import 'package:flutter/material.dart';
import 'firebase_options.dart'; 

void main() async {
  // Required to ensure Flutter framework is ready before Firebase starts
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes Firebase for the specific platform (Android, iOS, or Web)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('UniPool Firebase Initialized!'),
        ),
      ),
    );
  }
}