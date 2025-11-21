import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'complaint_actions.dart';
import 'navigation_utils.dart';

Widget buildMobileReportCard(
  BuildContext context,
  QueryDocumentSnapshot reportDoc,
  double textScale,
  Set<String> selectedComplaints,
  String? userRole,
  Function(String, Map<String, dynamic>) viewDetails,
) {
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
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => viewDetails(docId, report),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (userRole == 'empresa' || userRole == 'administrador')
                      Checkbox(
                        value: selectedComplaints.contains(docId),
                        onChanged: (value) {
                          if (value == true) {
                            selectedComplaints.add(docId);
                          } else {
                            selectedComplaints.remove(docId);
                          }
                        },
                        activeColor: Colors.green.shade700,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    Expanded(
                      child: Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formattedDate.split(',')[0],
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    buildMobileInfoChip('Cédula', idNumber, Icons.badge_outlined),
                    buildMobileInfoChip('Tel', phone, Icons.phone_outlined),
                    buildMobileInfoChip('$neighborhood, $address', '', Icons.location_on_outlined, isLocation: true),
                  ],
                ),
                const SizedBox(height: 12),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.green.shade700,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.error_outline, color: Colors.red),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 32,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sin imagen',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (userRole == 'empresa' || userRole == 'administrador') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.reply_outlined, size: 16),
                          label: const Text('Responder Queja'),
                          onPressed: () => viewDetails(docId, report),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: Colors.red.shade600),
                        onPressed: () => deleteComplaint(context, docId, imageUrl, userRole, FirebaseFirestore.instance),
                        tooltip: 'Eliminar queja',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ] else
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.visibility_outlined, size: 16),
                          label: const Text('Ver Detalles'),
                          onPressed: () => viewDetails(docId, report),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Widget buildMobileInfoChip(String label, String value, IconData icon, {bool isLocation = false}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.green.shade200),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.green.shade700),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isLocation ? label : '$label: $value',
            style: TextStyle(
              color: Colors.green.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}