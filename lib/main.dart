    import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/app_provider.dart';
import 'ui/screens/app_navigator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure Firebase config is correctly added later when running.
  // We'll use try/catch to gracefully handle Firebase initialization for now
  try {
    await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint("Firebase init error (if config missing): \$e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const MyMoneyApp(),
    ),
  );
}

class MyMoneyApp extends StatelessWidget {
  const MyMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ducat',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      home: const AppNavigator(),
    );
  }
}
