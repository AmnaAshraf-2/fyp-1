import React, { useState } from 'react';
import './Navigation.css';

function Navigation({ currentPage, onPageChange }) {
    const [isOpen, setIsOpen] = useState(false);

    const menuItems = [
        { id: 'dashboard', label: 'Dashboard', icon: '📊' },
        { id: 'users', label: 'User Management', icon: '👥' },
        { id: 'bookings', label: 'Booking Management', icon: '📦' },
        { id: 'analytics', label: 'Analytics', icon: '📈' },
        { id: 'settings', label: 'Settings', icon: '⚙️' }
    ];

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
                        <div className="admin-avatar">A</div>
                        <div className="admin-details">
                            <div className="admin-name">Admin User</div>
                            <div className="admin-role">System Administrator</div>
                        </div>
                    </div>
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
