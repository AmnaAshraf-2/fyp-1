import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class EnterpriseProfileScreen extends StatelessWidget {
  const EnterpriseProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(t.profileSettings, style: const TextStyle(color: Color(0xFF004d4d))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF004d4d)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              t.profileSettings,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF004d4d),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.enterpriseProfileAndSettingsWillAppearHere,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF004d4d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
