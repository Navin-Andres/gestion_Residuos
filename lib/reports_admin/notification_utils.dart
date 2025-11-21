import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> createNotification(FirebaseFirestore firestore, String userId, String title, String message, String role) async {
  try {
    final currentUser = FirebaseAuth.instance.currentUser;
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
    await firestore.collection('notifications').add(notificationData);
    print('Notificación creada para userId: $userId, responderEmail: $responderEmail en ${DateTime.now()}');
  } catch (e) {
    print('Error al crear notificación: $e en ${DateTime.now()}');
  }
}

Future<void> updateExistingNotifications(BuildContext context, FirebaseFirestore firestore) async {
  try {
    final snapshot = await firestore.collection('notifications').get();
    final batch = firestore.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['title'] == 'Queja Enviada' || data['title'] == 'Nueva Queja Recibida') {
        if (data['senderName'] != null && data['senderEmail'] == null) {
          final userDoc = await firestore.collection('users').doc(data['userId']).get();
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