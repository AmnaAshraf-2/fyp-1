import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:logistics_app/screens/users/customer.dart';
import 'package:logistics_app/screens/users/drivers.dart';
import 'package:logistics_app/screens/users/enterprise.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  Future<void> _saveRoleAndNavigate(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role);

    Widget screen;
    switch (role) {
      case 'customer':
        screen = const CustomerScreen();
        break;
      case 'driver':
        screen = const DriversScreen();
        break;
      case 'enterprise':
        screen = const EnterpriseScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.chooseRole)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _saveRoleAndNavigate('customer'),
              child: Text(AppLocalizations.of(context)!.customer),
            ),
            ElevatedButton(
              onPressed: () => _saveRoleAndNavigate('driver'),
              child: Text(AppLocalizations.of(context)!.driver),
            ),
            ElevatedButton(
              onPressed: () => _saveRoleAndNavigate('enterprise'),
              child: Text(AppLocalizations.of(context)!.enterprise),
            ),
          ],
        ),
      ),
    );
  }
}
