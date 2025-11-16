// base_drawer.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
          _profileImageUrl = data['profilePic'] ?? data['profile_image'];
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
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final storageRef = FirebaseStorage.instance
            .ref()
            .child("profile_pics")
            .child("${user.uid}.jpg");

        await storageRef.putFile(imageFile);
        String downloadUrl = await storageRef.getDownloadURL();

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image', downloadUrl);

        await FirebaseDatabase.instance
            .ref()
            .child("users")
            .child(user.uid)
            .update({"profile_image": downloadUrl});

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

  void _showLanguageDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String initialLanguage = prefs.getString('languageCode') ?? 'en';
    
    showDialog(
      context: context,
      builder: (dialogContext) {
        final loc = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
    
    Navigator.pop(context);
  }

  Future<void> _checkRoleRegistrationAndNavigate(String targetRole, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error switching role: $e")),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(loc.switchRole),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Colors.orange),
                title: Text(loc.customer),
                onTap: () {
                  Navigator.pop(context);
                  _checkRoleRegistrationAndNavigate('customer', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.blue),
                title: Text(loc.driver),
                onTap: () {
                  Navigator.pop(context);
                  _checkRoleRegistrationAndNavigate('driver', context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.business, color: Colors.green),
                title: Text(loc.enterprise),
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
      child: Column(
        children: [
          // Enhanced Header
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [widget.headerColor1, widget.headerColor2],
              ),
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
                                  ? Icon(
                                      Icons.person,
                                      size: 40,
                                      color: widget.headerColor1,
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
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: widget.headerColor1,
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
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
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
                              color: Colors.white,
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

          // Menu items
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
        color: isSelected ? widget.headerColor1.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isLogout ? Colors.red : (isSelected ? const Color(0xFF004d4d) : const Color(0xFF004d4d)),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout ? Colors.red : (isSelected ? const Color(0xFF004d4d) : const Color(0xFF004d4d)),
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

