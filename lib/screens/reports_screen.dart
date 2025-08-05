import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'complaint_details_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? userRole;
  final Set<String> _selectedComplaints = {};
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
        print('Usuario no autenticado en ${DateTime.now()}');
      });
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      await user.getIdToken(true);
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      setState(() {
        userRole = userDoc.data()?['role'] ?? 'usuario';
        print('Rol del usuario cargado: $userRole para UID: ${user.uid} en ${DateTime.now()}');
      });
      if (userRole != 'empresa' && userRole != 'administrador') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Solo empresas o administradores pueden acceder a esta pantalla.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Error al obtener el rol: $e en ${DateTime.now()}');
      setState(() {
        userRole = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar permisos: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _createNotification(String userId, String title, String message, String role) async {
    try {
      final currentUser = _auth.currentUser;
      String? responderEmail;
      if (currentUser != null && title == 'Respuesta a tu Queja') {
        responderEmail = currentUser.email ?? 'correo@desconocido.com';
      }

      final notificationData = {
        'userId': userId,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'role': role,
        if (responderEmail != null) 'responderEmail': responderEmail,
      };
      await _firestore.collection('notifications').add(notificationData);
      print('Notificación creada para userId: $userId, responderEmail: $responderEmail en ${DateTime.now()}');
    } catch (e) {
      print('Error al crear notificación: $e en ${DateTime.now()}');
    }
  }

  Future<void> _updateExistingNotifications() async {
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
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteSelectedComplaints() async {
    if (userRole != 'empresa' && userRole != 'administrador') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirmar Eliminación',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade700),
        ),
        content: const Text('¿Estás seguro de eliminar las quejas seleccionadas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final docId in _selectedComplaints) {
        final complaintDoc = await _firestore.collection('complaints').doc(docId).get();
        final complaintData = complaintDoc.data();
        final imageUrl = complaintData?['imageUrl'] as String?;
        final complaintUserId = complaintData?['userId'] as String?;
        if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
            print('Imagen eliminada: $imageUrl en ${DateTime.now()}');
          } catch (e) {
            print('Error al eliminar imagen: $e en ${DateTime.now()}');
          }
        }
        await _firestore.collection('complaints').doc(docId).delete();
        print('Queja eliminada: $docId en ${DateTime.now()}');
        if (complaintUserId != null) {
          await _createNotification(
            complaintUserId,
            'Queja Eliminada',
            'Tu queja ha sido eliminada por una empresa o administrador.',
            'usuario',
          );
        }
      }
      setState(() {
        _selectedComplaints.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Quejas eliminadas exitosamente'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print('Error al eliminar quejas: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar quejas: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteAllComplaints() async {
    if (userRole != 'empresa' && userRole != 'administrador') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirmar Eliminación Total',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade700),
        ),
        content: const Text('¿Estás seguro de eliminar todas las quejas? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar Todo', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final snapshot = await _firestore.collection('complaints').get();
      for (final doc in snapshot.docs) {
        final complaintData = doc.data();
        final imageUrl = complaintData['imageUrl'] as String?;
        final complaintUserId = complaintData['userId'] as String?;
        if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
          try {
            final ref = _storage.refFromURL(imageUrl);
            await ref.delete();
            print('Imagen eliminada: $imageUrl en ${DateTime.now()}');
          } catch (e) {
            print('Error al eliminar imagen: $e en ${DateTime.now()}');
          }
        }
        await doc.reference.delete();
        print('Queja eliminada: ${doc.id} en ${DateTime.now()}');
        if (complaintUserId != null) {
          await _createNotification(
            complaintUserId,
            'Queja Eliminada',
            'Tu queja ha sido eliminada por una empresa o administrador.',
            'usuario',
          );
        }
      }
      setState(() {
        _selectedComplaints.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Todas las quejas han sido eliminadas'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print('Error al eliminar todas las quejas: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar todas las quejas: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _deleteComplaint(String docId, String? imageUrl) async {
    if (userRole != 'empresa' && userRole != 'administrador') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirmar Eliminación',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade700),
        ),
        content: const Text('¿Estás seguro de eliminar esta queja?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final complaintDoc = await _firestore.collection('complaints').doc(docId).get();
      final complaintData = complaintDoc.data();
      final complaintUserId = complaintData?['userId'] as String?;
      if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
          print('Imagen eliminada: $imageUrl en ${DateTime.now()}');
        } catch (e) {
          print('Error al eliminar imagen: $e en ${DateTime.now()}');
        }
      }
      await _firestore.collection('complaints').doc(docId).delete();
      print('Queja eliminada: $docId en ${DateTime.now()}');
      if (complaintUserId != null) {
        await _createNotification(
          complaintUserId,
          'Queja Eliminada',
          'Tu queja ha sido eliminada por una empresa o administrador.',
          'usuario',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Queja eliminada exitosamente'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      print('Error al eliminar queja: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar queja: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _viewDetails(String docId, Map<String, dynamic> report) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintDetailsScreen(
          docId: docId,
          report: report,
          userRole: userRole,
          onSendResponse: (response) async {
            try {
              await _createNotification(
                report['userId'],
                'Respuesta a tu Queja',
                response,
                'usuario',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Respuesta enviada exitosamente'),
                    backgroundColor: Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            } catch (e) {
              print('Error al enviar respuesta: $e en ${DateTime.now()}');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al enviar respuesta: $e'),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            }
          },
          onDelete: () => _deleteComplaint(docId, report['imageUrl']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final textScale = screenWidth < 600 ? 1.0 : 1.2;
    final isDesktop = screenWidth >= 600;
    final padding = isDesktop ? const EdgeInsets.symmetric(horizontal: 32, vertical: 16) : const EdgeInsets.all(16);

    if (user == null || userRole == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green.shade700)),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamed(context, '/admin');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Vista de Reportes',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20 * textScale,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.green.shade700,
          elevation: 2,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () {
              Navigator.pushNamed(context, '/admin');
            },
          ),
          actions: [
            if (userRole == 'empresa' || userRole == 'administrador') ...[
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: _selectedComplaints.isNotEmpty ? 'Eliminar seleccionadas' : 'Eliminar todas',
                onPressed: _selectedComplaints.isNotEmpty ? _deleteSelectedComplaints : _deleteAllComplaints,
              ),
              IconButton(
                icon: const Icon(Icons.update),
                tooltip: 'Actualizar notificaciones',
                onPressed: _updateExistingNotifications,
              ),
            ],
          ],
        ),
        body: Container(
          color: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('complaints').orderBy('timestamp', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.green.shade700),
                              const SizedBox(height: 16),
                              Text(
                                'Cargando reportes...',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16 * textScale,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        print('Error en Firestore: ${snapshot.error} en ${DateTime.now()}');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar reportes',
                                style: TextStyle(
                                  fontSize: 18 * textScale,
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
                                  fontSize: 14 * textScale,
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _fetchUserRole,
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                              const SizedBox(height: 24),
                              Text(
                                'Sin reportes',
                                style: TextStyle(
                                  fontSize: 22 * textScale,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No hay reportes disponibles.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16 * textScale,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final reports = snapshot.data!.docs;

                      return SingleChildScrollView(
                        child: Container(
                          padding: padding,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: reports.map((reportDoc) {
                              final report = reportDoc.data() as Map<String, dynamic>? ?? {};
                              final docId = reportDoc.id;
                              final timestamp = report['timestamp'] as Timestamp?;
                              final formattedDate = timestamp != null
                                  ? DateFormat('yyyy-MM-dd, HH:mm')
                                      .format(timestamp.toDate())
                                      .replaceAll('PM', 'PM -05')
                                      .replaceAll('AM', 'AM -05')
                                  : 'Sin fecha';
                              final fullName = report['fullName'] ?? 'Sin nombre';
                              final idNumber = report['idNumber'] ?? 'No disponible';
                              final phone = report['phone'] ?? 'No disponible';
                              final description = report['description'] ?? 'Sin descripción';
                              final address = report['address'] ?? 'Sin dirección';
                              final neighborhood = report['neighborhood'] ?? 'Sin barrio';
                              final imageUrl = report['imageUrl'] as String?;

                              return Column(
                                children: [
                                  InkWell(
                                    onTap: () => _viewDetails(docId, report),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (userRole == 'empresa' || userRole == 'administrador')
                                            Checkbox(
                                              value: _selectedComplaints.contains(docId),
                                              onChanged: (value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _selectedComplaints.add(docId);
                                                  } else {
                                                    _selectedComplaints.remove(docId);
                                                  }
                                                });
                                              },
                                              activeColor: Colors.green.shade700,
                                            ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Row(
                                                  crossAxisAlignment: CrossAxisAlignment.center,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        fullName,
                                                        style: TextStyle(
                                                          fontSize: 16 * textScale,
                                                          fontWeight: FontWeight.w700,
                                                          color: Colors.green.shade700,
                                                          letterSpacing: 0.3,
                                                          height: 1.3,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Align(
                                                      alignment: Alignment.centerRight,
                                                      child: Tooltip(
                                                        message: '',
                                                        child: TextButton(
                                                          onPressed: () => _viewDetails(docId, report),
                                                          style: TextButton.styleFrom(
                                                            foregroundColor: Colors.green.shade700,
                                                            padding: EdgeInsets.zero,
                                                            minimumSize: Size.zero,
                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(
                                                                'Responder Queja',
                                                                style: TextStyle(
                                                                  fontSize: 13 * textScale,
                                                                  fontWeight: FontWeight.w600,
                                                                  color: Colors.green.shade700,
                                                                ),
                                                              ),
                                                              const SizedBox(width: 4),
                                                              Icon(
                                                                Icons.arrow_forward,
                                                                size: 14 * textScale,
                                                                color: Colors.green.shade700,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.green.shade200, width: 1),
                                                  ),
                                                  child: Text(
                                                    description,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade800,
                                                      fontSize: 13 * textScale,
                                                      letterSpacing: 0.3,
                                                      height: 1.5,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.green.shade200, width: 1),
                                                  ),
                                                  child: Text(
                                                    'Cédula: $idNumber',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade800,
                                                      fontSize: 13 * textScale,
                                                      letterSpacing: 0.3,
                                                      height: 1.5,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.green.shade200, width: 1),
                                                  ),
                                                  child: Text(
                                                    'Teléfono: $phone',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade800,
                                                      fontSize: 13 * textScale,
                                                      letterSpacing: 0.3,
                                                      height: 1.5,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.green.shade200, width: 1),
                                                  ),
                                                  child: Text(
                                                    'Dirección: $address',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade800,
                                                      fontSize: 13 * textScale,
                                                      letterSpacing: 0.3,
                                                      height: 1.5,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.green.shade200, width: 1),
                                                  ),
                                                  child: Text(
                                                    'Barrio: $neighborhood',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade800,
                                                      fontSize: 13 * textScale,
                                                      letterSpacing: 0.3,
                                                      height: 1.5,
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                imageUrl != null && imageUrl.isNotEmpty
                                                    ? ClipRRect(
                                                        borderRadius: BorderRadius.circular(12),
                                                        child: CachedNetworkImage(
                                                          imageUrl: imageUrl,
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
                                                    : Container(
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
                                                              Icon(Icons.image_not_supported_outlined, size: 32 * textScale, color: Colors.grey.shade500),
                                                              const SizedBox(height: 4),
                                                              Text(
                                                                'Sin imagen',
                                                                style: TextStyle(
                                                                  color: Colors.grey.shade600,
                                                                  fontStyle: FontStyle.italic,
                                                                  fontSize: 12 * textScale,
                                                                  letterSpacing: 0.3,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.shade50,
                                                    borderRadius: BorderRadius.circular(20),
                                                    border: Border.all(color: Colors.green.shade200, width: 1),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.access_time, size: 16 * textScale, color: Colors.green.shade700),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        formattedDate,
                                                        style: TextStyle(
                                                          color: Colors.green.shade700,
                                                          fontSize: 12 * textScale,
                                                          fontWeight: FontWeight.w500,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (userRole == 'empresa' || userRole == 'administrador')
                                            Column(
                                              mainAxisAlignment: MainAxisAlignment.start,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 24), // Espacio para alinear con la descripción
                                                IconButton(
                                                  icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
                                                  onPressed: () => _deleteComplaint(docId, imageUrl),
                                                  tooltip: 'Eliminar queja',
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    color: Colors.green.shade300,
                                    thickness: 2,
                                    height: 20,
                                    indent: 32,
                                    endIndent: 32,
                                    
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}