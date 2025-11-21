import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'dart:math';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart'; 

// Définition des périodes pour le sélecteur
enum TimeFrame { daily, weekly, monthly }

// Modèle de données brut (MovementRecord - inchangé)
class MovementRecord {
  final DateTime timestamp;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double accelMagnitude;  
  final double gyroMagnitude;

  MovementRecord({
    required this.timestamp,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  }) : accelMagnitude = sqrt(pow(accelX, 2) + pow(accelY, 2) + pow(accelZ, 2)),
       gyroMagnitude = sqrt(pow(gyroX, 2) + pow(gyroY, 2) + pow(gyroZ, 2));

  factory MovementRecord.fromJson(Map<String, dynamic> json) {
    return MovementRecord(
      timestamp: DateTime.parse(json['timestamp']),
      accelX: (json['accel_x'] as num).toDouble(),
      accelY: (json['accel_y'] as num).toDouble(),
      accelZ: (json['accel_z'] as num).toDouble(),
      gyroX: (json['gyro_x'] as num).toDouble(),
      gyroY: (json['gyro_y'] as num).toDouble(),
      gyroZ: (json['gyro_z'] as num).toDouble(),
    );
  }
}

// Modèle: Agrégation par période
class AggregatedActivity {
  final DateTime periodStart;
  final double averageAccelMagnitude;
  final int recordCount;

  AggregatedActivity({required this.periodStart, required this.averageAccelMagnitude, required this.recordCount});
}


class StepsHistoryPage extends StatefulWidget {
  const StepsHistoryPage({super.key});

  @override
  State<StepsHistoryPage> createState() => _StepsHistoryPageState();
}

class _StepsHistoryPageState extends State<StepsHistoryPage> {
  TimeFrame _currentTimeFrame = TimeFrame.weekly;
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<AggregatedActivity>> _historyFuture; 

  // Stats
  double _minAccelMag = 0;
  double _maxAccelMag = 0;
  double _avgAccelMag = 0;
  double _minGyroMag = 0;
  double _maxGyroMag = 0;
  double _avgGyroMag = 0;
  
