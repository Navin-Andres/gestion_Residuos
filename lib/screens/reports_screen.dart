import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      if (userRole != 'empresa' && userRole != 'autoridad') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solo empresas o autoridades pueden acceder a esta pantalla.')),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      print('Error al obtener el rol: $e en ${DateTime.now()}');
      setState(() {
        userRole = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar permisos. Contacta al administrador.')),
      );
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _createNotification(String userId, String title, String message, String role) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'role': role,
      });
      print('Notificación creada para userId: $userId en ${DateTime.now()}');
    } catch (e) {
      print('Error al crear notificación: $e en ${DateTime.now()}');
    }
  }

  Future<void> _deleteSelectedComplaints() async {
    if (userRole != 'empresa' && userRole != 'autoridad') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar las quejas seleccionadas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
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
            'Tu queja ha sido eliminada por una empresa o autoridad.',
            'usuario',
          );
        }
      }
      setState(() {
        _selectedComplaints.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quejas eliminadas exitosamente')),
      );
    } catch (e) {
      print('Error al eliminar quejas: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar quejas: $e')),
      );
    }
  }

  Future<void> _deleteAllComplaints() async {
    if (userRole != 'empresa' && userRole != 'autoridad') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación Total'),
        content: const Text('¿Estás seguro de eliminar todas las quejas? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar Todo'),
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
            'Tu queja ha sido eliminada por una empresa o autoridad.',
            'usuario',
          );
        }
      }
      setState(() {
        _selectedComplaints.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas las quejas han sido eliminadas')),
      );
    } catch (e) {
      print('Error al eliminar todas las quejas: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar todas las quejas: $e')),
      );
    }
  }

  Future<void> _deleteComplaint(String docId, String? imageUrl) async {
    if (userRole != 'empresa' && userRole != 'autoridad') return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar esta queja?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
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
          'Tu queja ha sido eliminada por una empresa o autoridad.',
          'usuario',
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queja eliminada exitosamente')),
      );
    } catch (e) {
      print('Error al eliminar queja: $e en ${DateTime.now()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar queja: $e')),
      );
    }
  }

  Future<void> _viewDetails(String docId, Map<String, dynamic> report) async {
    final responseController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Detalles de la Queja', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Nombre Completo', report['fullName'] ?? 'Sin nombre'),
                _buildDetailRow('Cédula', report['idNumber'] ?? 'No disponible'),
                _buildDetailRow('Teléfono', report['phone'] ?? 'No disponible'),
                _buildDetailRow('Descripción', report['description'] ?? 'Sin descripción'),
                _buildDetailRow('Dirección', report['address'] ?? 'Sin dirección'),
                _buildDetailRow('Barrio', report['neighborhood'] ?? 'Sin barrio'),
                _buildDetailRow('Estado', report['status'] ?? 'Pendiente'),
                _buildDetailRow('Destinatario', report['recipient'] ?? 'No especificado'),
                const SizedBox(height: 10),
                report['imageUrl'] != null && (report['imageUrl'] as String).isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: report['imageUrl'],
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator(color: Colors.green)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Center(child: Icon(Icons.error, color: Colors.red)),
                          ),
                        ),
                      )
                    : Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: const Center(
                          child: Text(
                            'No se proporcionó ninguna imagen',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                const SizedBox(height: 10),
                if (userRole == 'empresa' || userRole == 'autoridad') ...[
                  TextField(
                    controller: responseController,
                    decoration: const InputDecoration(
                      labelText: 'Responder a la queja',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !isLoading,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Colors.green)),
            ),
            if (userRole == 'empresa' || userRole == 'autoridad')
              TextButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (responseController.text.isEmpty || responseController.text.length < 5) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('La respuesta debe tener al menos 5 caracteres')),
                          );
                          return;
                        }

                        setDialogState(() {
                          isLoading = true;
                        });

                        try {
                          await _createNotification(
                            report['userId'],
                            'Respuesta a tu Queja',
                            responseController.text,
                            'usuario',
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Respuesta enviada exitosamente')),
                          );
                          Navigator.pop(context);
                        } catch (e) {
                          print('Error al enviar respuesta: $e en ${DateTime.now()}');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al enviar respuesta: $e')),
                          );
                        } finally {
                          setDialogState(() {
                            isLoading = false;
                          });
                        }
                      },
                child: const Text('Enviar Respuesta', style: TextStyle(color: Colors.green)),
              ),
          ],
        ),
      ),
    );

    responseController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null || userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamed(context, '/admin');
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vista de Reportes', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green[700],
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushNamed(context, '/admin');
            },
          ),
          actions: [
            if (userRole == 'empresa' || userRole == 'autoridad') ...[
              IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.white),
                onPressed: _selectedComplaints.isNotEmpty ? _deleteSelectedComplaints : _deleteAllComplaints,
                tooltip: _selectedComplaints.isNotEmpty ? 'Eliminar seleccionadas' : 'Eliminar todas',
              ),
            ],
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
            stream: _firestore.collection('complaints').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.green));
              }
              if (snapshot.hasError) {
                print('Error en Firestore: ${snapshot.error} en ${DateTime.now()}');
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Error al cargar reportes.', style: TextStyle(color: Colors.red)),
                      TextButton(
                        onPressed: _fetchUserRole,
                        child: const Text('Reintentar', style: TextStyle(color: Colors.green)),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No hay reportes disponibles.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                );
              }

              final reports = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index].data() as Map<String, dynamic>;
                  final docId = reports[index].id;
                  final timestamp = report['timestamp'] as Timestamp?;
                  final formattedDate = timestamp != null
                      ? DateFormat('yyyy-MM-dd, HH:mm').format(timestamp.toDate()).replaceAll('PM', 'PM -05').replaceAll('AM', 'AM -05')
                      : 'Sin fecha';
                  final imageUrl = report['imageUrl'] as String?;
                  final fullName = report['fullName'] ?? 'Sin nombre';
                  final idNumber = report['idNumber'] ?? 'No disponible';
                  final phone = report['phone'] ?? 'No disponible';
                  final description = report['description'] ?? 'Sin descripción';
                  final address = report['address'] ?? 'Sin dirección';
                  final neighborhood = report['neighborhood'] ?? 'Sin barrio';

                  final isValidUrl = imageUrl != null &&
                      imageUrl.isNotEmpty &&
                      Uri.tryParse(imageUrl)?.hasScheme == true &&
                      imageUrl.contains('firebasestorage.googleapis.com');

                  if (isValidUrl) {
                    print('Intentando cargar imagen: $imageUrl en ${DateTime.now()} en plataforma: ${kIsWeb ? 'web' : 'móvil'}');
                  } else {
                    print('URL de imagen inválida o ausente para reporte $docId: $imageUrl en ${DateTime.now()}');
                  }

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (userRole == 'empresa' || userRole == 'autoridad')
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
                              activeColor: Colors.green[700],
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Queja #${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility, color: Colors.blue),
                                          onPressed: () => _viewDetails(docId, report),
                                          tooltip: 'Ver detalles',
                                        ),
                                        if (userRole == 'empresa' || userRole == 'autoridad')
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteComplaint(docId, imageUrl),
                                            tooltip: 'Eliminar queja',
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow('Nombre Completo', fullName),
                                _buildDetailRow('Cédula', idNumber),
                                _buildDetailRow('Teléfono', phone),
                                _buildDetailRow('Descripción', description),
                                _buildDetailRow('Dirección', address),
                                _buildDetailRow('Barrio', neighborhood),
                                const SizedBox(height: 8),
                                Text(
                                  'Fecha: $formattedDate',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                isValidUrl
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: CachedNetworkImage(
                                          imageUrl: imageUrl!,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Center(child: CircularProgressIndicator(color: Colors.green)),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Center(child: Icon(Icons.error, color: Colors.red)),
                                          ),
                                        ),
                                      )
                                    : Container(
                                        height: 200,
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: Text(
                                            'No se proporcionó ninguna imagen',
                                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}