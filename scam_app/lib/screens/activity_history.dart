import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:intl/intl.dart'; // ✅ CONSERVÉ (contient DateFormat)
// import 'package:intl/date_symbol_data_local.dart'; // ❌ RETIRÉ (Inutilisé ici)

// Définition des périodes pour le sélecteur
enum TimeFrame { daily, weekly, monthly }

// Modèle pour stocker les données agrégées (Ex: Nombre d'échantillons par heure)
class ActivityAggregation {
  final DateTime hour; // L'heure de début de l'agrégation
  final int recordCount; // Nombre d'enregistrements pendant cette heure

  ActivityAggregation({required this.hour, required this.recordCount});
}

class ActiveDurationHistoryPage extends StatefulWidget {
  const ActiveDurationHistoryPage({super.key});

  @override
  State<ActiveDurationHistoryPage> createState() => _ActiveDurationHistoryPageState();
}

class _ActiveDurationHistoryPageState extends State<ActiveDurationHistoryPage> {
  TimeFrame _currentTimeFrame = TimeFrame.daily; 
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<ActivityAggregation>> _historyFuture;

  // Stats
  int _totalRecords = 0;
  double _avgRecordsPerHour = 0;
  int _maxRecordsPerHour = 0;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchActivityData(_currentTimeFrame);
  }
  
  void _changeTimeFrame(TimeFrame frame) {
    setState(() {
      _currentTimeFrame = frame;
      _historyFuture = _fetchActivityData(frame);
    });
  }

  // --- LOGIQUE DE RÉCUPÉRATION ET D'AGRÉGATION SUPABASE ---

  Future<List<ActivityAggregation>> _fetchActivityData(TimeFrame frame) async {
    DateTime startDate;
    switch (frame) {
      case TimeFrame.daily:
        startDate = DateTime.now().subtract(const Duration(hours: 24));
        break;
      case TimeFrame.weekly:
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case TimeFrame.monthly:
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
    }
    final isoStartDate = startDate.toIso8601String();

    try {
        final List<dynamic> response = await _supabase
            .from('capteurs_data')
            .select('timestamp')
            .gte('timestamp', isoStartDate)
            .order('timestamp', ascending: true);

        final Map<int, int> hourlyCounts = {}; 
        final records = response.map((json) => DateTime.parse(json['timestamp'])).toList();
        
        if (records.isEmpty) {
             _totalRecords = 0;
             _maxRecordsPerHour = 0;
             _avgRecordsPerHour = 0;
             return [];
        }

        _totalRecords = records.length;

        for (var timestamp in records) {
          int key;
          
          if (frame == TimeFrame.daily) {
            key = timestamp.hour; 
          } else if (frame == TimeFrame.weekly) {
            key = timestamp.weekday; 
          } else { 
            key = timestamp.day;
          }

          hourlyCounts[key] = (hourlyCounts[key] ?? 0) + 1;
        }

        final List<ActivityAggregation> aggregatedData = [];
        
        // Déterminer la plage d'heures/jours à afficher 
        int startKey = 0;
        int endKey = 0;
        
        if (frame == TimeFrame.daily) {
            startKey = 0; endKey = 23;
        } else if (frame == TimeFrame.weekly) {
            startKey = 1; endKey = 7;
        } else { 
            startKey = 1; endKey = DateTime.now().day; 
        }

        // Initialiser la liste avec toutes les heures/jours de la période
        for (int i = startKey; i <= endKey; i++) {
          final count = hourlyCounts[i] ?? 0;
          
          DateTime representativeTime;
          if (frame == TimeFrame.daily) {
              representativeTime = DateTime(startDate.year, startDate.month, startDate.day, i); 
          } else if (frame == TimeFrame.weekly) {
              representativeTime = DateTime.now().subtract(Duration(days: DateTime.now().weekday - i));
          } else { 
              representativeTime = DateTime(DateTime.now().year, DateTime.now().month, i);
          }

          aggregatedData.add(ActivityAggregation(
            hour: representativeTime,
            recordCount: count,
          ));
        }
        
        final counts = aggregatedData.map((a) => a.recordCount).toList();
        if (counts.isNotEmpty) {
            _maxRecordsPerHour = counts.reduce(max);
            _avgRecordsPerHour = counts.reduce((a, b) => a + b) / counts.length;
        }


        if (frame == TimeFrame.daily) {
            aggregatedData.sort((a, b) => a.hour.hour.compareTo(b.hour.hour));
        }

        return aggregatedData;

    } catch (e) {
      debugPrint('Supabase Error: $e');
      throw Exception('Impossible de charger les données d\'activité: ${e.toString()}');
    }
  }
  
  // Fonction pour obtenir le titre en bas du graphique (avec SideTitleWidget)
  Widget _getBottomTitle(double value, TitleMeta meta, List<ActivityAggregation> data) {
    final index = value.toInt();
    if (index < 0 || index >= data.length) return const SizedBox();

    final record = data[index];
    String label;

    switch (_currentTimeFrame) {
      case TimeFrame.daily:
        label = DateFormat('Hm').format(record.hour); 
        break;
      case TimeFrame.weekly:
        label = DateFormat('E', 'fr').format(record.hour); // Utilise la locale initialisée dans main.dart
        break;
      case TimeFrame.monthly:
        label = DateFormat('d').format(record.hour); 
        break;
    }
    
    // Logique d'affichage pour éviter la surcharge (inchangée)
    bool shouldShow = true;
    if (_currentTimeFrame == TimeFrame.daily && index % 3 != 0) shouldShow = false;
    if (_currentTimeFrame == TimeFrame.weekly && index % 1 != 0) shouldShow = true;
    if (_currentTimeFrame == TimeFrame.monthly && index % 5 != 0) shouldShow = false;

    if (!shouldShow) return const SizedBox();

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4.0,
      child: Text(label, style: const TextStyle(fontSize: 10)),
    );
  }

  // Widget pour l'affichage de la donnée actuelle (Total et Max)
  Widget _buildCurrentDataDisplay(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Historique d'activité",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total enregistrements", style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text(
                  _totalRecords.toString(),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text("Max Échantillons/Période", style: TextStyle(fontSize: 14, color: Colors.grey)),
                Text(
                  _maxRecordsPerHour.toString(),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeFrameSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: TimeFrame.values.map((frame) {
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeTimeFrame(frame),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _currentTimeFrame == frame
                      ? Colors.blueAccent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  _getTimeFrameLabel(frame),
                  style: TextStyle(
                    color: _currentTimeFrame == frame ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getTimeFrameLabel(TimeFrame frame) {
    switch (frame) {
      case TimeFrame.daily: return 'Jour (Heures)';
      case TimeFrame.weekly: return 'Semaine (Jours)';
      case TimeFrame.monthly: return 'Mois (Jours)';
    }
  }

  Widget _buildChartCard(bool isDark, List<ActivityAggregation> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    final barGroups = List.generate(data.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: data[i].recordCount.toDouble(),
            color: data[i].recordCount == _maxRecordsPerHour ? Colors.orangeAccent : Colors.blueAccent,
            width: 15,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(6),
              topRight: Radius.circular(6),
            ),
          ),
        ],
      );
    });

    final maxY = (_maxRecordsPerHour * 1.1).ceilToDouble();
    
    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barGroups: barGroups,
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) => _getBottomTitle(value, meta, data),
                reservedSize: 30,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          ),
        ),
      ),
    );
  }
  
  // Widget pour les statistiques clés
  Widget _buildStatsRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          title: "Total Mesures",
          value: _totalRecords.toString(),
          color: Colors.blue,
          isDark: isDark,
        ),
        _StatItem(
          title: "Moy/Période",
          value: _avgRecordsPerHour.toStringAsFixed(1),
          color: Colors.orange,
          isDark: isDark,
        ),
        _StatItem(
          title: "Max/Période",
          value: _maxRecordsPerHour.toString(),
          color: Colors.red,
          isDark: isDark,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique Durée d'Activité"),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<List<ActivityAggregation>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text('Erreur de chargement: ${snapshot.error}', textAlign: TextAlign.center),
            ));
          }

          final aggregatedData = snapshot.data ?? [];
          
          if (aggregatedData.isEmpty) {
            return const Center(
              child: Text("Aucune donnée d'activité trouvée pour cette période.", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentDataDisplay(isDark),
                const SizedBox(height: 20),
                _buildTimeFrameSelector(),
                const SizedBox(height: 30),
                
                _buildChartCard(isDark, aggregatedData),
                const SizedBox(height: 30),

                _buildStatsRow(isDark),
              ],
            ),
          );
        },
      ),
    );
  }
}

// Widget réutilisable pour afficher une statistique (inchangé)
class _StatItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool isDark;

  const _StatItem({
    required this.title,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}