import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'complaint_actions.dart';
import 'navigation_utils.dart';

Widget buildDesktopReportCard(
  BuildContext context,
  QueryDocumentSnapshot reportDoc,
  double textScale,
  bool isDesktop,
  bool isTablet,
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
  final idNumber = report['idNumber']?.toString() ?? 'No disponible'; // Convertir a string
  final phone = report['phone']?.toString() ?? 'No disponible'; // Convertir a string
  final description = report['description'] ?? 'Sin descripción';
  final address = report['address']?.toString() ?? 'Sin dirección'; // Convertir a string
  final neighborhood = report['neighborhood']?.toString() ?? 'Sin barrio'; // Convertir a string
  final imageUrl = report['imageUrl'] as String?;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    child: Card(
      elevation: isDesktop ? 3 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => viewDetails(docId, report),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (userRole == 'empresa' || userRole == 'administrador')
                Container(
                  margin: const EdgeInsets.only(right: 16, top: 4),
                  child: Checkbox(
                    value: selectedComplaints.contains(docId),
                    onChanged: (value) {
                      if (value == true) {
                        selectedComplaints.add(docId);
                      } else {
                        selectedComplaints.remove(docId);
                      }
                    },
                    activeColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              Container(
                width: isDesktop ? 120 : 100,
                height: isDesktop ? 120 : 100,
                margin: const EdgeInsets.only(right: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.green.shade700,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.error_outline, color: Colors.red),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported_outlined,
                                size: isDesktop ? 32 : 24,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sin imagen',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            fullName,
                            style: TextStyle(
                              fontSize: isDesktop ? 20 : 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.green.shade800,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                          fontSize: isDesktop ? 15 : 14,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildDesktopInfoRow('Cédula', idNumber, Icons.badge_outlined),
                              const SizedBox(height: 8),
                              buildDesktopInfoRow('Teléfono', phone, Icons.phone_outlined),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              buildDesktopInfoRow('Barrio', neighborhood, Icons.location_city_outlined),
                              const SizedBox(height: 8),
                              buildDesktopInfoRow('Dirección', address, Icons.location_on_outlined),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (userRole == 'empresa' || userRole == 'administrador') ...[
                    ElevatedButton.icon(
                      icon: const Icon(Icons.reply_outlined, size: 18),
                      label: const Text('Responder Queja'),
                      onPressed: () => viewDetails(docId, report),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        minimumSize: Size(isDesktop ? 160 : 140, 44),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    ElevatedButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Ver Detalles'),
                      onPressed: () => viewDetails(docId, report),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        minimumSize: Size(isDesktop ? 160 : 140, 44),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget buildDesktopInfoRow(String label, String value, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.green.shade200),
    ),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.green.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}