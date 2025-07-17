import 'package:firebase_prueba2/panel_administrativo_screen/create_user_screen.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/edit_user_screen.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/educational_content_screen.dart';
import 'package:firebase_prueba2/panel_administrativo_screen/users_list_screen.dart';
import 'package:firebase_prueba2/screens/Agregar_contenedor.screen.dart';
import 'package:firebase_prueba2/screens/admin_panel_screen.dart';
import 'package:firebase_prueba2/screens/complaint_screen.dart';
import 'package:firebase_prueba2/screens/container_map_screen.dart';
import 'package:firebase_prueba2/screens/educational_section_screen.dart' show EducationalSectionScreen;
import 'package:firebase_prueba2/screens/inbox_screen.dart';
import 'package:firebase_prueba2/screens/map_screen.dart';
import 'package:firebase_prueba2/screens/profile_septup_screen.dart';
import 'package:firebase_prueba2/screens/reports_screen.dart';
import 'package:firebase_prueba2/screens/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_prueba2/screens/home_screen.dart';
import 'package:firebase_prueba2/screens/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    print('Error inicializando Firebase: $e en ${DateTime.now()}');
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
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/map': (context) => ContainerMapScreen(),
        '/complaint': (context) => const ComplaintScreen(),
        '/educational': (context) => EducationalSectionScreen(),
        '/profile': (context) => const UserProfileScreen(),
        '/profile_setup': (context) => const ProfileSetupScreen(),
        '/admin': (context) => const AdminPanelScreen(),
        '/reportes': (context) => const ReportsScreen(),
        '/inbox': (context) => const InboxScreen(),
        '/agregarContenedor': (context) => AgregarContenedorScreen(),
        '/create_user': (context) => const CreateUserScreen(),
        '/users_list': (context) => const UsersListScreen(),
        '/edit_user': (context) => EditUserScreen(arguments: ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {}),
        '/educational_content': (context) => EducationalContentScreen(),
        
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  Future<String> _getInitialRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    print('Verificando estado de autenticación en ${DateTime.now()}');
    if (user == null) {
      print('No hay usuario autenticado, redirigiendo a /login');
      return '/login';
    }
    try {
      print('Usuario autenticado: UID=${user.uid}, Email=${user.email}');
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = userDoc.data()?['role'] ?? 'usuario';
      print('Rol obtenido: $role para UID=${user.uid} en ${DateTime.now()}');
      if (role == 'empresa' || role == 'administrador') {
        return '/admin';
      } else if (!userDoc.exists) {
        return '/profile_setup';
      } else {
        return '/home';
      }
    } catch (e) {
      print('Error al obtener rol: $e en ${DateTime.now()}');
      return '/login';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getInitialRoute(),
      builder: (context, snapshot) {
        print('Estado de conexión: ${snapshot.connectionState} en ${DateTime.now()}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.green)),
          );
        }
        if (snapshot.hasError) {
          print('Error al determinar ruta inicial: ${snapshot.error} en ${DateTime.now()}');
          return const LoginScreen();
        }
        final initialRoute = snapshot.data ?? '/login';
        print('Ruta inicial determinada: $initialRoute en ${DateTime.now()}');
        switch (initialRoute) {
          case '/admin':
            return const AdminPanelScreen();
          case '/profile_setup':
            return const ProfileSetupScreen();
          case '/home':
            return const HomeScreen();
          case '/login':
          default:
            return const LoginScreen();
        }
      },
    );
  }
}