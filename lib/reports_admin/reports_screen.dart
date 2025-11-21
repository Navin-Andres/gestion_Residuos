import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'mobile_report_card.dart';
import 'desktop_report_card.dart';
import 'complaint_actions.dart';
import 'notification_utils.dart';
import 'navigation_utils.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final textScale = screenWidth < 600 ? 1.0 : screenWidth < 1200 ? 1.1 : 1.3;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;
    final isMobile = screenWidth < 600;

    final padding = isDesktop
        ? const EdgeInsets.symmetric(horizontal: 48, vertical: 24)
        : isTablet
            ? const EdgeInsets.symmetric(horizontal: 32, vertical: 20)
            : const EdgeInsets.all(16);

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
              fontSize: isDesktop ? 24 : 20,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.green.shade700,
          elevation: isDesktop ? 0 : 2,
          centerTitle: isMobile,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, size: isDesktop ? 24 : 20),
            onPressed: () {
              Navigator.pushNamed(context, '/admin');
            },
          ),
          actions: [
            if (userRole == 'empresa' || userRole == 'administrador') ...[
              if (isDesktop) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: Text(_selectedComplaints.isNotEmpty ? 'Eliminar (${_selectedComplaints.length})' : 'Eliminar Todas'),
                    onPressed: _selectedComplaints.isNotEmpty ? () => deleteSelectedComplaints(context, _selectedComplaints, userRole, _firestore) : () => deleteAllComplaints(context, _selectedComplaints, userRole, _firestore),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.update, size: 18),
                    label: const Text('Actualizar'),
                    onPressed: () => updateExistingNotifications(context, _firestore),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ] else ...[
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: _selectedComplaints.isNotEmpty ? 'Eliminar seleccionadas' : 'Eliminar todas',
                  onPressed: _selectedComplaints.isNotEmpty ? () => deleteSelectedComplaints(context, _selectedComplaints, userRole, _firestore) : () => deleteAllComplaints(context, _selectedComplaints, userRole, _firestore),
                ),
                IconButton(
                  icon: const Icon(Icons.update),
                  tooltip: 'Actualizar notificaciones',
                  onPressed: () => updateExistingNotifications(context, _firestore),
                ),
              ],
            ],
            const SizedBox(width: 8),
          ],
          toolbarHeight: isDesktop ? 72 : 56,
        ),
        body: Container(
          color: isDesktop ? Colors.grey.shade50 : Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 1400 : 800),
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

                      if (isDesktop || isTablet) {
                        return SingleChildScrollView(
                          child: Container(
                            padding: padding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedComplaints.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_selectedComplaints.length} quejas seleccionadas',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _selectedComplaints.clear();
                                            });
                                          },
                                          child: const Text('Limpiar selección'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ...reports.map((reportDoc) => buildDesktopReportCard(context, reportDoc, textScale, isDesktop, isTablet, _selectedComplaints, userRole, (docId, report) => viewDetails(context, docId, report, userRole, _firestore))).toList(),
                              ],
                            ),
                          ),
                        );
                      } else {
                        return SingleChildScrollView(
                          child: Container(
                            padding: padding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedComplaints.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${_selectedComplaints.length} quejas seleccionadas',
                                          style: TextStyle(
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _selectedComplaints.clear();
                                            });
                                          },
                                          child: const Text('Limpiar'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ...reports.map((reportDoc) => buildMobileReportCard(context, reportDoc, textScale, _selectedComplaints, userRole, (docId, report) => viewDetails(context, docId, report, userRole, _firestore))).toList(),
                              ],
                            ),
                          ),
                        );
                      }
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