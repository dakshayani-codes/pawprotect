// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'viewmodels/pet_viewmodel.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'views/auth/auth_screen.dart';
import 'views/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()..checkExistingSession()),
        ChangeNotifierProvider(create: (_) => PetViewModel()),
      ],
      child: const PawProtectApp(),
    ),
  );
}

class PawProtectApp extends StatelessWidget {
  const PawProtectApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PawProtect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF006E)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: Consumer<AuthViewModel>(
        builder: (_, authVM, __) {
          if (authVM.isAuthenticated) return const HomeScreen();
          return const AuthScreen();
        },
      ),
    );
  }
}
