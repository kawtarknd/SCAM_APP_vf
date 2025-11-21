import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

// Définition des périodes pour le sélecteur
enum TimeFrame { daily, weekly, monthly }

// 🚨 Modèle de données pour le SpO2
class Spo2Data {
  final DateTime timestamp;
  final int spo2; // Généralement stocké en pourcentage (int)

  Spo2Data({required this.timestamp, required this.spo2});

  factory Spo2Data.fromJson(Map<String, dynamic> json) {
    return Spo2Data(
      timestamp: DateTime.parse(json['timestamp']),
      // La valeur SpO2 est stockée en INT dans votre code ESP32
      spo2: (json['spo2'] as num).toInt(),
    );
  }
}

class Spo2HistoryPage extends StatefulWidget {
  const Spo2HistoryPage({super.key});

  @override
  State<Spo2HistoryPage> createState() => _Spo2HistoryPageState();
}

class _Spo2HistoryPageState extends State<Spo2HistoryPage> {
  TimeFrame _currentTimeFrame = TimeFrame.weekly;
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Spo2Data>> _historyFuture;

  // Variables pour les statistiques (calculées dans le FutureBuilder)
  int _minSpO2 = 0;
  int _maxSpO2 = 0;
  double _avgSpO2 = 0;
  int _currentSpO2 = 0;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistoryData(_currentTimeFrame);
  }
  
  void _changeTimeFrame(TimeFrame frame) {
    setState(() {
      _currentTimeFrame = frame;
      _historyFuture = _fetchHistoryData(frame);
    });
  }

  // --- LOGIQUE DE RÉCUPÉRATION SUPABASE ---

  Future<List<Spo2Data>> _fetchHistoryData(TimeFrame frame) async {
    DateTime startDate;
    switch (frame) {
      case TimeFrame.daily:
        startDate = DateTime.now().subtract(const Duration(days: 1));
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
      // Requête Supabase : Sélectionner 'timestamp' et 'spo2'
      final List<dynamic> response = await _supabase
          .from('capteurs_data')
          .select('timestamp, spo2')
          .gte('timestamp', isoStartDate)
          .order('timestamp', ascending: true);

      return response.map((data) => Spo2Data.fromJson(data as Map<String, dynamic>)).toList();

    } catch (e) {
      debugPrint('Supabase Error: $e');
      throw Exception('Impossible de charger les données SpO2: ${e.toString()}');
    }
  }

  // --- Widgets de construction ---

  // Fonction pour obtenir le titre en bas du graphique
  Widget _getBottomTitle(double value, TitleMeta meta, List<Spo2Data> records) {
    final index = value.toInt();
    if (records.isEmpty || index < 0 || index >= records.length) {
      return const SizedBox();
    }
    
    // Afficher seulement un point sur 10 (ou le dernier) pour désencombrer l'axe
    if (index % 10 != 0 && index != records.length - 1) {
      return const SizedBox();
    }
    
    final record = records[index];
    final time = '${record.timestamp.hour.toString().padLeft(2, '0')}h${record.timestamp.minute.toString().padLeft(2, '0')}';
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(time, style: const TextStyle(fontSize: 10)),
    );
  }

  Widget _buildCurrentDataDisplay(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Saturation actuelle",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "$_currentSpO2",
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 4),
              child: Text(
                "%",
                style: TextStyle(fontSize: 24, color: Colors.blueAccent),
              ),
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
      case TimeFrame.daily: return 'Jour';
      case TimeFrame.weekly: return 'Semaine';
      case TimeFrame.monthly: return 'Mois';
    }
  }

  Widget _buildChartCard(bool isDark, List<FlSpot> spots, double minY, double maxY, double maxX, List<Spo2Data> records) {
    // L'intervalle Y est généralement faible pour le SpO2 (entre 90 et 100)
    final yInterval = 1.0; 

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
                interval: yInterval,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => _getBottomTitle(value, meta, records),
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
              color: Colors.redAccent, // Utiliser le rouge pour le SpO2
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.redAccent.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatItem(
          title: "Min (%)",
          value: _minSpO2.toString(),
          color: Colors.red,
          isDark: isDark,
        ),
        _StatItem(
          title: "Moy (%)",
          value: _avgSpO2.toStringAsFixed(1),
          color: Colors.orange,
          isDark: isDark,
        ),
        _StatItem(
          title: "Max (%)",
          value: _maxSpO2.toString(),
          color: Colors.green,
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
        title: const Text("Historique SpO2"),
        backgroundColor: Colors.redAccent,
      ),
      body: FutureBuilder<List<Spo2Data>>(
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
          List<FlSpot> spo2Spots = [];
          List<int> spo2Values = [];
          
          if (records.isNotEmpty) {
            
            for (int i = 0; i < records.length; i++) {
              final data = records[i];
              // SpO2 doit être > 0
              if (data.spo2 > 0) {
                 spo2Spots.add(FlSpot(i.toDouble(), data.spo2.toDouble()));
                 spo2Values.add(data.spo2);
              }
            }
            
            if (spo2Values.isNotEmpty) {
              _minSpO2 = spo2Values.reduce(min);
              _maxSpO2 = spo2Values.reduce(max);
              _avgSpO2 = spo2Values.reduce((a, b) => a + b) / spo2Values.length;
              _currentSpO2 = spo2Values.last;
            } else {
              _minSpO2 = _maxSpO2 = _currentSpO2 = 0;
              _avgSpO2 = 0;
            }
          }

          if (spo2Spots.isEmpty) {
            return const Center(
              child: Text("Aucune donnée d'historique SpO2 trouvée pour cette période.", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }
          
          // Définir la plage Y entre 90% et 100% ou autour des données réelles
          final chartMinY = max(90, (_minSpO2 - 2)).toDouble();
          final chartMaxY = min(100, (_maxSpO2 + 2)).toDouble();
          final chartMaxX = (spo2Spots.length - 1).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentDataDisplay(isDark),
                const SizedBox(height: 20),
                _buildTimeFrameSelector(),
                const SizedBox(height: 30),
                
                _buildChartCard(isDark, spo2Spots, chartMinY, chartMaxY, chartMaxX, records),
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