import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:intl/intl.dart'; // Conservé pour le formatage d'heure

// 🚨 SIMPLIFICATION : Seule la période 'daily' est conservée
enum TimeFrame { daily }

// Structure de données (inchangée)
class HeartRateData {
  final DateTime timestamp;
  final int bpm;

  HeartRateData({required this.timestamp, required this.bpm});

  factory HeartRateData.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.parse(json['timestamp']);
    final bpm = (json['bpm'] as num).toInt(); 
    return HeartRateData(timestamp: timestamp, bpm: bpm);
  }
}

class HeartRateHistoryPage extends StatefulWidget {
  const HeartRateHistoryPage({super.key});

  @override
  State<HeartRateHistoryPage> createState() => _HeartRateHistoryPageState();
}

class _HeartRateHistoryPageState extends State<HeartRateHistoryPage> {
  // 🚨 Démarrer par défaut sur la seule option disponible
  TimeFrame _currentTimeFrame = TimeFrame.daily; 
  
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<HeartRateData>> _historyFuture;

  @override
  void initState() {
    super.initState();
    // Charger immédiatement la vue "Jour"
    _historyFuture = _fetchHistoryData(_currentTimeFrame);
  }

  // --- LOGIQUE DE RÉCUPÉRATION SUPABASE ---

  Future<List<HeartRateData>> _fetchHistoryData(TimeFrame frame) async {
    // Limite pour la performance
    const int MAX_POINTS_TO_SHOW = 150; 
    
    // Logique pour ne prendre que les dernières 24 heures (Jour)
    DateTime startDate = DateTime.now().subtract(const Duration(days: 1));
    final isoStartDate = startDate.toIso8601String();

    try {
      final List<dynamic> response = await _supabase
          .from('capteurs_data')
          .select('timestamp, bpm')
          .gte('timestamp', isoStartDate)
          .order('timestamp', ascending: false) // DESC pour limiter les plus récents
          .limit(MAX_POINTS_TO_SHOW); 

      final records = response.map((data) => HeartRateData.fromJson(data as Map<String, dynamic>)).toList();
      
      // Inverser pour l'ordre chronologique sur le graphique
      return records.reversed.toList(); 

    } catch (e) {
      debugPrint('Erreur Supabase: $e');
      throw Exception('Impossible de charger les données d\'historique depuis Supabase: ${e.toString()}');
    }
  }

  void _changeTimeFrame(TimeFrame frame) {
    // Puisque seul 'daily' existe, on charge immédiatement sans basculer l'état
    setState(() {
      _currentTimeFrame = frame;
      _historyFuture = _fetchHistoryData(frame);
    });
  }

  // 🚨 Fonction pour afficher l'heure sur l'axe X (Simplifiée)
  Widget _getBottomTitle(double value, TitleMeta meta, List<HeartRateData> records) {
    final index = value.toInt();
    if (index < 0 || index >= records.length) return const SizedBox();
    
    final record = records[index];
    
    // Afficher seulement un titre sur X points pour éviter la surcharge
    // Ex: Afficher une étiquette toutes les 20 points
    if (index % 20 != 0 && index != records.length - 1) return const SizedBox(); 
    
    // Afficher l'heure (Ex: 14:30)
    final label = DateFormat('Hm').format(record.timestamp); 

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }


  // --- WIDGET PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique Cardiaque"),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<List<HeartRateData>>(
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

          final records = snapshot.data ?? [];
          List<FlSpot> heartRateSpots = [];
          List<int> bpms = [];
          int minBPM = 0;
          int maxBPM = 0;
          double avgBPM = 0;
          int currentBPM = 0;
          
          if (records.isNotEmpty) {
            
            for (int i = 0; i < records.length; i++) {
              final data = records[i];
              if (data.bpm > 0) {
                 heartRateSpots.add(FlSpot(i.toDouble(), data.bpm.toDouble()));
                 bpms.add(data.bpm);
              }
            }
            
            if (bpms.isNotEmpty) {
              minBPM = bpms.reduce(min);
              maxBPM = bpms.reduce(max);
              avgBPM = bpms.reduce((a, b) => a + b) / bpms.length;
              currentBPM = bpms.last;
            }
          }

          if (heartRateSpots.isEmpty) {
            return const Center(
              child: Text("Aucune donnée d'historique de fréquence cardiaque trouvée pour cette période (24h).", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          final chartMinY = max(0, (minBPM - 5)).toDouble();
          final chartMaxY = (maxBPM + 5).toDouble();
          final chartMaxX = (heartRateSpots.length - 1).toDouble();
          
          // Intervalle des labels basé sur le nombre de points pour afficher environ 8 étiquettes
          final interval = (heartRateSpots.length / 8).ceilToDouble(); 

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentDataDisplay(currentBPM, isDark),
                const SizedBox(height: 20),
                _buildTimeFrameSelector(), // Affiche uniquement "Jour"
                const SizedBox(height: 30),
                
                // 🚨 Affichage du LineChart
                _buildChartCard(isDark, heartRateSpots, chartMinY, chartMaxY, chartMaxX, records, interval),
                const SizedBox(height: 30),

                _buildStatsRow(isDark, minBPM, avgBPM.round(), maxBPM),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Widgets de construction ---

  Widget _buildCurrentDataDisplay(int bpm, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Fréquence actuelle",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$bpm",
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 4),
              child: Text(
                "bpm",
                style: TextStyle(fontSize: 24, color: Colors.blueAccent),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget de sélection de période adapté (affiche uniquement "Jour")
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
        // N'affiche que le bouton "Jour"
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
                child: const Text(
                  'Jour', 
                  style: TextStyle(
                    color: Colors.white,
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
    // Logique simplifiée
    switch (frame) {
      case TimeFrame.daily: return 'Jour';
    }
    return ''; 
  }

  // 🚨 WIDGET DE GRAPHIQUE RESTAURÉ EN LIGNE (LineChart)
  Widget _buildChartCard(bool isDark, List<FlSpot> spots, double minY, double maxY, double maxX, List<HeartRateData> records, double interval) {
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
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
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
                reservedSize: 30,
                interval: 5,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: interval, // Intervalle calculé
                getTitlesWidget: (value, meta) => _getBottomTitle(value, meta, records), // Affichage des heures
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
              width: 1,
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blueAccent.withOpacity(0.3),
              ),
            ),
          ],
          // NOTE: LineChart n'utilise PAS barTouchData, il utilise LineTouchData
          // Nous n'incluons pas LineTouchData ici pour éviter d'introduire de nouvelles erreurs
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, int minBPM, int avgBPM, int maxBPM) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          title: "Min (bpm)",
          value: minBPM.toString(),
          color: Colors.green,
          isDark: isDark,
        ),
        _StatItem(
          title: "Moy (bpm)",
          value: avgBPM.toString(),
          color: Colors.orange,
          isDark: isDark,
        ),
        _StatItem(
          title: "Max (bpm)",
          value: maxBPM.toString(),
          color: Colors.blue,
          isDark: isDark,
        ),
      ],
    );
  }
}

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