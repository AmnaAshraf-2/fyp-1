import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:logistics_app/screens/language.dart';
import 'package:logistics_app/screens/login.dart';
import 'package:logistics_app/screens/password.dart';
import 'package:logistics_app/screens/reg.dart';
import 'package:logistics_app/screens/role.dart';
import 'package:logistics_app/screens/users/customer/cargoDetails.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/customer/newBooking.dart';
import 'package:logistics_app/screens/users/drivers.dart';
import 'package:logistics_app/screens/users/enterprise.dart';
import 'package:logistics_app/splash/splashscreen.dart';
import 'package:logistics_app/splash/welcome.dart';
import 'package:logistics_app/widgets/themes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: "AIzaSyDWpUIrQ4VwjiN9EE06zYPoQxg15Hvmbuc",
          authDomain: "fyp-1-2dbaf.firebaseapp.com",
          databaseURL: "https://fyp-1-2dbaf-default-rtdb.firebaseio.com",
          projectId: "fyp-1-2dbaf",
          storageBucket: "fyp-1-2dbaf.firebasestorage.app",
          messagingSenderId: "798522688381",
          appId: "1:798522688381:web:54e364753fbc170ef00214"));
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString('languageCode') ?? 'ur';
    setState(() {
      _locale = Locale(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logistics App',
      locale: _locale,
      themeMode: ThemeMode.system,
      theme: MyTheme.lightTheme,
      darkTheme: MyTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
        Locale('ps'),
      ],
      initialRoute: '/', // Set initial screen to SplashScreen or LoginScreen
      routes: {
       // '/': (context) => const Splashscreen(),
        '/login': (context) => const LoginScreen(),
        '/Register': (context) => const RegisterScreen(),
        '/Password': (context) => const ForgotPasswordScreen(),
        '/': (context) => const WelcomeScreen(),
        '/language': (context) => const LanguageSettingsScreen(),
        '/role': (context) => const RoleScreen(),
        '/customerDashboard': (context) => const CustomerDashboard(),
        '/driverDashboard': (context) => const DriversScreen(),
        '/enterpriseDashboard': (context) => const EnterpriseScreen(),
        '/newBookings': (context) => const NewBookingsScreen(),
        '/cargo-details': (context) => const CargoDetailsScreen(),
        // Add more routes here for other screens
      },
    );
  }
}
