import React, { useState } from 'react';
import Navigation from './Navigation';
import Dashboard from './Dashboard';
import UserManagement from './UserManagement';
import BookingManagement from './BookingManagement';
import './App.css';

function App() {
  const [currentPage, setCurrentPage] = useState('dashboard');

  const renderPage = () => {
    switch (currentPage) {
      case 'dashboard':
        return <Dashboard />;
      case 'users':
        return <UserManagement />;
      case 'bookings':
        return <BookingManagement />;
      case 'analytics':
        return <div className="coming-soon">Analytics - Coming Soon</div>;
      case 'settings':
        return <div className="coming-soon">Settings - Coming Soon</div>;
      default:
        return <Dashboard />;
    }
  };

  return (
    <div className="app">
      <Navigation currentPage={currentPage} onPageChange={setCurrentPage} />
      <main className="main-content">
        {renderPage()}
      </main>
    </div>
  );
}

export default App;
