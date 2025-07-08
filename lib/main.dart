import 'package:firebase_prueba2/screens/admin_panel_screen.dart';
import 'package:firebase_prueba2/screens/complaint_screen.dart';
import 'package:firebase_prueba2/screens/educational_section_screen.dart' show EducationalSectionScreen;
import 'package:firebase_prueba2/screens/map_screen.dart';
import 'package:firebase_prueba2/screens/profile_septup_screen.dart';
import 'package:firebase_prueba2/screens/reports_screen.dart';
import 'package:firebase_prueba2/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_prueba2/screens/home_screen.dart';
import 'package:firebase_prueba2/screens/login_screen.dart';
import 'firebase_options.dart';
import 'package:flutter/scheduler.dart' hide HomeScreen;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    print('Error inicializando Firebase: $e');
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Error al iniciar la app')))));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestión de Residuos',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const AuthCheck(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/home': (context) => HomeScreen(),
        '/login': (context) => LoginScreen(), // Quité const
        '/map': (context) => MapScreen(), // Quité const
        '/complaint': (context) => const ComplaintScreen(),
        '/educational': (context) => EducationalSectionScreen(), // Quité const
        '/profile': (context) => const UserProfileScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/admin': (context) => const AdminPanelScreen(),
        '/reportes': (context) => const ReportsScreen(),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('Estado de conexión: ${snapshot.connectionState}');
        print('Usuario autenticado: ${snapshot.hasData}');
        print('Usuario UID: ${snapshot.data?.uid}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.green)),
          );
        }
        if (snapshot.hasData && snapshot.data!.uid != null) {
          print('Redirigiendo a HomeScreen');
          return HomeScreen();
        }
        print('Redirigiendo a LoginScreen');
        return LoginScreen(); // Quité const
      },
    );
  }
}