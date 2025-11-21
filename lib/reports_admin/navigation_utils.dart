import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../screen_pagina_de inicio/complaint_details_screen.dart';
import 'notification_utils.dart';
import 'complaint_actions.dart';

Future<void> viewDetails(BuildContext context, String docId, Map<String, dynamic> report, String? userRole, FirebaseFirestore firestore) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ComplaintDetailsScreen(
        docId: docId,
        report: report,
        userRole: userRole,
        onSendResponse: (response) async {
          try {
            await createNotification(
              firestore,
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
        onDelete: () => deleteComplaint(context, docId, report['imageUrl'], userRole, firestore),
      ),
    ),
  );
}