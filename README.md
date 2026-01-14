# Logistics App

A comprehensive Flutter-based logistics and transportation management application that connects customers, drivers, and enterprises for efficient cargo and freight services.

## 📱 Overview

The Logistics App is a full-featured mobile application designed to streamline the logistics and transportation industry. It enables customers to book transportation services, drivers to manage trips and earnings, and enterprises to manage their fleet and operations. The system also includes a web-based admin panel for comprehensive system management.

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

## 🖥️ Web Admin Panel

The Logistics App includes a comprehensive web-based admin panel built with React for managing the entire logistics system. The admin panel provides administrators with powerful tools to oversee operations, manage users, and monitor bookings.

### Admin Panel Features

#### 📊 Dashboard
- **Real-time Statistics**: Live metrics and key performance indicators
- **User Analytics**: Total counts by role (Customers, Drivers, Enterprises)
- **Booking Statistics**: Track total, pending, and completed bookings
- **Revenue Tracking**: Monitor financial performance and earnings
- **Recent Activity**: View latest user registrations and booking activities
- **Visual Analytics**: Interactive charts and graphs for data visualization

#### 👥 User Management
- **User Overview**: View all registered users in the system
- **Advanced Search**: Search users by name, email, phone number, or role
- **Role Filtering**: Filter users by role (Customer, Driver, Enterprise)
- **User Editing**: Update user information including name, email, phone, and role
- **User Deletion**: Remove users from the system
- **Driver Details**: View comprehensive driver information including:
  - License number and expiry date
  - CNIC (National ID) details
  - Date of birth
  - Bank account information
- **Sorting Options**: Sort users by name, email, join date, or other criteria
- **Bulk Operations**: Perform actions on multiple users simultaneously

#### 📦 Booking Management
- **Booking Overview**: View all booking requests in the system
- **Advanced Search**: Search bookings by load name, customer name, or booking type
- **Status Management**: Update booking status (Pending, Accepted, In Progress, Completed, Cancelled)
- **Detailed View**: Access complete booking information in modal views
- **Customer Integration**: View associated customer details for each booking
- **Booking Filtering**: Filter bookings by status, date, type, or other criteria
- **Booking Deletion**: Remove bookings from the system
- **Sorting Options**: Sort bookings by date, status, fare, or other criteria

#### 🎨 Admin Panel UI/UX
- **Responsive Design**: Works seamlessly on desktop, tablet, and mobile devices
- **Modern Interface**: Clean, intuitive design with Material-UI components
- **Real-time Updates**: Automatic data synchronization with Firebase
- **Interactive Navigation**: Easy navigation between different sections
- **Loading States**: Visual feedback during data operations
- **Error Handling**: Comprehensive error messages and handling
- **Dark Mode Support**: Theme customization options

### Admin Panel Setup

#### Prerequisites
- Node.js (v14 or higher)
- npm or yarn package manager
- Firebase project with Realtime Database enabled
- Access to Firebase project credentials

#### Installation

1. **Navigate to the admin panel directory**
   ```bash
   cd logistics-admin
   ```

2. **Install dependencies**
   ```bash
   npm install
   # or
   yarn install
   ```

3. **Configure Firebase**
   - Update `src/firebase.js` with your Firebase configuration
   - Ensure your Firebase project has Realtime Database enabled
   - Configure Firebase security rules appropriately

4. **Start the development server**
   ```bash
   npm start
   # or
   yarn start
   ```

