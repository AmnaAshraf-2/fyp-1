import 'package:flutter/material.dart';
import 'package:logistics_app/main.dart';
import 'package:logistics_app/screens/role.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String? _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguageCode = prefs.getString('languageCode') ?? 'en';
    });
  }

  Future<void> _saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', languageCode);
  }

  void _onLanguageSelected(String code) {
    setState(() {
      _selectedLanguageCode = code;
    });
  }

  void _proceed() async {
    if (_selectedLanguageCode != null) {
      await _saveLanguage(_selectedLanguageCode!);
      Locale newLocale = Locale(_selectedLanguageCode!);
      MyApp.setLocale(context, newLocale);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/p.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5), // Higher opacity than login (0.5 vs 0.4)
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  
                  Text(
                    "Choose Language",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    color: Colors.white,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        children: [
                          _buildLanguageTile('English', 'en'),
                          const Divider(height: 30, color: Color(0xFF004d4d)),
                          _buildLanguageTile('اردو', 'ur'),
                          const Divider(height: 30, color: Color(0xFF004d4d)),
                          _buildLanguageTile('پښتو', 'ps'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _proceed,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 15, horizontal: 40),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF004d4d),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'PROCEED',
                      style: TextStyle(fontSize: 18, color: Color(0xFF004d4d), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageTile(String language, String code) {
    return ListTile(
      title: Text(
        language,
        style: TextStyle(
          fontSize: 18,
          color: const Color(0xFF004d4d),
        ),
      ),
      leading: Radio<String>(
        value: code,
        groupValue: _selectedLanguageCode,
        activeColor: const Color(0xFF004d4d),
        onChanged: (value) => _onLanguageSelected(value!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }
}
