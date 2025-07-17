import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String? userRole;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        userRole = null;
      });
      print('Usuario no autenticado al intentar cargar InboxScreen en ${DateTime.now()}');
      return;
    }
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        userRole = userDoc.data()?['role'] ?? 'usuario';
        print('Rol del usuario cargado: $userRole para UID: ${user.uid} en ${DateTime.now()}');
      });
    } catch (e) {
      print('Error al obtener el rol: $e en ${DateTime.now()}');
      setState(() {
        userRole = null;
      });
    }
  }

  Future<void> _updateExistingNotifications() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('No hay usuario autenticado para actualizar notificaciones en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para actualizar notificaciones.')),
      );
      return;
    }
    try {
      final snapshot = await _firestore.collection('notifications').get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['title'] == 'Queja Enviada' || data['title'] == 'Nueva Queja Recibida') {
          if (data['senderName'] != null && data['senderEmail'] == null) {
            final userDoc = await _firestore.collection('users').doc(data['userId']).get();
            final senderEmail = userDoc.data()?['email'] ?? 'correo@desconocido.com';
            batch.update(doc.reference, {
              'senderEmail': senderEmail,
              'senderName': FieldValue.delete(),
            });
          }
        } else if (data['title'] == 'Respuesta a tu Queja') {
          if (data['responderName'] != null && data['responderEmail'] == null) {
            batch.update(doc.reference, {
              'responderEmail': 'admin@desconocido.com',
              'responderName': FieldValue.delete(),
            });
          }
        }
      }
      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificaciones actualizadas exitosamente')),
      );
      print('Notificaciones actualizadas con senderEmail y responderEmail en ${DateTime.now()}');
    } catch (e) {
      print('Error al actualizar notificaciones: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar notificaciones: $e')),
      );
    }
  }

  Widget _buildComplaintDetails(Map<String, dynamic> notification) {
    final isResponseNotification = notification['title'] == 'Respuesta a tu Queja';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isResponseNotification) ...[
          _buildDetailRow('Descripción', notification['description'] ?? 'Sin descripción'),
          _buildDetailRow('Dirección', notification['address'] ?? 'Sin dirección'),
          _buildDetailRow('Barrio', notification['neighborhood'] ?? 'Sin barrio'),
          _buildDetailRow('Destinatario', notification['recipient'] ?? 'No especificado'),
          _buildDetailRow('Enviado por', notification['senderEmail'] ?? 'No especificado'),
          const SizedBox(height: 10),
          notification['imageUrl'] != null && (notification['imageUrl'] as String).isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: notification['imageUrl'],
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 150,
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator(color: Colors.green)),
                    ),
                    errorWidget: (context, url, error) {
                      print('Error al cargar imagen: $error para URL: ${notification['imageUrl']} en ${DateTime.now()}');
                      return Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.error, color: Colors.red)),
                      );
                    },
                  ),
                )
              : Container(
                  height: 150,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Text(
                      'No se proporcionó ninguna imagen',
                      style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
        ],
        if (isResponseNotification) ...[
          _buildDetailRow('Respuesta', notification['message'] ?? 'Sin mensaje'),
          _buildDetailRow('Respondido por', notification['responderEmail'] ?? 'No especificado'),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(BuildContext context, String notificationId, String? complaintId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(notificationId).delete();
      print('Notificación eliminada: $notificationId en ${DateTime.now()}');

      if (complaintId != null) {
        await FirebaseFirestore.instance.collection('complaints').doc(complaintId).delete();
        print('Queja eliminada: $complaintId en ${DateTime.now()}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificación y queja eliminadas exitosamente')),
      );
    } catch (e) {
      print('Error al eliminar notificación/queja: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  Future<void> _deleteAllNotifications(BuildContext context, String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
        final complaintId = doc.data()['complaintId'] as String?;
        if (complaintId != null) {
          batch.delete(FirebaseFirestore.instance.collection('complaints').doc(complaintId));
        }
      }
      await batch.commit();
      print('Todas las notificaciones y quejas asociadas eliminadas para userId: $userId en ${DateTime.now()}');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas las notificaciones y quejas eliminadas')),
      );
    } catch (e) {
      print('Error al eliminar todas las notificaciones: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar todas las notificaciones: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      print('Usuario no autenticado al intentar cargar InboxScreen en ${DateTime.now()}');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bandeja de Entrada', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green[700],
        ),
        body: const Center(child: Text('Por favor, inicia sesión para ver tus notificaciones.')),
      );
    }

    print('Cargando notificaciones para userId: ${user.uid} en ${DateTime.now()}');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de Entrada', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (userRole == 'empresa' || userRole == 'autoridad') {
              Navigator.pushReplacementNamed(context, '/admin');
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.update, color: Colors.white),
            tooltip: 'Actualizar notificaciones',
            onPressed: _updateExistingNotifications,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            tooltip: 'Eliminar todas las notificaciones',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar todas las notificaciones'),
                  content: const Text('¿Estás seguro de que quieres eliminar todas tus notificaciones y quejas asociadas?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _deleteAllNotifications(context, user.uid);
                        Navigator.pop(context);
                      },
                      child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[100]!, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .orderBy('timestamp', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              print('Esperando datos de notificaciones para userId: ${user.uid} en ${DateTime.now()}');
              return const Center(child: CircularProgressIndicator(color: Colors.green));
            }
            if (snapshot.hasError) {
              print('Error al cargar notificaciones: ${snapshot.error} en ${DateTime.now()}');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error al cargar notificaciones: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/inbox'),
                      child: const Text('Reintentar', style: TextStyle(color: Colors.green)),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              print('No hay notificaciones para userId: ${user.uid} en ${DateTime.now()}');
              return const Center(
                child: Text(
                  'No hay notificaciones disponibles.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            final notifications = snapshot.data!.docs;
            print('Notificaciones cargadas: ${notifications.length} para userId: ${user.uid} en ${DateTime.now()}');
            for (var doc in notifications) {
              print('Notificación ID: ${doc.id}, Datos: ${doc.data()}, Fecha: ${DateTime.now()}');
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index].data() as Map<String, dynamic>;
                final notificationId = notifications[index].id;
                final timestamp = notification['timestamp'] as Timestamp?;
                final formattedDate = timestamp != null
                    ? DateFormat('yyyy-MM-dd, HH:mm').format(timestamp.toDate()).replaceAll('PM', 'PM -05').replaceAll('AM', 'AM -05')
                    : 'Sin fecha';
                final isComplaintNotification = notification['title'] == 'Queja Enviada' ||
                    notification['title'] == 'Nueva Queja Recibida' ||
                    notification['title'] == 'Respuesta a tu Queja';

                print('Mostrando notificación $notificationId: ${notification['title']} en ${DateTime.now()}');

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16.0),
                    title: Text(
                      notification['title'] ?? 'Sin título',
                      style: TextStyle(
                        fontWeight: notification['read'] == true ? FontWeight.normal : FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        if (isComplaintNotification)
                          _buildComplaintDetails(notification)
                        else
                          Text(
                            notification['message'] ?? 'Sin mensaje',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Fecha: $formattedDate',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar notificación'),
                            content: const Text('¿Estás seguro de que quieres eliminar esta notificación y su queja asociada?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await _deleteNotification(context, notificationId, notification['complaintId']);
                                  Navigator.pop(context);
                                },
                                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    onTap: () async {
                      try {
                        await _firestore
                            .collection('notifications')
                            .doc(notificationId)
                            .update({'read': true});
                        print('Notificación marcada como leída: $notificationId en ${DateTime.now()}');
                      } catch (e) {
                        print('Error al marcar notificación como leída: $e en ${DateTime.now()}');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al marcar como leída: $e')),
                        );
                      }
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        onDestinationSelected: (index) {
          if (userRole == 'empresa' || userRole == 'autoridad') {
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/admin');
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/map');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/profile');
                break;
              case 3:
                // Ya estamos en InboxScreen
                break;
            }
          } else {
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, '/home');
                break;
              case 1:
                Navigator.pushReplacementNamed(context, '/map');
                break;
              case 2:
                Navigator.pushReplacementNamed(context, '/profile');
                break;
              case 3:
                // Ya estamos en InboxScreen
                break;
            }
          }
        },
        indicatorColor: Colors.green[200],
        backgroundColor: Colors.white,
        elevation: 8,
        destinations: [
          NavigationDestination(
            icon: userRole == 'empresa' || userRole == 'autoridad'
                ? const Icon(Icons.admin_panel_settings, color: Colors.green)
                : const Icon(Icons.home, color: Colors.green),
            selectedIcon: userRole == 'empresa' || userRole == 'autoridad'
                ? const Icon(Icons.admin_panel_settings_outlined, color: Colors.green)
                : const Icon(Icons.home_filled, color: Colors.green),
            label: userRole == 'empresa' || userRole == 'autoridad' ? 'Admin' : 'Inicio',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map, color: Colors.green),
            selectedIcon: Icon(Icons.map_outlined, color: Colors.green),
            label: 'Mapa',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person, color: Colors.green),
            selectedIcon: Icon(Icons.person, color: Colors.green),
            label: 'Perfil',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inbox, color: Colors.green),
            selectedIcon: Icon(Icons.inbox_outlined, color: Colors.green),
            label: 'Bandeja',
          ),
        ],
      ),
    );
  }
}