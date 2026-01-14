// base_drawer.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:logistics_app/main.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class BaseDrawer extends StatefulWidget {
  final String role;
  final String roleLabel;
  final List<DrawerMenuItem> menuItems;
  final Color headerColor1;
  final Color headerColor2;

  const BaseDrawer({
    super.key,
    required this.role,
    required this.roleLabel,
    required this.menuItems,
    this.headerColor1 = Colors.blueAccent,
    this.headerColor2 = Colors.blue,
  });

  @override
  State<BaseDrawer> createState() => _BaseDrawerState();
}

class DrawerMenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isLogout;

  DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isSelected = false,
    this.isLogout = false,
  });
}

class _BaseDrawerState extends State<BaseDrawer> {
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
      if (snapshot.exists) {
        final data = snapshot.value as Map;
        final loc = AppLocalizations.of(context);
        setState(() {
          _userName = data['name'] ?? (loc?.guestUser ?? "Guest User");
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("userName", _userName);
      } else {
        // If user doesn't exist in database, use guest user label
        final loc = AppLocalizations.of(context);
        setState(() {
          _userName = loc?.guestUser ?? "Guest User";
        });
      }
    }
  }

  void _showLanguageDialog(BuildContext context) async {
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
              title: Text(loc.selectLanguage),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(loc.english, style: const TextStyle(color: Color(0xFF004d4d))),
                    leading: Radio<String>(
                      value: 'en',
                      groupValue: currentLanguage,
                      onChanged: (value) {
                        _changeLanguage(context, 'en');
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(loc.urdu, style: const TextStyle(color: Color(0xFF004d4d))),
                    leading: Radio<String>(
                      value: 'ur',
                      groupValue: currentLanguage,
                      onChanged: (value) {
                        _changeLanguage(context, 'ur');
                      },
                    ),
                  ),
                  ListTile(
                    title: Text(loc.pashto, style: const TextStyle(color: Color(0xFF004d4d))),
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
    
    Navigator.pop(context);
  }

  Future<void> _checkRoleRegistrationAndNavigate(String targetRole, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final loc = AppLocalizations.of(context)!;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.userNotLoggedIn)),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final snapshot = await FirebaseDatabase.instance.ref("users/${user.uid}").get();
      
      if (!snapshot.exists) {
        // User doesn't exist, navigate to registration
        Navigator.pop(context); // Close loading
        _navigateToRegistration(targetRole, context);
        return;
      }

      final userData = Map<String, dynamic>.from(snapshot.value as Map);
      final currentRole = userData['role']?.toString() ?? 'customer';

      // If switching to the same role, just navigate to dashboard
      if (currentRole == targetRole) {
        Navigator.pop(context); // Close loading
        _navigateToDashboard(targetRole, context);
        return;
      }

      // Check if user is registered in the target role
      bool isRegistered = false;

      if (targetRole == 'driver') {
        // Check if driver has completed registration
        final driverDetails = userData['driverDetails'];
        final isProfileComplete = userData['isProfileComplete'] ?? false;
        isRegistered = driverDetails != null && isProfileComplete == true;
      } else if (targetRole == 'enterprise') {
        // Check if enterprise has completed registration
        final enterpriseDetails = userData['enterpriseDetails'];
        final isProfileComplete = userData['isProfileComplete'] ?? false;
        isRegistered = enterpriseDetails != null && isProfileComplete == true;
      } else if (targetRole == 'customer') {
        // Customer is always registered (default role)
        isRegistered = true;
      }

      if (isRegistered) {
        // Update role in database and navigate to dashboard
        await FirebaseDatabase.instance.ref("users/${user.uid}").update({
          "role": targetRole,
        });
        Navigator.pop(context); // Close loading
        _navigateToDashboard(targetRole, context);
      } else {
        // Navigate to registration
        Navigator.pop(context); // Close loading
        _navigateToRegistration(targetRole, context);
      }
    } catch (e) {
      Navigator.pop(context); // Close loading if still open
      debugPrint("Error checking role registration: $e");
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.errorSwitchingRole(e.toString()))),
      );
    }
  }

  void _navigateToDashboard(String role, BuildContext context) {
    // Close drawer if open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // Navigate after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (role) {
        case 'customer':
          Navigator.pushReplacementNamed(context, '/');
          break;
        case 'driver':
          Navigator.pushReplacementNamed(context, '/driverDashboard');
          break;
        case 'enterprise':
          Navigator.pushReplacementNamed(context, '/enterpriseDashboard');
          break;
        case 'enterprise_driver':
          Navigator.pushReplacementNamed(context, '/enterpriseDriverDashboard');
          break;
      }
    });
  }

  void _navigateToRegistration(String role, BuildContext context) async {
    // Close drawer if open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // Update role first
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseDatabase.instance.ref("users/${user.uid}").update({
          "role": role,
        });
      } catch (e) {
        debugPrint("Error updating role: $e");
      }
    }

    // Navigate after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (role) {
        case 'driver':
          Navigator.pushReplacementNamed(context, '/driver-registration');
          break;
        case 'enterprise':
          Navigator.pushReplacementNamed(context, '/enterprise-registration');
          break;
        case 'customer':
          Navigator.pushReplacementNamed(context, '/');
          break;
      }
    });
  }

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
          title: Text(loc.switchRole),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Colors.orange),
                title: Text(loc.customer, style: const TextStyle(color: Color(0xFF004d4d))),
                onTap: () {
                  Navigator.pop(context);
                  _checkRoleRegistrationAndNavigate('customer', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: Text(loc.driver, style: const TextStyle(color: Color(0xFF004d4d))),
                onTap: () {
                  Navigator.pop(context);
                  _checkRoleRegistrationAndNavigate('driver', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.business, color: Colors.green),
                title: Text(loc.enterprise, style: const TextStyle(color: Color(0xFF004d4d))),
                onTap: () {
                  Navigator.pop(context);
                  _checkRoleRegistrationAndNavigate('enterprise', context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // 🔹 Teal Gradient Header with Curved Bottom
          Container(
            width: double.infinity,
            height: 210,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF006A6A),
                  const Color(0xFF008B8B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _userName.isEmpty ? loc.guestUser : _userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.roleLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 🔹 Drawer Items List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...widget.menuItems.map((item) => _buildDrawerItem(
                  item.icon,
                  item.title,
                  item.onTap,
                  isSelected: item.isSelected,
                  isLogout: item.isLogout,
                )),
                _buildDrawerItem(
                  Icons.language,
                  loc.changeLanguage,
                  () => _showLanguageDialog(context),
                ),
                const Divider(height: 28),
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

          // 🔹 Clean Footer
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Text(
              "Logistics App v1.0",
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
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
    final tealDark = const Color(0xFF004d4d);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.teal.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: Colors.teal.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout ? Colors.red : tealDark,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout ? Colors.red : tealDark,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        splashColor: Colors.teal.shade100,
      ),
    );
  }
}

