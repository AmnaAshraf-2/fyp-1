# Logistics App

A comprehensive Flutter-based logistics and transportation management application that connects customers, drivers, and enterprises for efficient cargo and freight services.

## 📱 Overview

The Logistics App is a full-featured mobile application designed to streamline the logistics and transportation industry. It enables customers to book transportation services, drivers to manage trips and earnings, and enterprises to manage their fleet and operations.

## ✨ Features

### 👤 Customer Features
- **Booking Management**: Create new bookings with detailed cargo information
- **Real-time Tracking**: Track driver location and trip progress in real-time
- **Route Visualization**: View pickup and delivery routes on interactive maps
- **Booking History**: Access past and upcoming bookings
- **Rating System**: Rate drivers and enterprises after trip completion
- **Notifications**: Receive real-time updates about booking status
- **Location Picker**: Easy-to-use map interface for selecting pickup and delivery locations
- **Cargo Details**: Specify load type, weight, quantity, and vehicle requirements
- **Insurance Options**: Add insurance coverage to bookings
- **Live Trip Monitoring**: Monitor active trips with live location updates

### 🚗 Driver Features
- **Trip Management**: View and manage upcoming and past trips
- **Earnings Tracking**: Monitor earnings and financial performance
- **Vehicle Registration**: Register and manage vehicle information
- **New Offers**: Browse and accept available booking offers
- **Live Trip Tracking**: Track active trips with real-time location sharing
- **Driver Profile**: Complete driver registration with license and CNIC details
- **Notifications**: Receive booking requests and trip updates
- **Route Navigation**: Access optimized routes for deliveries

### 🏢 Enterprise Features
- **Dashboard**: Comprehensive overview of operations and statistics
- **Fleet Management**: Manage enterprise vehicles and drivers
- **Booking Management**: View and manage all enterprise bookings
- **Driver Management**: Add, remove, and manage enterprise drivers
- **Earnings Tracking**: Monitor enterprise revenue and financial metrics
- **Active Trips**: Track all active enterprise trips
- **Shareholder Management**: Manage enterprise shareholder details
- **Vehicle Management**: Add and manage enterprise vehicle fleet
- **Live Driver Tracking**: Monitor all enterprise drivers' locations in real-time

### 🚛 Enterprise Driver Features
- **Assignment Management**: View and manage assigned trips
- **Dashboard**: Access enterprise driver-specific dashboard
- **Trip Tracking**: Track assigned enterprise trips

### 🌐 General Features
- **Multi-language Support**: Available in English, Urdu, and Pashto
- **Authentication**: Secure login with Firebase Authentication
- **Google Sign-In**: Quick authentication with Google accounts
- **Dark Mode**: System-based theme support (light/dark)
- **Push Notifications**: Real-time notifications via Firebase Cloud Messaging
- **Offline Support**: Basic offline functionality with Firebase Realtime Database
- **File Management**: Upload and manage documents and images
- **PDF Generation**: Generate and print booking summaries and receipts
- **Audio Recording**: Record and manage audio notes (for trip documentation)

## 🛠️ Technology Stack

### Frontend
- **Flutter** (SDK: ^3.6.0)
- **Dart**

### Backend & Services
- **Firebase Authentication**: User authentication and authorization
- **Firebase Realtime Database**: Real-time data synchronization
- **Cloud Firestore**: Additional database capabilities
- **Firebase Storage**: File and image storage
- **Firebase Cloud Messaging**: Push notifications

### Key Dependencies
- `google_maps_flutter`: Interactive maps and location services
- `geolocator`: Location services and GPS tracking
- `geocoding`: Address geocoding and reverse geocoding
- `flutter_polyline_points`: Route calculation and polyline rendering
- `provider`: State management
- `firebase_auth`: Authentication
- `firebase_database`: Realtime database
- `firebase_messaging`: Push notifications
- `image_picker`: Image selection and upload
- `file_picker`: File selection
- `pdf` & `printing`: PDF generation and printing
- `record` & `audioplayers`: Audio recording and playback
- `flutter_contacts`: Contact management
- `intl_phone_field`: International phone number input
- `country_picker`: Country selection
- `url_launcher`: External URL and phone call launching

## 📋 Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.6.0 or higher)
- **Dart SDK** (comes with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Firebase Account** with a project set up
- **Google Cloud Console** account (for Maps API)
- **Node.js** (for admin panel, if using)

## 🚀 Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd logistics_app
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable the following services:
     - Authentication (Email/Password, Google Sign-In)
     - Realtime Database
     - Cloud Firestore
     - Storage
     - Cloud Messaging
   - Download `google-services.json` for Android and place it in `android/app/`
   - Download `GoogleService-Info.plist` for iOS and place it in `ios/Runner/`
   - Update Firebase configuration in `lib/main.dart` with your project credentials

4. **Google Maps API Setup**
   - Create a project in [Google Cloud Console](https://console.cloud.google.com/)
   - Enable the following APIs:
     - Maps JavaScript API
     - Places API
     - Directions API
     - Routes API (for new Directions API)
   - Create an API key and restrict it appropriately
   - Add the API key to your app configuration

5. **Run the application**
   ```bash
   flutter run
   ```

## 📁 Project Structure

```
lib/
├── data/              # Data models and modals
├── drawer/            # Navigation drawer components
├── global/            # Global utilities and constants
├── l10n/              # Localization files (English, Urdu, Pashto)
├── main.dart          # Application entry point
├── screens/           # All application screens
│   ├── users/
│   │   ├── customer/  # Customer-specific screens
│   │   ├── driver/    # Driver-specific screens
│   │   ├── enterprise/# Enterprise-specific screens
│   │   └── enterprise_driver/ # Enterprise driver screens
│   ├── login.dart     # Authentication screens
│   └── ...
├── services/          # Business logic and services
├── splash/            # Splash and welcome screens
└── widgets/           # Reusable widgets and themes
```

## 🔧 Configuration

### Firebase Configuration
Update Firebase credentials in `lib/main.dart`:
```dart
await Firebase.initializeApp(
  options: FirebaseOptions(
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_AUTH_DOMAIN",
    databaseURL: "YOUR_DATABASE_URL",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_STORAGE_BUCKET",
    messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
    appId: "YOUR_APP_ID"
  )
);
```

### Google Maps API Key
- Android: Add to `android/app/src/main/AndroidManifest.xml`
- iOS: Add to `ios/Runner/AppDelegate.swift`
- Web: Add to `web/index.html`

## 🌍 Localization

The app supports multiple languages:
- English (en)
- Urdu (ur)
- Pashto (ps)

Language files are located in `lib/l10n/`. Users can change language preferences in the app settings.

## 📱 Platform Support

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows (partial)
- ✅ macOS (partial)
- ✅ Linux (partial)

## 🧪 Testing

Run tests with:
```bash
flutter test
```

Test files are located in the `test/` directory.

## 🏗️ Building

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## 📦 Admin Panel

The project includes a React-based admin panel located in the `logistics-admin/` directory. See `logistics-admin/README.md` for admin panel setup and usage.

## 🔐 Security Considerations

- Firebase Security Rules should be properly configured
- API keys should be restricted in production
- User data should be encrypted in transit
- Implement proper authentication checks
- Validate all user inputs
- Use HTTPS for all network communications

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is part of a Final Year Project (FYP-1). All rights reserved.

## 👥 Authors

- Amna Ashraf

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- Google Maps for location services
- All open-source contributors whose packages made this project possible

## 📞 Support

For support, please open an issue in the repository or contact the development team.

---

**Note**: This is a Final Year Project (FYP-2) application. Ensure all Firebase and API configurations are properly set up before running the application.
