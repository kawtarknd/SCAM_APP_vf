import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const SettingsScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool isDark;

  @override
  void initState() {
    super.initState();
    isDark = widget.isDark; // initialise le switch selon l’état actuel
  }

  // Déconnexion avec confirmation
  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Se déconnecter"),
        content: const Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Oui"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text(
          "Paramètres",
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              // Notifications
              ListTile(
                leading: const Icon(Icons.notifications_none, color: Colors.blue),
                title: Text("Notifications",
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                trailing: Switch(
                  value: true,
                  onChanged: (val) {},
                  activeThumbColor: Colors.blue,
                ),
              ),
              const Divider(),

              // Mode sombre / clair
              ListTile(
                leading: const Icon(Icons.dark_mode, color: Colors.blue),
                title: Text("Mode sombre",
                    style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) {
                    setState(() {
                      isDark = val;
                    });
                    widget.toggleTheme(val);
                  },
                  activeThumbColor: Colors.blue,
                ),
              ),
              const Divider(),

              

              // Déconnexion
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.blueAccent),
                title: const Text(
                  "Se déconnecter",
                  style: TextStyle(color: Colors.blueAccent),
                ),
                onTap: () => _signOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
