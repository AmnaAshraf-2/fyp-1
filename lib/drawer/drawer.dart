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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _userName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: null,
            currentAccountPicture: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: _profileImageUrl != null
                      ? NetworkImage(_profileImageUrl!)
                      : const AssetImage("assets/default_profile.png")
                          as ImageProvider,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap:
                        _changeProfilePic, // 👈 same function to pick + upload pic
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.orange,
                      ),
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
            ),
          ),

          // Menu items...

          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Profile"),
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text("Support / Help"),
            onTap: () {
              Navigator.pushNamed(context, '/support');
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About"),
            onTap: () {
              Navigator.pushNamed(context, '/about');
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text("History/Past Trips"),
            onTap: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              onPressed: () {
                _showRoleSwitcher(context);
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text("Switch Role"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
