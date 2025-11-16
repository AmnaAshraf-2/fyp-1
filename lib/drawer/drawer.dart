// app_drawer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logistics_app/screens/users/driver/drivers.dart';
import 'package:logistics_app/main.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer(
      {super.key, required String userName, String? profileImageUrl});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _userName = "Guest User";
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot =
          await FirebaseDatabase.instance.ref("users/${user.uid}").get();
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        setState(() {
          _userName = data['name'] ?? "Guest User";
          _profileImageUrl = data['profilePic'];
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("userName", _userName);
        if (_profileImageUrl != null) {
          await prefs.setString("profilePic", _profileImageUrl!);
        }
      }
    }
  }

  Future<void> _changeProfilePic() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      try {
        // Get current user
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance
            .ref()
            .child("profile_pics")
            .child("${user.uid}.jpg");

        await storageRef.putFile(imageFile);

        // Get download URL
        String downloadUrl = await storageRef.getDownloadURL();

        // Save URL in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image', downloadUrl);

        // Optional: also save in Firebase Realtime Database
        await FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(user.uid)
            .update({"profile_image": downloadUrl});

        // Update UI immediately
        setState(() {
          _profileImageUrl = downloadUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated")),
        );
      } catch (e) {
        debugPrint("Error uploading profile pic: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e")),
        );
      }
    }
  }

// --- function to show role switcher dialog ---
  void _showRoleSwitcher(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Switch Role"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Colors.orange),
                title: const Text("Customer"),
                onTap: () {
                  _updateRole("customer", context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: const Text("Driver"),
                onTap: () {
                  _updateRole("driver", context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.business, color: Colors.green),
                title: const Text("Enterprise"),
                onTap: () {
                  _updateRole("enterprise", context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

// --- update role in Firestore and navigate to correct dashboard ---
  Future<void> _updateRole(String role, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
      "role": role,
    });

    Navigator.pop(context); // close dialog

    // Navigate based on role
    if (role == "customer") {
      Navigator.pushReplacementNamed(context, "/customerDashboard");
    } else if (role == "driver") {
      Navigator.pushReplacementNamed(context, "/driverDashboard");
    } else if (role == "enterprise") {
      Navigator.pushReplacementNamed(context, "/enterpriseDashboard");
    }
  }

  void _showLanguageDialog(BuildContext context) async {
    // Get current language from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    String initialLanguage = prefs.getString('languageCode') ?? 'en';
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        final loc = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Use a variable that persists across rebuilds
            final currentLanguage = initialLanguage;
            
            return AlertDialog(
              title: Text(loc.selectLanguage),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(loc.english),
                    leading: Radio<String>(
                      value: 'en',
                      groupValue: currentLanguage,
                      onChanged: (value) {
                        _changeLanguage(context, 'en');
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(loc.urdu),
                    leading: Radio<String>(
                      value: 'ur',
                      groupValue: currentLanguage,
                      onChanged: (value) {
                        _changeLanguage(context, 'ur');
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(loc.pashto),
                    leading: Radio<String>(
                      value: 'ps',
                      groupValue: currentLanguage,
                      onChanged: (value) {
                        _changeLanguage(context, 'ps');
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _changeLanguage(BuildContext context, String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
    
    Locale newLocale = Locale(languageCode);
    MyApp.setLocale(context, newLocale);
    
    Navigator.pop(context); // Close dialog
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Enhanced Header
          Container(
            height: 200,
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 35,
                              backgroundImage: _profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!)
                                  : null,
                              backgroundColor: Colors.white,
                              child: _profileImageUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.blueAccent,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _changeProfilePic,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.customer,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF004d4d),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.yellow, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            loc.premiumMember,
                            style: const TextStyle(
                              color: Color(0xFF004d4d),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Menu items with enhanced styling
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  Icons.dashboard,
                  loc.dashboard,
                  () => Navigator.pushReplacementNamed(context, '/customerDashboard'),
                  isSelected: true,
                ),
                _buildDrawerItem(
                  Icons.person,
                  loc.profile,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile - Coming Soon')),
                  ),
                ),
                _buildDrawerItem(
                  Icons.history,
                  loc.bookingHistory,
                  () => Navigator.pushNamed(context, '/pastBookings'),
                ),
                _buildDrawerItem(
                  Icons.settings,
                  loc.settings,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings - Coming Soon')),
                  ),
                ),
                _buildDrawerItem(
                  Icons.help_outline,
                  loc.supportHelp,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Support - Coming Soon')),
                  ),
                ),
                _buildDrawerItem(
                  Icons.info_outline,
                  loc.about,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('About - Coming Soon')),
                  ),
                ),
                _buildDrawerItem(
                  Icons.language,
                  loc.changeLanguage,
                  () => _showLanguageDialog(context),
                ),
                const Divider(),
                _buildDrawerItem(
                  Icons.swap_horiz,
                  loc.switchRole,
                  () => _showRoleSwitcher(context),
                ),
                _buildDrawerItem(
                  Icons.logout,
                  loc.logout,
                  () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                  isLogout: true,
                ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(
                top: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${loc.version} 1.0.0',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF004d4d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isSelected = false,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF004d4d).withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout ? Colors.red : const Color(0xFF004d4d),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout ? Colors.red : const Color(0xFF004d4d),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
