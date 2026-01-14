// app_drawer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
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
  String _userName = "";

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
      final loc = AppLocalizations.of(context);
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        setState(() {
          _userName = data['name'] ?? (loc?.guestUser ?? "Guest User");
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("userName", _userName);
      } else {
        // If user doesn't exist in database, use guest user label
        setState(() {
          _userName = loc?.guestUser ?? "Guest User";
        });
      }
    }
  }

// --- function to show role switcher dialog ---
  void _showRoleSwitcher(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final loc = AppLocalizations.of(context)!;
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            loc.switchRole,
            style: const TextStyle(color: Color(0xFF004d4d)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Color(0xFF004d4d)),
                title: Text(
                  loc.customer,
                  style: const TextStyle(color: Color(0xFF004d4d)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _updateRole("customer", context);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.local_shipping, color: Color(0xFF004d4d)),
                title: Text(
                  loc.driver,
                  style: const TextStyle(color: Color(0xFF004d4d)),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _updateRole("driver", context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.business, color: Color(0xFF004d4d)),
                title: Text(
                  loc.enterprise,
                  style: const TextStyle(color: Color(0xFF004d4d)),
                ),
                onTap: () {
                  Navigator.pop(context);
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
    // Get current language from SharedPreferences (user-specific)
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    String initialLanguage = 'en';
    if (user != null) {
      initialLanguage = prefs.getString('languageCode_${user.uid}') ?? 'en';
    } else {
      initialLanguage = prefs.getString('languageCode') ?? 'en';
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        final loc = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentLanguage = initialLanguage;

            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                loc.selectLanguage,
                style: const TextStyle(color: Color(0xFF004d4d)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      loc.english,
                      style: const TextStyle(color: Color(0xFF004d4d)),
                    ),
                    leading: Radio<String>(
                      value: 'en',
                      groupValue: currentLanguage,
                      onChanged: (value) {
                        _changeLanguage(context, 'en');
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                      loc.urdu,
                      style: const TextStyle(color: Color(0xFF004d4d)),
                    ),
                    leading: Radio<String>(
                      value: 'ur',
                      groupValue: currentLanguage,
                      onChanged: (value) {
                        _changeLanguage(context, 'ur');
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(
                      loc.pashto,
                      style: const TextStyle(color: Color(0xFF004d4d)),
                    ),
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
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    
    // Save language preference for the current user
    if (user != null) {
      await prefs.setString('languageCode_${user.uid}', languageCode);
    } else {
      // Fallback to global if no user (shouldn't happen, but just in case)
      await prefs.setString('languageCode', languageCode);
    }

    Locale newLocale = Locale(languageCode);
    MyApp.setLocale(context, newLocale);

    Navigator.pop(context); // Close dialog
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: Colors.white, // UPDATED
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            height: 200,
            decoration: const BoxDecoration(
              color: Colors.white, // UPDATED
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userName.isEmpty ? loc.guestUser : _userName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Color(0xFF004d4d), // UPDATED
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.customer,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF004d4d), // UPDATED
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star,
                              color: Color(0xFF004d4d), size: 16), // UPDATED
                          const SizedBox(width: 4),
                          Text(
                            loc.premiumMember,
                            style: const TextStyle(
                              color: Color(0xFF004d4d), // UPDATED
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

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  Icons.dashboard,
                  loc.dashboard,
                  () => Navigator.pushReplacementNamed(
                      context, '/customerDashboard'),
                  isSelected: true,
                ),
                _buildDrawerItem(
                  Icons.person,
                  loc.profile,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.profileComingSoon)),
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
                  () => Navigator.pushNamed(context, '/notification-preferences'),
                ),
                _buildDrawerItem(
                  Icons.help_outline,
                  loc.supportHelp,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.supportComingSoon)),
                  ),
                ),
                _buildDrawerItem(
                  Icons.info_outline,
                  loc.about,
                  () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.aboutComingSoon)),
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
                Icon(Icons.info, size: 16, color: Color(0xFF004d4d)), // UPDATED
                const SizedBox(width: 8),
                Text(
                  '${loc.version} 1.0.0',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF004d4d), // UPDATED
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
          color: isLogout ? Colors.red : const Color(0xFF004d4d), // UPDATED
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout ? Colors.red : const Color(0xFF004d4d), // UPDATED
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
