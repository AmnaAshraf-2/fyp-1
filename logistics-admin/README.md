# Logistics App Admin Panel

A comprehensive web-based admin panel for managing the Logistics App system. Built with React and Firebase Realtime Database.

## Features

### 📊 Dashboard
- Real-time statistics and metrics
- User counts by role (Customers, Drivers, Enterprises)
- Booking statistics (Total, Pending, Completed)
- Revenue tracking
- Recent user activity
- Recent booking activity

### 👥 User Management
- View all registered users
- Search and filter users by name, email, phone, or role
- Edit user information (name, email, phone, role)
- Delete users
- View driver details (license, CNIC, expiry)
- Sort users by various criteria

### 📦 Booking Management
- View all booking requests
- Search and filter bookings by load name, customer, or type
- Update booking status (Pending, Accepted, In Progress, Completed, Cancelled)
- View detailed booking information
- Delete bookings
- Sort bookings by various criteria

### 🎨 Modern UI/UX
- Responsive design for desktop and mobile
- Clean, modern interface
- Real-time data updates
- Interactive navigation
- Loading states and error handling

## Getting Started

### Prerequisites
- Node.js (v14 or higher)
- npm or yarn
- Firebase project with Realtime Database

### Installation

1. Navigate to the admin panel directory:
   ```bash
   cd logistics-admin
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Configure Firebase:
   - Update `src/firebase.js` with your Firebase configuration
   - Ensure your Firebase project has Realtime Database enabled

4. Start the development server:
   ```bash
   npm start
   ```

5. Open [http://localhost:3000](http://localhost:3000) to view the admin panel

### Firebase Configuration

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

## Available Scripts

- `npm start` - Runs the app in development mode
- `npm build` - Builds the app for production
- `npm test` - Launches the test runner
- `npm eject` - Ejects from Create React App

## Features in Detail

### Dashboard
- **Statistics Cards**: Display key metrics with visual icons
- **Recent Activity**: Show latest users and bookings
- **Real-time Updates**: Data refreshes automatically
- **Responsive Design**: Works on all screen sizes

### User Management
- **Advanced Search**: Search across multiple fields
- **Role Filtering**: Filter by user role
- **Bulk Operations**: Edit and delete multiple users
- **Driver Details**: Special view for driver-specific information
- **Sorting**: Sort by name, email, or join date

### Booking Management
- **Status Management**: Update booking status with dropdown
- **Detailed View**: Modal with complete booking information
- **Customer Integration**: Shows customer details for each booking
- **Filtering**: Filter by status, date, or other criteria

## Security Considerations

- The admin panel should be protected with authentication
- Consider implementing role-based access control
- Ensure Firebase security rules are properly configured
- Use HTTPS in production

## Deployment

1. Build the production version:
   ```bash
   npm run build
   ```

2. Deploy the `build` folder to your hosting service
3. Configure environment variables if needed
4. Set up proper Firebase security rules

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is part of the Logistics App system.