  List<MovementRecord> _currentRawRecords = [];


  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr', null);
    _historyFuture = _fetchAggregatedData(_currentTimeFrame);
  }
  
  void _changeTimeFrame(TimeFrame frame) {
    setState(() {
      _currentTimeFrame = frame;
      _historyFuture = _fetchAggregatedData(frame);
    });
  }

  // --- LOGIQUE DE RÉCUPÉRATION ET D'AGRÉGATION ---

  Future<List<AggregatedActivity>> _fetchAggregatedData(TimeFrame frame) async {
    DateTime startDate;
    // 🚨 CORRECTION SCOPE : Initialiser daysToFetch ici
    int daysToFetch = 0; 

    switch (frame) {
      case TimeFrame.daily:
        daysToFetch = 1;
        startDate = DateTime.now().subtract(const Duration(days: 1));
        break;
      case TimeFrame.weekly:
        daysToFetch = 7;
        startDate = DateTime.now().subtract(const Duration(days: 7));
        break;
      case TimeFrame.monthly:
        daysToFetch = 30;
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
    }
    final isoStartDate = startDate.toIso8601String();

    try {
      final List<dynamic> response = await _supabase
          .from('capteurs_data')
          .select('timestamp, accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z')
          .gte('timestamp', isoStartDate)
          .order('timestamp', ascending: true);

      final rawRecords = response.map((data) => MovementRecord.fromJson(data as Map<String, dynamic>)).toList();
      _currentRawRecords = rawRecords; 

      if (rawRecords.isEmpty) {
        _calculateGlobalStats(rawRecords);
        return [];
      }

      _calculateGlobalStats(rawRecords);
      
      return _aggregateDataByTimeframe(rawRecords, frame, daysToFetch);

    } catch (e) {
      debugPrint('Supabase Error: $e');
      throw Exception('Impossible de charger les données de mouvement: ${e.toString()}');
    }
  }

  void _calculateGlobalStats(List<MovementRecord> records) {
     if (records.isEmpty) {
        _minAccelMag = _maxAccelMag = _avgAccelMag = 0;
        _minGyroMag = _maxGyroMag = _avgGyroMag = 0;
        return;
    }

    final accelMags = records.map((r) => r.accelMagnitude).toList();
    _minAccelMag = accelMags.reduce(min);
    _maxAccelMag = accelMags.reduce(max);
    _avgAccelMag = accelMags.reduce((a, b) => a + b) / accelMags.length;

    final gyroMags = records.map((r) => r.gyroMagnitude).toList();
    _minGyroMag = gyroMags.reduce(min);
    _maxGyroMag = gyroMags.reduce(max);
    _avgGyroMag = gyroMags.reduce((a, b) => a + b) / gyroMags.length;
  }

  List<AggregatedActivity> _aggregateDataByTimeframe(
      List<MovementRecord> rawRecords, TimeFrame frame, int daysToFetch) { // daysToFetch renommé pour clarifier
    
    final Map<int, List<double>> periodMap = {};
    final Map<int, DateTime> periodStartMap = {};
    
    // Groupement par période
    for (var record in rawRecords) {
      int periodIndex;
      DateTime periodStartDate;
      
      if (frame == TimeFrame.daily) {
        periodIndex = record.timestamp.hour;
        periodStartDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day, record.timestamp.hour);
      } else if (frame == TimeFrame.weekly) {
        periodIndex = record.timestamp.weekday; 
        periodStartDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      } else { 
        periodIndex = record.timestamp.day;
        periodStartDate = DateTime(record.timestamp.year, record.timestamp.month, record.timestamp.day);
      }
      
      periodMap.putIfAbsent(periodIndex, () => []).add(record.accelMagnitude);
      periodStartMap[periodIndex] = periodStartDate;
    }

    final List<AggregatedActivity> aggregatedList = [];
    int totalPeriods = 0;
    
    // Déterminer la boucle de périodes
    if (frame == TimeFrame.daily) {
        totalPeriods = 24; 
    } else if (frame == TimeFrame.weekly) {
        totalPeriods = 7; 
    } else {
        totalPeriods = daysToFetch; // Utiliser le nombre de jours à afficher
    }

    for (int i = 0; i < totalPeriods; i++) {
        int periodKey = i;
        if (frame != TimeFrame.daily) {
             periodKey = i + 1; // 1-7 pour semaine, 1-30 pour mois
        }
        if (frame == TimeFrame.monthly && periodKey > 31) continue; // Éviter les jours inutiles

        final magnitudes = periodMap[periodKey];
        final count = magnitudes?.length ?? 0;
        
        DateTime start;
        if (count > 0) {
            start = periodStartMap[periodKey]!;
        } else {
            // Créer un placeholder de date/heure cohérent
            if (frame == TimeFrame.daily) {
                start = DateTime.now().subtract(Duration(hours: DateTime.now().hour - periodKey));
            } else if (frame == TimeFrame.weekly) {
                start = DateTime.now().subtract(Duration(days: DateTime.now().weekday - periodKey));
            } else {
                start = DateTime.now().subtract(Duration(days: daysToFetch - periodKey));
            }
        }
        
        final avgMag = count > 0 ? magnitudes!.reduce((a, b) => a + b) / count : 0.0;
        
        aggregatedList.add(AggregatedActivity(
            periodStart: start,
            averageAccelMagnitude: avgMag,
            recordCount: count,
        ));
    }
    
    aggregatedList.sort((a, b) => a.periodStart.compareTo(b.periodStart));
    
    // 🚨 Utilisation correcte de daysToFetch pour le filtrage final
    final filteredList = aggregatedList.where((a) => 
        a.periodStart.isAfter(
            DateTime.now()
                .subtract(Duration(days: daysToFetch)) 
                .subtract(const Duration(hours: 2))
        )).toList();
    
    return filteredList;
  }

  // Fonction pour afficher le titre de l'axe X dans BarChart
  Widget _getBottomTitle(double value, TitleMeta meta, List<AggregatedActivity> data) {
    final index = value.toInt();
    if (index < 0 || index >= data.length) return const SizedBox();
    
    final record = data[index];
    String label;

    // Logique pour afficher chaque barre (tous les jours de la semaine/mois)
    bool shouldShow = true;
    
    if (_currentTimeFrame == TimeFrame.daily) {
      // Afficher une heure sur 4 si c'est la vue jour
      shouldShow = index % 4 == 0;
      label = DateFormat('H', 'fr').format(record.periodStart); 
    } else if (_currentTimeFrame == TimeFrame.weekly) {
      // Afficher tous les jours
      label = DateFormat('E', 'fr').format(record.periodStart).substring(0, 1); 
    } else { // Monthly
      // Afficher tous les 5 jours
      shouldShow = index % 5 == 0;
      label = DateFormat('d', 'fr').format(record.periodStart); 
    }
    
    if (!shouldShow && index != data.length - 1 && _currentTimeFrame != TimeFrame.weekly) return const SizedBox();
    
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 4.0,
      child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    );
  }

  // Widget pour l'affichage de la donnée actuelle (AccX et GyroX) (inchangé)
  Widget _buildCurrentDataDisplay(bool isDark, MovementRecord? currentRecord) {
    final currentAccelX = currentRecord?.accelX.toStringAsFixed(0) ?? '0';
    final currentGyroX = currentRecord?.gyroX.toStringAsFixed(0) ?? '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Dernière mesure de mouvement",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text("Accel X: ", style: TextStyle(fontSize: 24, color: isDark ? Colors.white70 : Colors.black54)),
            Text(
              currentAccelX,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Text(" unités", style: TextStyle(fontSize: 18, color: Colors.blueAccent)),
          ],
        ),
        Row(
          children: [
            Text("Gyro X: ", style: TextStyle(fontSize: 24, color: isDark ? Colors.white70 : Colors.black54)),
            Text(
              currentGyroX,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Text(" unités", style: TextStyle(fontSize: 18, color: Colors.blueAccent)),
          ],
        ),
      ],
    );
  }

  String _getTimeFrameLabel(TimeFrame frame) {
    switch (frame) {
      case TimeFrame.daily: return 'Jour';
      case TimeFrame.weekly: return 'Semaine';
      case TimeFrame.monthly: return 'Mois';
    }
  }

  // Widget pour le sélecteur de période (inchangé)
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
  
  // Widget pour les statistiques clés (Min/Max/Moyenne) (inchangé)
  Widget _buildStatsRow(bool isDark) {
    return Column(
      children: [
        const Text("Statistiques d'Accélération (Magnitude)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              title: "Min (Acc)",
              value: _minAccelMag.toStringAsFixed(0),
              color: Colors.green,
              isDark: isDark,
            ),
            _StatItem(
              title: "Moy (Acc)",
              value: _avgAccelMag.toStringAsFixed(1),
              color: Colors.orange,
              isDark: isDark,
            ),
            _StatItem(
              title: "Max (Acc)",
              value: _maxAccelMag.toStringAsFixed(0),
              color: Colors.red,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text("Statistiques de Gyroscope (Magnitude)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              title: "Min (Gyro)",
              value: _minGyroMag.toStringAsFixed(0),
              color: Colors.green,
              isDark: isDark,
            ),
            _StatItem(
              title: "Moy (Gyro)",
              value: _avgGyroMag.toStringAsFixed(1),
              color: Colors.orange,
              isDark: isDark,
            ),
            _StatItem(
              title: "Max (Gyro)",
              value: _maxGyroMag.toStringAsFixed(0),
              color: Colors.red,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique Mouvement"),
        backgroundColor: Colors.blueAccent,
      ),
      // Utilisation du FutureBuilder pour gérer l'état de chargement
      body: FutureBuilder<List<AggregatedActivity>>(
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
          MovementRecord? currentRecord = _currentRawRecords.isNotEmpty ? _currentRawRecords.last : null;


          if (aggregatedData.isEmpty) {
            return const Center(
              child: Text("Aucune donnée d'historique de mouvement trouvée pour cette période.", 
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          // Préparation des groupes de barres
          final barGroups = List.generate(aggregatedData.length, (i) {
             final data = aggregatedData[i];
             return BarChartGroupData(
                x: i,
                barRods: [
                    BarChartRodData(
                        // Utiliser la magnitude moyenne comme valeur Y
                        toY: data.averageAccelMagnitude,
                        color: data.averageAccelMagnitude == _maxAccelMag ? Colors.redAccent : Colors.blueAccent,
                        width: 15,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(6),
                            topRight: Radius.circular(6),
                        ),
                    ),
                ],
             );
          });
          
          // L'axe Y max est maintenant basé sur la Magnitude Max Agrégée
          final chartMaxY = (_maxAccelMag * 1.1).ceilToDouble(); 
          final yInterval = chartMaxY / 4;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCurrentDataDisplay(isDark, currentRecord),
                const SizedBox(height: 20),
                _buildTimeFrameSelector(),
                const SizedBox(height: 30),
                
                // Affichage du BarChart
                _buildChartCard(isDark, barGroups, chartMaxY, yInterval, aggregatedData),
                const SizedBox(height: 30),
                
                _buildStatsRow(isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  // NOUVEAU WIDGET DE GRAPHIQUE À BARRES
  Widget _buildChartCard(bool isDark, List<BarChartGroupData> barGroups, double chartMaxY, double yInterval, List<AggregatedActivity> data) {
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
          alignment: BarChartAlignment.spaceAround,
          maxY: chartMaxY,
          minY: 0,
          barGroups: barGroups,
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
                reservedSize: 40,
                interval: yInterval,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(), // Affichage de la magnitude Accel
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1, // L'intervalle est de 1 pour chaque groupe de barres
                getTitlesWidget: (value, meta) => _getBottomTitle(value, meta, data), 
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
        ),
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