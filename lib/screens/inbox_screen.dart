import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum NotificationFilter { todos, enviados, respondidos }

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String? userRole;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  NotificationFilter _currentFilter = NotificationFilter.todos;

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
        SnackBar(
          content: const Text('Debes iniciar sesión para actualizar notificaciones.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
        SnackBar(
          content: const Text('Notificaciones actualizadas exitosamente'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      print('Notificaciones actualizadas con senderEmail y responderEmail en ${DateTime.now()}');
    } catch (e) {
      print('Error al actualizar notificaciones: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar notificaciones: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  List<QueryDocumentSnapshot> _filterNotifications(List<QueryDocumentSnapshot> notifications) {
    switch (_currentFilter) {
      case NotificationFilter.enviados:
        return notifications.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['title'] == 'Queja Enviada';
        }).toList();
      case NotificationFilter.respondidos:
        return notifications.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['title'] == 'Respuesta a tu Queja';
        }).toList();
      case NotificationFilter.todos:
      default:
        return notifications;
    }
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Todos', NotificationFilter.todos, Icons.all_inbox),
            const SizedBox(width: 12),
            _buildFilterChip('Enviados', NotificationFilter.enviados, Icons.send),
            const SizedBox(width: 12),
            _buildFilterChip('Respondidos', NotificationFilter.respondidos, Icons.reply),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, NotificationFilter filter, IconData icon) {
    final isSelected = _currentFilter == filter;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : Colors.green.shade700,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.green.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _currentFilter = filter;
        });
      },
      selectedColor: Colors.green.shade700,
      checkmarkColor: Colors.white,
      backgroundColor: Colors.green.shade50,
      elevation: 2,
      shadowColor: Colors.green.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.green.shade700 : Colors.green.shade200,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildComplaintDetails(Map<String, dynamic> notification, String formattedDate) {
    final isResponseNotification = notification['title'] == 'Respuesta a tu Queja';
    final isSentNotification = notification['title'] == 'Queja Enviada' || notification['title'] == 'Nueva Queja Recibida';
    if (!isResponseNotification && !isSentNotification) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSentNotification) ...[
            _buildDetailRow('Descripción', notification['description'] ?? 'Sin descripción', isFullText: true),
            const SizedBox(height: 2),
            _buildDetailRow('Dirección', notification['address'] ?? 'Sin dirección'),
            const SizedBox(height: 2),
            _buildDetailRow('Barrio', notification['neighborhood'] ?? 'Sin barrio'),
            const SizedBox(height: 2),
            _buildDetailRow('Enviado por', notification['senderEmail'] ?? 'No especificado'),
            const SizedBox(height: 2),
            if (notification['imageUrl'] != null && (notification['imageUrl'] as String).isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: notification['imageUrl'],
                  height: 150.0,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 150.0,
                    color: Colors.grey.shade300,
                    child: Center(child: CircularProgressIndicator(color: Colors.green.shade700)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 150.0,
                    color: Colors.grey.shade300,
                    child: const Center(child: Icon(Icons.error, color: Colors.red)),
                  ),
                ),
              )
            else
              Container(
                height: 150.0,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 32, color: Colors.grey.shade500),
                      const SizedBox(height: 4),
                      Text(
                        'Sin imagen',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
          if (isResponseNotification) ...[
            _buildDetailRow('Respuesta', notification['message'] ?? 'Sin mensaje', isFullText: true),
            const SizedBox(height: 2),
            _buildDetailRow('Respondido por', notification['responderEmail'] ?? 'No especificado'),
            const SizedBox(height: 8),
          ],
          _buildDateChip(formattedDate),
        ],
      ),
    );
  }

  Widget _buildDateChip(String formattedDate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 6),
          Text(
            formattedDate,
            style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {int maxLines = 1, bool isFullText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.green.shade800,
              fontSize: 12,
              letterSpacing: 0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 13,
              letterSpacing: 0.3,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            maxLines: isFullText ? null : maxLines,
            overflow: isFullText ? null : TextOverflow.ellipsis,
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Eliminado exitosamente'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print('Error al eliminar notificación/queja: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error al eliminar: $e')),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Todas las notificaciones eliminadas'),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print('Error al eliminar todas las notificaciones: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
          title: const Text(
            'Bandeja de Entrada',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.green.shade700,
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'Acceso requerido',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Por favor, inicia sesión para ver tus notificaciones.',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    print('Cargando notificaciones para userId: ${user.uid} en ${DateTime.now()}');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bandeja de Entrada',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar notificaciones',
            onPressed: _updateExistingNotifications,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete_all') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(
                      'Eliminar todas las notificaciones',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    content: Text(
                      '¿Estás seguro de que quieres eliminar todas tus notificaciones y quejas asociadas? Esta acción no se puede deshacer.',
                      style: TextStyle(
                        letterSpacing: 0.2,
                        height: 1.4,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await _deleteAllNotifications(context, user.uid);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text(
                          'Eliminar',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Eliminar todas',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            _buildFilterChips(),
            Expanded(
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.green.shade700),
                          const SizedBox(height: 16),
                          Text(
                            'Cargando notificaciones...',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    print('Error al cargar notificaciones: ${snapshot.error} en ${DateTime.now()}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Error al cargar notificaciones',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/inbox'),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    print('No hay notificaciones para userId: ${user.uid} en ${DateTime.now()}');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 24),
                          Text(
                            'Sin notificaciones',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No tienes notificaciones disponibles.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final allNotifications = snapshot.data!.docs;
                  final filteredNotifications = _filterNotifications(allNotifications);
                  print('Notificaciones cargadas: ${allNotifications.length}, filtradas: ${filteredNotifications.length} para userId: ${user.uid} en ${DateTime.now()}');

                  if (filteredNotifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Sin resultados',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No hay notificaciones para el filtro seleccionado.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = filteredNotifications[index].data() as Map<String, dynamic>;
                      final notificationId = filteredNotifications[index].id;
                      final timestamp = notification['timestamp'] as Timestamp?;
                      final formattedDate = timestamp != null
                          ? DateFormat('dd/MM/yyyy • HH:mm').format(timestamp.toDate())
                          : 'Sin fecha';
                      final isComplaintNotification = notification['title'] == 'Queja Enviada' ||
                          notification['title'] == 'Nueva Queja Recibida' ||
                          notification['title'] == 'Respuesta a tu Queja';

                      print('Mostrando notificación $notificationId: ${notification['title']} en ${DateTime.now()}');

                      return Column(
                        children: [
                          InkWell(
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
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.error, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text('Error al marcar como leída: $e')),
                                      ],
                                    ),
                                    backgroundColor: Colors.redAccent,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (notification['read'] != true)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade700,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (notification['read'] != true) const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          notification['title'] ?? 'Sin título',
                                          style: TextStyle(
                                            fontWeight: notification['read'] == true ? FontWeight.w600 : FontWeight.w700,
                                            color: Colors.green.shade800,
                                            fontSize: 16,
                                            letterSpacing: 0.3,
                                            height: 1.3,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildComplaintDetails(notification, formattedDate),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: Colors.red.shade700, size: 20),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Text(
                                            'Eliminar notificación',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.red.shade700,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          content: Text(
                                            '¿Estás seguro de que quieres eliminar esta notificación y su queja asociada?',
                                            style: TextStyle(
                                              letterSpacing: 0.2,
                                              height: 1.4,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: Text(
                                                'Cancelar',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                await _deleteNotification(context, notificationId, notification['complaintId']);
                                                Navigator.pop(context);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red.shade700,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              child: const Text(
                                                'Eliminar',
                                                style: TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (index < filteredNotifications.length - 1)
                            Divider(
                              color: Colors.green.shade200,
                              thickness: 2,
                              height: 20,
                              indent: 32,
                              endIndent: 32,
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
                break;
            }
          }
        },
        indicatorColor: Colors.green.shade200,
        backgroundColor: Colors.white,
        elevation: 8,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.green.shade100,
        destinations: [
          NavigationDestination(
            icon: userRole == 'empresa' || userRole == 'autoridad'
                ? Icon(Icons.admin_panel_settings_outlined, color: Colors.green.shade700)
                : Icon(Icons.home_outlined, color: Colors.green.shade700),
            selectedIcon: userRole == 'empresa' || userRole == 'autoridad'
                ? Icon(Icons.admin_panel_settings, color: Colors.green.shade700)
                : Icon(Icons.home, color: Colors.green.shade700),
            label: userRole == 'empresa' || userRole == 'autoridad' ? 'Admin' : 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined, color: Colors.green.shade700),
            selectedIcon: Icon(Icons.map, color: Colors.green.shade700),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: Colors.green.shade700),
            selectedIcon: Icon(Icons.person, color: Colors.green.shade700),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined, color: Colors.green.shade700),
            selectedIcon: Icon(Icons.inbox, color: Colors.green.shade700),
            label: 'Bandeja',
          ),
        ],
      ),
    );
  }
}