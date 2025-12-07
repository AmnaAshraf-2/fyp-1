import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:logistics_app/data/modals.dart';
import 'package:logistics_app/screens/login.dart';
import 'package:logistics_app/screens/password.dart';
import 'package:logistics_app/screens/reg.dart';
import 'package:logistics_app/screens/users/customer/cargoDetails.dart';
import 'package:logistics_app/screens/users/customer/customerDashboard.dart';
import 'package:logistics_app/screens/users/customer/newBooking.dart';
import 'package:logistics_app/screens/users/customer/upcoming_bookings.dart';
import 'package:logistics_app/screens/users/customer/past_bookings.dart';
import 'package:logistics_app/screens/users/customer/customer_notifications.dart';
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
import 'package:logistics_app/screens/users/customer/customer_live_trip.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logistics_app/services/initialize_vehicles.dart';
import 'package:logistics_app/widgets/rating_notification_handler.dart' show RatingNotificationHandler, ratingNavigatorKey;
import 'package:flutter_web_plugins/url_strategy.dart';

// Global locale notifier instance
LocaleNotifier? _localeNotifier;

// Getter to access locale notifier from other files
LocaleNotifier? get localeNotifier => _localeNotifier;

void main() async {
  // Use path URL strategy instead of hash URL strategy for web
  // This fixes MediaRecorder issues on Chrome with hash routing
  usePathUrlStrategy();
  
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyDFOW1G-RFnsMNn7OWS-adyuR9-2beZUPk",
            authDomain: "fyp-1-2dbaf.firebaseapp.com",
            databaseURL: "https://fyp-1-2dbaf-default-rtdb.firebaseio.com",
            projectId: "fyp-1-2dbaf",
            storageBucket: "fyp-1-2dbaf.firebasestorage.app",
            messagingSenderId: "798522688381",
            appId: "1:798522688381:android:9d187b0588785cdaf00214"));
  } catch (e) {
    print('Firebase initialization error: $e');
    // Continue anyway - Firebase might already be initialized
  }
  
  // Initialize vehicles in Firebase (only if not already initialized)
  // This will populate the vehicle_types node with data from vehicles.dart
  InitializeVehicles.initializeIfNeeded().then((result) {
    if (result['skipped'] == true) {
      print('ℹ️ Vehicles already initialized in Firebase');
    } else {
      print('✅ Vehicle initialization completed: ${result['success']} success, ${result['failed']} failed');
    }
  }).catchError((error) {
    print('❌ Error initializing vehicles: $error');
  });
  
  _localeNotifier = LocaleNotifier();
  runApp(MyApp(localeNotifier: _localeNotifier!));
}

/// Locale Notifier - manages locale state without causing full app rebuilds
class LocaleNotifier extends ValueNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
    // Listen to auth state changes to reload language when user logs in/out
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _loadLocale(); // Reload language for logged-in user
      } else {
        // User logged out, reset to default
        value = const Locale('en');
      }
    });
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    
    // If user is logged in, load their specific language preference
    // Otherwise, use default 'en'
    String code = 'en';
    if (user != null) {
      code = prefs.getString('languageCode_${user.uid}') ?? 'en';
    } else {
      // Fallback to global preference if no user (for initial app load)
      code = prefs.getString('languageCode') ?? 'en';
    }
    
    value = Locale(code);
  }

  void setLocale(Locale locale) {
    value = locale;
  }
}

class MyApp extends StatelessWidget {
  final LocaleNotifier localeNotifier;

  const MyApp({super.key, required this.localeNotifier});

  static void setLocale(BuildContext context, Locale newLocale) {
    _localeNotifier?.setLocale(newLocale);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return MaterialApp(
          navigatorKey: ratingNavigatorKey,
          title: 'Logistics App',
          locale: locale,
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
          // Force LTR text direction to keep drawer on the left side
          builder: (context, child) {
            return RatingNotificationHandler(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: child ?? const SizedBox(),
              ),
            );
          },
          home: const Splashscreen(),
          routes: {
        //communication
        
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/Password': (context) => const ForgotPasswordScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/customerDashboard': (context) => const CustomerDashboard(),
        '/driverDashboard': (context) => const DriversScreen(),
        '/enterpriseDashboard': (context) => const EnterpriseDashboard(),
        '/newBookings': (context) => const NewBookingsScreen(),
        '/upcomingBookings': (context) => const UpcomingBookingsScreen(),
        '/pastBookings': (context) => const PastBookingsScreen(),
        '/liveTrip': (context) => const CustomerLiveTripScreen(),
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
        '/enterprise-registration': (context) =>
            const EnterpriseDetailsScreen(),
        '/enterprise-dashboard': (context) => const EnterpriseDashboard(),
        '/enterprise-details': (context) => const EnterpriseDetailsScreen(),
        '/enterprise-new-offers': (context) =>
            const EnterpriseNewOffersScreen(),
        //'/enterprise-profile': (context) => const EnterpriseProfileScreen(),
          },
        );
      },
    );
  }
}