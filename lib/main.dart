import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:logistics_app/data/modals.dart';
import 'package:logistics_app/screens/language.dart';
import 'package:logistics_app/screens/login.dart';
import 'package:logistics_app/screens/password.dart';
import 'package:logistics_app/screens/reg.dart';
import 'package:logistics_app/screens/role.dart';
import 'package:logistics_app/screens/users/customer/cargoDetails.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/customer/newBooking.dart';
import 'package:logistics_app/screens/users/customer/upcoming_bookings.dart';
import 'package:logistics_app/screens/users/customer/customer_notifications.dart';
// import 'package:logistics_app/screens/users/customer/profile.dart';
// import 'package:logistics_app/screens/users/customer/settings.dart';
// import 'package:logistics_app/screens/users/customer/support.dart';
// import 'package:logistics_app/screens/users/customer/about.dart';
// import 'package:logistics_app/screens/users/customer/history.dart';
import 'package:logistics_app/screens/users/driver/driver_registration.dart';
import 'package:logistics_app/screens/users/driver/drivers.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_details.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_dashboard.dart';
import 'package:logistics_app/screens/users/enterprise/enterprise_new_offers.dart';
import 'package:logistics_app/screens/users/enterprise/shareholder_details.dart';
import 'package:logistics_app/splash/splashscreen.dart';
import 'package:logistics_app/splash/welcome.dart';
import 'package:logistics_app/widgets/themes.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logistics_app/screens/users/driver/vehicle_info_page.dart';
import 'package:logistics_app/screens/users/customer/summary.dart';
import 'package:logistics_app/data/modals.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: "AIzaSyAJMxGoUZZWjgfFtfXAADRzryzVug96vZM",
          authDomain: "fyp-1-2dbaf.firebaseapp.com",
          databaseURL: "https://fyp-1-2dbaf-default-rtdb.firebaseio.com",
          projectId: "fyp-1-2dbaf",
          storageBucket: "fyp-1-2dbaf.firebasestorage.app",
          messagingSenderId: "798522688381",
          appId: "1:798522688381:android:9d187b0588785cdaf00214"));
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
    String? code = prefs.getString('languageCode') ?? 'en';
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
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ur'),
        Locale('ps'),
      ],
      initialRoute: '/',
      routes: {
        //splash
        '/': (context) => const Splashscreen(),
        //'/splash': (context) => const Splashscreen(),
        '/language': (context) => const LanguageSettingsScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/Password': (context) => const ForgotPasswordScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/role': (context) => const RoleScreen(),
        '/customerDashboard': (context) => const CustomerDashboard(),
        '/driverDashboard': (context) => const DriversScreen(),
        '/enterpriseDashboard': (context) => const EnterpriseDashboard(),
        '/newBookings': (context) => const NewBookingsScreen(),
        '/upcomingBookings': (context) => const UpcomingBookingsScreen(),
        '/pastBookings': (context) =>
            const UpcomingBookingsScreen(), // Using same screen for now
        '/customerNotifications': (context) =>
            const CustomerNotificationsScreen(),
        '/cargo-details': (context) => const CargoDetailsScreen(),
        '/summary': (context) => SummaryScreen(
              initialDetails: CargoDetails(
                loadName: 'Sample Load',
                loadType: 'General',
                weight: 1000.0,
                quantity: 1,
                offerFare: 5000.0,
                isInsured: true,
                weightUnit: '',
                vehicleType: '',
                senderPhone: '',
                receiverPhone: '',
                pickupLocation: '',
                destinationLocation: '',
              ),
            ),
        '/driver-registration': (context) => const DriverRegistration(),
        '/vehicle-info': (context) => VehicleInfoPage(
              cnic: '',
              license: '',
              phone: '',
            ),
        // // Customer screens
        // '/profile': (context) => const CustomerProfileScreen(),
        // '/settings': (context) => const CustomerSettingsScreen(),
        // '/support': (context) => const CustomerSupportScreen(),
        // '/about': (context) => const AboutScreen(),
        // '/history': (context) => const CustomerHistoryScreen(),
        '/enterprise-registration': (context) =>
            const EnterpriseDetailsScreen(),
        '/enterprise-dashboard': (context) => const EnterpriseDashboard(),
        '/enterprise-details': (context) => const EnterpriseDetailsScreen(),
        '/enterprise-new-offers': (context) =>
            const EnterpriseNewOffersScreen(),
        //'/enterprise-profile': (context) => const EnterpriseProfileScreen(),
      },
    );
  }
}
