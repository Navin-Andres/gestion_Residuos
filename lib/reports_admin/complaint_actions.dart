import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'notification_utils.dart';

Future<void> deleteComplaint(BuildContext context, String docId, String? imageUrl, String? userRole, FirebaseFirestore firestore) async {
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
    final complaintDoc = await firestore.collection('complaints').doc(docId).get();
    final complaintData = complaintDoc.data();
    final complaintUserId = complaintData?['userId'] as String?;
    if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
      try {
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        await ref.delete();
        print('Imagen eliminada: $imageUrl en ${DateTime.now()}');
      } catch (e) {
        print('Error al eliminar imagen: $e en ${DateTime.now()}');
      }
    }
    await firestore.collection('complaints').doc(docId).delete();
    print('Queja eliminada: $docId en ${DateTime.now()}');
    if (complaintUserId != null) {
      await createNotification(firestore, complaintUserId, 'Queja Eliminada', 'Tu queja ha sido eliminada por una empresa o administrador.', 'usuario');
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

Future<void> deleteSelectedComplaints(BuildContext context, Set<String> selectedComplaints, String? userRole, FirebaseFirestore firestore) async {
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
    for (final docId in selectedComplaints) {
      final complaintDoc = await firestore.collection('complaints').doc(docId).get();
      final complaintData = complaintDoc.data();
      final imageUrl = complaintData?['imageUrl'] as String?;
      final complaintUserId = complaintData?['userId'] as String?;
      if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
          print('Imagen eliminada: $imageUrl en ${DateTime.now()}');
        } catch (e) {
          print('Error al eliminar imagen: $e en ${DateTime.now()}');
        }
      }
      await firestore.collection('complaints').doc(docId).delete();
      print('Queja eliminada: $docId en ${DateTime.now()}');
      if (complaintUserId != null) {
        await createNotification(firestore, complaintUserId, 'Queja Eliminada', 'Tu queja ha sido eliminada por una empresa o administrador.', 'usuario');
      }
    }
    selectedComplaints.clear();
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

Future<void> deleteAllComplaints(BuildContext context, Set<String> selectedComplaints, String? userRole, FirebaseFirestore firestore) async {
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
    final snapshot = await firestore.collection('complaints').get();
    for (final doc in snapshot.docs) {
      final complaintData = doc.data();
      final imageUrl = complaintData['imageUrl'] as String?;
      final complaintUserId = complaintData['userId'] as String?;
      if (imageUrl != null && imageUrl.contains('firebasestorage.googleapis.com')) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(imageUrl);
          await ref.delete();
          print('Imagen eliminada: $imageUrl en ${DateTime.now()}');
        } catch (e) {
          print('Error al eliminar imagen: $e en ${DateTime.now()}');
        }
      }
      await doc.reference.delete();
      print('Queja eliminada: ${doc.id} en ${DateTime.now()}');
      if (complaintUserId != null) {
        await createNotification(firestore, complaintUserId, 'Queja Eliminada', 'Tu queja ha sido eliminada por una empresa o administrador.', 'usuario');
      }
    }
    selectedComplaints.clear();
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