import 'package:flutter/material.dart';
import 'package:logistics_app/main.dart';
import 'package:logistics_app/screens/role.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
      // Rebuild app with new locale
      MyApp.setLocale(context, newLocale);
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => RoleScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Center(
        child: Text(
          "Choose Language",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      )),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CheckboxListTile(
                      title: const Text("English"),
                      value: _selectedLanguageCode == 'en',
                      onChanged: (_) => _onLanguageSelected('en'),
                    ),
                    CheckboxListTile(
                      title: const Text("اردو"),
                      value: _selectedLanguageCode == 'ur',
                      onChanged: (_) => _onLanguageSelected('ur'),
                    ),
                    CheckboxListTile(
                      title: const Text("پښتو"),
                      value: _selectedLanguageCode == 'ps',
                      onChanged: (_) => _onLanguageSelected('ps'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _proceed,
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
              ),
              child: const Text("Proceed"),
            ),
          ],
        ),
      ),
    );
  }
}