5. **Access the admin panel**
   - Open [http://localhost:3000](http://localhost:3000) in your browser
   - The admin panel will automatically reload when you make changes

#### Production Build

To build the admin panel for production:

```bash
npm run build
# or
yarn build
```

This creates an optimized production build in the `build/` directory.

#### Firebase Data Structure

The admin panel connects to Firebase Realtime Database and expects the following data structure:

```
users/
  {userId}/
    name: string
    email: string
    phone: string
    role: string (customer, driver, enterprise)
    createdAt: timestamp
    driverDetails/ (for drivers)
      dob: string
      cnic: string
      licenseNumber: string
      licenseExpiry: string
      bankAccount: string

requests/
  {requestId}/
    customerId: string
    loadName: string
    loadType: string
    weight: number
    weightUnit: string
    quantity: number
    pickupTime: string
    offerFare: number
    isInsured: boolean
    vehicleType: string
    status: string (pending, accepted, in_progress, completed, cancelled)
    timestamp: number
```

#### Security Considerations

- **Authentication**: Implement proper authentication for admin access
- **Role-Based Access**: Restrict admin panel access to authorized personnel only
- **Firebase Security Rules**: Configure Firebase Realtime Database security rules
- **HTTPS**: Use HTTPS in production environments
- **API Key Protection**: Secure Firebase API keys and credentials
- **Input Validation**: Validate all user inputs and operations

## 🛠️ Technology Stack

### Mobile App (Flutter)
- **Flutter** (SDK: ^3.6.0)
- **Dart**

### Web Admin Panel
- **React**: Frontend framework
- **Firebase Realtime Database**: Real-time data synchronization
- **Material-UI**: UI component library (if used)

### Backend & Services
- **Firebase Authentication**: User authentication and authorization
- **Firebase Realtime Database**: Real-time data synchronization
- **Cloud Firestore**: Additional database capabilities
- **Firebase Storage**: File and image storage
- **Firebase Cloud Messaging**: Push notifications

### Key Dependencies (Flutter)
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

### For Mobile App
- **Flutter SDK** (3.6.0 or higher)
- **Dart SDK** (comes with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Firebase Account** with a project set up
- **Google Cloud Console** account (for Maps API)

### For Admin Panel
- **Node.js** (v14 or higher)
- **npm** or **yarn** package manager
- **Firebase Account** with Realtime Database enabled

## 🚀 Installation

### Mobile App Setup

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

### Admin Panel Setup

See the [Web Admin Panel](#-web-admin-panel) section above for detailed setup instructions.

## 📁 Project Structure

```
logistics_app/
├── lib/
│   ├── data/              # Data models and modals
│   ├── drawer/            # Navigation drawer components
│   ├── global/            # Global utilities and constants
│   ├── l10n/              # Localization files (English, Urdu, Pashto)
│   ├── main.dart          # Application entry point
│   ├── screens/           # All application screens
│   │   ├── users/
│   │   │   ├── customer/  # Customer-specific screens
│   │   │   ├── driver/    # Driver-specific screens
│   │   │   ├── enterprise/# Enterprise-specific screens
│   │   │   └── enterprise_driver/ # Enterprise driver screens
│   │   ├── login.dart     # Authentication screens
│   │   └── ...
│   ├── services/          # Business logic and services
│   ├── splash/            # Splash and welcome screens
│   └── widgets/           # Reusable widgets and themes
├── logistics-admin/       # Web admin panel (React)
│   ├── src/               # React source files
│   ├── public/            # Public assets
│   ├── package.json       # Node.js dependencies
│   └── build/             # Production build output
├── android/               # Android platform files
├── ios/                   # iOS platform files
├── web/                   # Web platform files
└── test/                  # Test files
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

### Admin Panel Firebase Configuration
Update Firebase configuration in `logistics-admin/src/firebase.js`:
```javascript
import { initializeApp } from 'firebase/app';
import { getDatabase } from 'firebase/database';

const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_AUTH_DOMAIN",
  databaseURL: "YOUR_DATABASE_URL",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_STORAGE_BUCKET",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID"
};

const app = initializeApp(firebaseConfig);
export const database = getDatabase(app);
```

## 🌍 Localization

The mobile app supports multiple languages:
- English (en)
- Urdu (ur)
- Pashto (ps)

Language files are located in `lib/l10n/`. Users can change language preferences in the app settings.

## 📱 Platform Support

### Mobile App
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows (partial)
- ✅ macOS (partial)
- ✅ Linux (partial)

### Admin Panel
- ✅ Web (all modern browsers)
- ✅ Responsive design for mobile and tablet

## 🧪 Testing

### Mobile App
Run tests with:
```bash
flutter test
```

Test files are located in the `test/` directory.

### Admin Panel
```bash
cd logistics-admin
npm test
```

## 🏗️ Building

### Mobile App

#### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

#### Web
```bash
flutter build web --release
```

### Admin Panel
```bash
cd logistics-admin
npm run build
```

The production build will be in the `build/` directory.

## 🔐 Security Considerations

- **Firebase Security Rules**: Should be properly configured for all Firebase services
- **API Keys**: Should be restricted in production environments
- **User Data**: Should be encrypted in transit
- **Authentication**: Implement proper authentication checks
- **Input Validation**: Validate all user inputs
- **HTTPS**: Use HTTPS for all network communications
- **Admin Access**: Restrict admin panel access to authorized personnel only
- **Role-Based Access Control**: Implement proper RBAC for different user roles

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
- React team for the admin panel framework
- All open-source contributors whose packages made this project possible

## 📞 Support

For support, please open an issue in the repository or contact the development team.

---

**Note**: This is a Final Year Project (FYP-1) application. Ensure all Firebase and API configurations are properly set up before running the application. Both the mobile app and admin panel require separate Firebase configuration.
