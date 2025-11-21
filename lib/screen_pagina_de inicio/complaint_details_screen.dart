import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ComplaintDetailsScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> report;
  final String? userRole;
  final Function(String) onSendResponse;
  final VoidCallback onDelete;

  const ComplaintDetailsScreen({
    super.key,
    required this.docId,
    required this.report,
    required this.userRole,
    required this.onSendResponse,
    required this.onDelete,
  });

  @override
  _ComplaintDetailsScreenState createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  final TextEditingController _responseController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fetchUserEmail();
  }

  Future<void> _fetchUserEmail() async {
    final userId = widget.report['userId'] as String?;
    if (userId != null) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final email = userDoc.data()?['email'] ?? 'No disponible';
      setState(() {
        widget.report['userEmail'] = email;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final textScale = screenWidth < 600 ? 1.0 : 1.2;
    final padding = EdgeInsets.symmetric(horizontal: screenWidth < 600 ? 16.0 : 24.0, vertical: 20.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Responder Queja',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20 * textScale,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.white,
        padding: padding,
        child: SingleChildScrollView(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detalles del Usuario',
                    style: TextStyle(
                      fontSize: 18 * textScale,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nombre: ${widget.report['fullName'] ?? 'Sin nombre'}',
                          style: TextStyle(
                            fontSize: 16 * textScale,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Correo: ${widget.report['userEmail'] ?? 'Cargando...'}',
                          style: TextStyle(
                            fontSize: 14 * textScale,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Redactar Respuesta',
                    style: TextStyle(
                      fontSize: 18 * textScale,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _responseController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu respuesta aquí...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.green.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.green.shade50,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.userRole == 'empresa' || widget.userRole == 'administrador') ...[
                        ElevatedButton(
                          onPressed: widget.onDelete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            'Eliminar Queja',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * textScale),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      ElevatedButton(
                        onPressed: () {
                          if (_responseController.text.isNotEmpty) {
                            widget.onSendResponse(_responseController.text);
                            _responseController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Respuesta enviada'),
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            Future.delayed(const Duration(seconds: 2), () {
                              Navigator.pop(context);
                            });
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Por favor, escribe una respuesta.'),
                                backgroundColor: Colors.red.shade700,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text(
                          'Enviar Respuesta',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * textScale),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}