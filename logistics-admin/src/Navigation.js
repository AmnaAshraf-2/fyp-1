import React, { useState } from 'react';
import './Navigation.css';

function Navigation({ currentPage, onPageChange, user, userData, onLogout }) {
    const [isOpen, setIsOpen] = useState(false);

    const menuItems = [
        { id: 'dashboard', label: 'Dashboard', icon: '📊' },
        { id: 'users', label: 'User Management', icon: '👥' },
        { id: 'vehicles', label: 'Vehicle Management', icon: '🚛' },
        { id: 'vehicle-types', label: 'Vehicle Types', icon: '🚗' },
        { id: 'bookings', label: 'Booking Management', icon: '📦' },
        { id: 'reports', label: 'Reports', icon: '📋' },
        { id: 'analytics', label: 'Analytics', icon: '📈' },
        { id: 'commission', label: 'Commission', icon: '💵' }
    ];

    // Get user display name
    const displayName = userData?.name || user?.displayName || user?.email?.split('@')[0] || 'Admin User';
    const userEmail = userData?.email || user?.email || '';
    const userRole = userData?.role || 'System Administrator';
    const userInitial = displayName.charAt(0).toUpperCase();

    return (
        <>
            {/* Mobile Menu Button */}
            <button
                className="mobile-menu-btn"
                onClick={() => setIsOpen(!isOpen)}
            >
                ☰
            </button>

            {/* Navigation Sidebar */}
            <nav className={`navigation ${isOpen ? 'open' : ''}`}>
                <div className="nav-header">
                    <h2>Logistics Admin</h2>
                    <button
                        className="close-btn"
                        onClick={() => setIsOpen(false)}
                    >
                        ×
                    </button>
                </div>

                <ul className="nav-menu">
                    {menuItems.map(item => (
                        <li key={item.id}>
                            <button
                                className={`nav-item ${currentPage === item.id ? 'active' : ''}`}
                                onClick={() => {
                                    onPageChange(item.id);
                                    setIsOpen(false);
                                }}
                            >
                                <span className="nav-icon">{item.icon}</span>
                                <span className="nav-label">{item.label}</span>
                            </button>
                        </li>
                    ))}
                </ul>

                <div className="nav-footer">
                    <div className="admin-info">
                        {user?.photoURL ? (
                            <img
                                src={user.photoURL}
                                alt={displayName}
                                className="admin-avatar-img"
                            />
                        ) : (
                            <div className="admin-avatar">{userInitial}</div>
                        )}
                        <div className="admin-details">
                            <div className="admin-name">{displayName}</div>
                            <div className="admin-role">{userRole}</div>
                            {userEmail && (
                                <div className="admin-email">{userEmail}</div>
                            )}
                        </div>
                    </div>
                    <button
                        className="logout-button"
                        onClick={() => {
                            onLogout();
                            setIsOpen(false);
                        }}
                    >
                        <span className="logout-icon">🚪</span>
                        <span>Logout</span>
                    </button>
                </div>
            </nav>

            {/* Overlay for mobile */}
            {isOpen && (
                <div
                    className="nav-overlay"
                    onClick={() => setIsOpen(false)}
                />
            )}
        </>
    );
}

export default Navigation;
