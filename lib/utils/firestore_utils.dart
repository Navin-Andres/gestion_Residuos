import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> updateExistingNotifications(FirebaseFirestore firestore, BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('No hay usuario autenticado para actualizar notificaciones en ${DateTime.now()}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debes iniciar sesión para actualizar notificaciones.')),
    );
    return;
  }
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