import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();
  final _ageController = TextEditingController();
  final _emergencyContactsController = TextEditingController();

  bool _isLoading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _firstNameController.text = data['first_name'] ?? '';
          _lastNameController.text = data['last_name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _usernameController.text = data['username'] ?? '';
          _photoUrl = user.photoURL ?? 'https://i.pravatar.cc/150';

          if (data['date_of_birth'] != null) {
            final dob = (data['date_of_birth'] as Timestamp).toDate();
            _dobController.text = DateFormat('dd MMM yyyy').format(dob);
          }
          _ageController.text = (data['age'] ?? '').toString();

          if (data['emergency_contacts'] != null) {
            _emergencyContactsController.text =
                (data['emergency_contacts'] as List<dynamic>).join(', ');
          }
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'username': _usernameController.text.trim(),
        'emergency_contacts': _emergencyContactsController.text
            .split(',')
            .map((e) => e.trim())
            .toList(),
      });

      await user.updateDisplayName(
        "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}",
      );
      await user.updatePhotoURL(_photoUrl);
      await user.reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Profil mis à jour avec succès !")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    final user = _auth.currentUser;
    if (user == null) return;

    TextEditingController newPasswordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Changer le mot de passe"),
        content: TextField(
          controller: newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Nouveau mot de passe"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () async {
              try {
                await user.updatePassword(newPasswordController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("🔒 Mot de passe mis à jour !")),
                );
                Navigator.pop(context);
              } on FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur : ${e.message}")),
                );
              }
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Couleurs adaptées au Dark Mode
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.black : const Color(0xFFFDF8F6);
    final fieldBgColor = isDarkMode ? Colors.grey[900]! : const Color(0xFFFFF6F3);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final labelColor = isDarkMode ? Colors.grey[400]! : Colors.grey[700]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text(
          "Mon Profil",
         style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(_photoUrl ?? ''),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 6,
                    child: InkWell(
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Fonction de changement de photo à venir 💡"),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF77BEF0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            _buildSectionCard(
              title: "Informations personnelles",
              child: Column(
                children: [
                  _buildInputField("Prénom", _firstNameController,
                      enabled: true, fieldBgColor: fieldBgColor, textColor: textColor, labelColor: labelColor),
                  const SizedBox(height: 12),
                  _buildInputField("Nom", _lastNameController,
                      enabled: true, fieldBgColor: fieldBgColor, textColor: textColor, labelColor: labelColor),
                  const SizedBox(height: 12),
                  _buildInputField("Username", _usernameController,
                      fieldBgColor: fieldBgColor, textColor: textColor, labelColor: labelColor),
                  const SizedBox(height: 12),
                  _buildInputField("Email", _emailController,
                      fieldBgColor: fieldBgColor, textColor: textColor, labelColor: labelColor),
                  const SizedBox(height: 12),
                  _buildInputField("Téléphone", _phoneController,
                      fieldBgColor: fieldBgColor, textColor: textColor, labelColor: labelColor),
                  const SizedBox(height: 12),
                  _buildInputField("Date de naissance", _dobController,
                      enabled: false, fieldBgColor: fieldBgColor, textColor: textColor, labelColor: labelColor),
                  const SizedBox(height: 12),
                  _buildInputField("Âge", _ageController,
                      enabled: false, fieldBgColor: fieldBgColor, textColor: textColor, labelColor: labelColor),
                  const SizedBox(height: 12),
                  _buildInputField("Contacts d'urgence", _emergencyContactsController,
                      fieldBgColor: fieldBgColor, textColor: textColor, labelColor: labelColor),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton.icon(
                          onPressed: _updateProfile,
                          icon: const Icon(Icons.save),
                          label: const Text("Mettre à jour le profil"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF77BEF0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text("Changer le mot de passe"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF77BEF0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.orange.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF77BEF0),
              ),
            ),
            const SizedBox(height: 15),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool enabled = true,
    Color fieldBgColor = const Color(0xFFFFF6F3),
    Color textColor = Colors.black87,
    Color labelColor = Colors.grey,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: labelColor),
        filled: true,
        fillColor: fieldBgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color.fromARGB(255, 128, 198, 255)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF77BEF0), width: 2),
        ),
      ),
    );
  }
}
