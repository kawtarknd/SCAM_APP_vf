import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 

// Le modèle VitalAlert (inchangé)
class VitalAlert {
  final DateTime timestamp;
  final double fcCorrigeeBpm; 
  final int spo2;
  final int mouvementCodeInt; 
  final String statutAlerte;
  final bool isCritical;

  VitalAlert({
    required this.timestamp,
    required this.fcCorrigeeBpm,
   required this.spo2,
    required this.mouvementCodeInt,
    required this.statutAlerte,
    required this.isCritical,
  });

  factory VitalAlert.fromJson(Map<String, dynamic> json) {
    return VitalAlert(
      timestamp: DateTime.parse(json['timestamp']),
      fcCorrigeeBpm: (json['fc_corrigee_bpm'] as num?)?.toDouble() ?? 0.0,
      spo2: (json['spo2'] as num?)?.toInt() ?? 0,
      mouvementCodeInt: (json['nap_mouvement_code'] as num?)?.toInt() ?? 0,
      statutAlerte: json['statut_alerte'] as String? ?? 'Normal',
      isCritical: json['is_critical'] as bool? ?? false,
    );
  }
  
  String get mouvementCodeDisplay {
    switch (mouvementCodeInt) {
      case 0:
        return 'Repos';
      case 1:
        return 'Faible';
      case 2:
        return 'Intense';
      default:
        return 'Code: ${mouvementCodeInt}';
    }
  }
}

class NotificationsScreen extends StatelessWidget {
  final SupabaseClient _supabase = Supabase.instance.client;

  NotificationsScreen({super.key});

  Stream<List<VitalAlert>> _getAlertsStream() {
    return _supabase
        .from('vitals_analysis') 
        .stream(primaryKey: ['timestamp'])
        .order('timestamp', ascending: false)
        .limit(50)
        .map((dataList) {
          final allRecords = dataList.map((item) => VitalAlert.fromJson(item)).toList();
          
          // FILTRE CÔTÉ FLUTTER: N'afficher que les alertes non normales ou critiques
          // (Note : on suppose que la DB ne renvoie pas "Alerte" avec is_critical=false, mais le filtre est maintenu)
          return allRecords.where((alert) => alert.isCritical || alert.statutAlerte != 'Normal').toList();
        });
  }

  // 🚨 COULEURS MISES À JOUR
  Color _getAlertColor(VitalAlert alert) {
    if (alert.isCritical) return Colors.red.shade700;       // Critique: Rouge
    if (alert.statutAlerte == 'Alerte') return Colors.blue;  // Alerte simple: Bleu 
    return Colors.green; 
  }
  
  IconData _getAlertIcon(VitalAlert alert) {
    if (alert.isCritical) return Icons.crisis_alert;
    if (alert.statutAlerte == 'Alerte') return Icons.warning_amber;
    return Icons.check_circle_outline;
  }
  
  // 🚨 WIDGET ACTION MESSAGE CORRIGÉ
  Widget _buildActionMessage(VitalAlert alert, Color accentColor, bool isDark) {
    
    // 1. GESTION DES ALERTES CRITIQUES (URGENT)
    if (alert.isCritical) {
      return const Text(
        "🚨 APPEL URGENT : Consultez immédiatement un médecin ou appelez les personnes d'urgence.",
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      );
    // 2. GESTION DES ALERTES SIMPLES (RECOMMANDATION)
    } else if (alert.statutAlerte == 'Alerte') { 
      return Row(
        children: [
          Icon(Icons.directions_run, color: Colors.blueAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            "Prenez une pause et faites des exercices de respiration.",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87, 
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Alertes et Notifications"),
        backgroundColor: Colors.redAccent, 
        elevation: 0,
      ),
      body: StreamBuilder<List<VitalAlert>>(
        stream: _getAlertsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Erreur de Stream: ${snapshot.error}', textAlign: TextAlign.center),
            ));
          }

          final alerts = snapshot.data ?? [];

          if (alerts.isEmpty) {
            return const Center(
              child: Text("Aucune alerte critique ou anormale trouvée.", 
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final accentColor = _getAlertColor(alert);
              
              // Style Mobile-Friendly et Dynamique
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      // 🚨 OMBRE DIFFERENCIÉE
                      color: alert.isCritical 
                          ? Colors.red.withOpacity(0.5) 
                          : Colors.blue.withOpacity(0.4), // Ombre bleue pour Alerte simple
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Indicateur de statut
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getAlertIcon(alert),
                            color: accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Titre et Heure
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.statutAlerte,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: accentColor, // Titre de la couleur de l'alerte
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd/MM HH:mm').format(alert.timestamp.toLocal()),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        // Marqueur d'urgence (si critique)
                        if (alert.isCritical)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'URGENT',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const Divider(height: 15, thickness: 0.5),
                    
                    // 🚨 MESSAGE D'ACTION DYNAMIQUE
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: _buildActionMessage(alert, accentColor, isDark),
                    ),
                    
                    const Divider(height: 15, thickness: 0.5),
                    
                    // Détails des données vitales
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DetailStat(
                          title: 'FC Corrigée',
                          value: '${alert.fcCorrigeeBpm.toStringAsFixed(0)} bpm',
                          color: Colors.blueAccent,
                          isDark: isDark,
                        ),
                        _DetailStat(
                          title: 'Mouvement',
                          value: alert.mouvementCodeDisplay,
                          color: accentColor,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// WIDGET POUR L'AFFICHAGE DES DÉTAILS COMPACTS (inchangé)
class _DetailStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool isDark;

  const _DetailStat({
    required this.title,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}