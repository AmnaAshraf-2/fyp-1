import React, { useState, useEffect } from 'react';
import { onAuthStateChanged, signOut } from 'firebase/auth';
import { auth } from './firebase';
import Navigation from './Navigation';
import Dashboard from './Dashboard';
import UserManagement from './UserManagement';
import VehicleManagement from './VehicleManagement';
import VehicleTypeManagement from './VehicleTypeManagement';
import BookingManagement from './BookingManagement';
import Reports from './Reports';
import Analytics from './Analytics';
import Commission from './Commission';
import Login from './Login';
import Register from './Register';
import './App.css';

function App() {
  const [currentPage, setCurrentPage] = useState('dashboard');
  const [user, setUser] = useState(null);
  const [userData, setUserData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [authView, setAuthView] = useState('login'); // 'login' or 'register'

  useEffect(() => {
    // Listen for auth state changes
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      if (currentUser) {
        setUser(currentUser);
        // User is authenticated, fetch user data if needed
        // For now, we'll assume userData is set via onLoginSuccess
      } else {
        setUser(null);
        setUserData(null);
      }
      setLoading(false);
    });

    // Check URL hash for auth view
    const hash = window.location.hash.replace('#', '');
    if (hash === 'register') {
      setAuthView('register');
    } else {
      setAuthView('login');
    }

    // Listen for hash changes
    const handleHashChange = () => {
      const newHash = window.location.hash.replace('#', '');
      if (newHash === 'register') {
        setAuthView('register');
      } else {
        setAuthView('login');
      }
    };

    window.addEventListener('hashchange', handleHashChange);

    return () => {
      unsubscribe();
      window.removeEventListener('hashchange', handleHashChange);
    };
  }, []);

  const handleLoginSuccess = (user, data) => {
    setUser(user);
    setUserData(data);
    window.location.hash = '';
  };

  const handleRegisterSuccess = (user, data) => {
    setUser(user);
    setUserData(data);
    window.location.hash = '';
  };

  const handleLogout = async () => {
    try {
      await signOut(auth);
      setUser(null);
      setUserData(null);
      setAuthView('login');
      window.location.hash = 'login';
    } catch (error) {
      console.error('Logout error:', error);
    }
  };

  // Show loading state while checking auth
  if (loading) {
    return (
      <div className="app">
        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          minHeight: '100vh',
          fontSize: '18px',
          color: '#666'
        }}>
          Loading...
        </div>
      </div>
    );
  }

  // Show auth screens if not authenticated
  if (!user) {
    return (
      <div className="app app-auth">
        {authView === 'login' ? (
          <Login onLoginSuccess={handleLoginSuccess} />
        ) : (
          <Register onRegisterSuccess={handleRegisterSuccess} />
        )}
      </div>
    );
  }

  // Show main app if authenticated
  const renderPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <Dashboard />;
      case 'users':
        return <UserManagement />;
      case 'vehicles':
        return <VehicleManagement />;
      case 'vehicle-types':
        return <VehicleTypeManagement />;
      case 'bookings':
        return <BookingManagement />;
      case 'reports':
        return <Reports />;
      case 'analytics':
        return <Analytics />;
      case 'commission':
        return <Commission />;
      default:
        return <Dashboard />;
    }
  };

  return (
    <div className="app">
      <Navigation 
        currentPage={currentPage} 
        onPageChange={setCurrentPage}
        user={user}
        userData={userData}
        onLogout={handleLogout}
      />
      <main className="main-content">
        {renderPage()}
      </main>
    </div>
  );
}

export default App;
