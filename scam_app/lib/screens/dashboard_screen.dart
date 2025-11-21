import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'heart_rate_history_page.dart';
import 'steps_history_page.dart';
import 'spo2_history.dart';
import 'activity_history.dart';

class DashboardScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const DashboardScreen({
    super.key,
    required this.toggleTheme,
    required this.isDark,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final _auth = FirebaseAuth.instance;
  String _userName = "Utilisateur";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? "Utilisateur";
      });
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const _HomePage(),
      NotificationsScreen(),
      const ProfileScreen(),
      SettingsScreen(toggleTheme: widget.toggleTheme, isDark: widget.isDark),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  DatabaseReference get _vitalsRef => FirebaseDatabase.instance.ref('vitals');

  Widget _buildVitalsStream(BuildContext context) {
    return StreamBuilder(
      stream: _vitalsRef.onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        int bpm = 0;
        double spo2 = 0.0;
        int accelX = 0;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          print('Erreur Realtime DB: ${snapshot.error}');
          return const Center(child: Text("Erreur de connexion aux données."));
        } else if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          final data = snapshot.data!.snapshot.value as Map?;
          if (data != null) {
            bpm = data['bpm'] is int ? data['bpm'] : (data['bpm'] as num?)?.toInt() ?? 0;
            spo2 = (data['spo2'] as num?)?.toDouble() ?? 0.0;

            final accelList = data['accel'] is List ? data['accel'] as List<dynamic> : null;
            if (accelList != null && accelList.isNotEmpty) {
              accelX = (accelList[0] as num?)?.toInt() ?? 0;
            }
          }
        }

        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _StatCard(
              icon: Icons.favorite,
              title: "Fréquence Cardiaque",
              value: "${bpm > 0 ? bpm : '--'} bpm",
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HeartRateHistoryPage(),
                  ),
                );
              },
            ),
            _StatCard(
              icon: Icons.directions_walk,
              title: "Mouvement (Acc X)",
              value: "${accelX > 0 ? accelX : '--'}",
              color: Colors.deepOrangeAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StepsHistoryPage(),
                  ),
                );
              },
            ),
            _StatCard(
              icon: Icons.local_fire_department,
              title: "Saturation SPO2",
              value: "${spo2 > 0.0 ? spo2.toStringAsFixed(1) : '--'} %",
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Spo2HistoryPage(), 
                  ),
                );
              },
            ),
            _StatCard(
              icon: Icons.access_time,
              title: "Actif (Durée)",
              value: "Aggregé",
              color: Colors.indigoAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ActiveDurationHistoryPage(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "Utilisateur";

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bienvenue, $userName",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Suivez vos données cardiaques et vos mouvements.",
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: NetworkImage(
                        user?.photoURL ?? 'https://i.pravatar.cc/150',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black54,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Navigator.of(context).pushNamed('/notifications');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Colors.blue,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),

            Expanded(
              child: _buildVitalsStream(context),
            ),
          ],
        ),
      ),
    );
  }
}

/////////////////////////////////////////////////////////////////////////
//      🟦 VERSION `_StatCard` CORRIGÉE — PLUS AUCUN OVERFLOW
/////////////////////////////////////////////////////////////////////////

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Icon(icon, color: color, size: 34),

            FittedBox(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),

            FittedBox(
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
